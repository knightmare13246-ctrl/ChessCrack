//! SQLite schema, migrations, import, search, export. One database, owned here.

use crate::pgn::{
    compose_pgn, fen_hash, parse_game, result_str, GameReader, IndexMode, ParsedGame,
};
use rusqlite::{params, params_from_iter, types::Value as SqlValue, Connection, OptionalExtension};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;

pub const SCHEMA_VERSION: i32 = 1;
pub type DbResult<T> = Result<T, String>;

fn e<T: std::fmt::Display>(x: T) -> String {
    x.to_string()
}

fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

pub fn open(path: &str) -> DbResult<Connection> {
    let conn = Connection::open(path).map_err(e)?;
    conn.execute_batch(
        "PRAGMA journal_mode=WAL;
         PRAGMA synchronous=NORMAL;
         PRAGMA foreign_keys=ON;
         PRAGMA temp_store=MEMORY;
         PRAGMA cache_size=-8192;
         PRAGMA busy_timeout=60000;",
    )
    .map_err(e)?;
    migrate(&conn)?;
    Ok(conn)
}

fn migrate(conn: &Connection) -> DbResult<()> {
    let v: i32 = conn
        .query_row("PRAGMA user_version", [], |r| r.get(0))
        .map_err(e)?;
    if v > SCHEMA_VERSION {
        return Err(format!(
            "database schema v{v} is newer than this app supports (v{SCHEMA_VERSION}); refusing to open"
        ));
    }
    if v < 1 {
        conn.execute_batch(
            "BEGIN;
             CREATE TABLE databases(
               id INTEGER PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
               category TEXT NOT NULL DEFAULT 'custom', color INTEGER NOT NULL DEFAULT 0,
               icon TEXT NOT NULL DEFAULT 'folder', game_count INTEGER NOT NULL DEFAULT 0,
               index_mode TEXT NOT NULL DEFAULT 'balanced', version INTEGER NOT NULL DEFAULT 1,
               created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
             CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
             CREATE TABLE players(id INTEGER PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE);
             CREATE TABLE events(id INTEGER PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE,
               site TEXT NOT NULL COLLATE NOCASE, UNIQUE(name, site));
             CREATE TABLE games(
               id INTEGER PRIMARY KEY,
               db_id INTEGER NOT NULL REFERENCES databases(id) ON DELETE CASCADE,
               white_id INTEGER NOT NULL REFERENCES players(id),
               black_id INTEGER NOT NULL REFERENCES players(id),
               white_elo INTEGER, black_elo INTEGER,
               result INTEGER NOT NULL DEFAULT 0,
               event_id INTEGER NOT NULL REFERENCES events(id),
               date TEXT NOT NULL DEFAULT '????.??.??', year INTEGER,
               round TEXT NOT NULL DEFAULT '?',
               eco TEXT, opening TEXT, variation TEXT,
               ply_count INTEGER NOT NULL DEFAULT 0, flags INTEGER NOT NULL DEFAULT 0,
               favorite INTEGER NOT NULL DEFAULT 0, fingerprint INTEGER NOT NULL,
               created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
             CREATE TABLE game_data(game_id INTEGER PRIMARY KEY REFERENCES games(id) ON DELETE CASCADE,
               extra_headers TEXT NOT NULL DEFAULT '', movetext TEXT NOT NULL);
             CREATE TABLE position_index(hash INTEGER NOT NULL, game_id INTEGER NOT NULL
               REFERENCES games(id) ON DELETE CASCADE, ply INTEGER NOT NULL,
               PRIMARY KEY(hash, game_id, ply)) WITHOUT ROWID;
             CREATE TABLE import_jobs(id INTEGER PRIMARY KEY, db_id INTEGER NOT NULL,
               source_path TEXT NOT NULL, file_size INTEGER NOT NULL,
               committed_offset INTEGER NOT NULL DEFAULT 0, processed INTEGER NOT NULL DEFAULT 0,
               imported INTEGER NOT NULL DEFAULT 0, duplicates INTEGER NOT NULL DEFAULT 0,
               invalid INTEGER NOT NULL DEFAULT 0, state TEXT NOT NULL,
               started_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
             CREATE TABLE import_errors(job_id INTEGER NOT NULL, game_number INTEGER NOT NULL,
               byte_offset INTEGER NOT NULL, message TEXT NOT NULL);
             CREATE UNIQUE INDEX ux_games_fp ON games(db_id, fingerprint);
             CREATE INDEX ix_games_white ON games(db_id, white_id);
             CREATE INDEX ix_games_black ON games(db_id, black_id);
             CREATE INDEX ix_games_date ON games(db_id, date);
             CREATE INDEX ix_games_eco ON games(db_id, eco);
             CREATE INDEX ix_games_event ON games(db_id, event_id);
             CREATE INDEX ix_games_fav ON games(db_id, favorite) WHERE favorite=1;
             CREATE INDEX ix_import_errors ON import_errors(job_id);
             CREATE INDEX ix_pos_game ON position_index(game_id);
             PRAGMA user_version=1;
             COMMIT;",
        )
        .map_err(e)?;
    }
    // Ensure index exists on already-created v1 databases
    conn.execute_batch("CREATE INDEX IF NOT EXISTS ix_pos_game ON position_index(game_id);")
        .map_err(e)?;
    Ok(())
}

// ---------------------------------------------------------------- databases

pub fn create_database(
    c: &Connection,
    name: &str,
    category: &str,
    color: i64,
    icon: &str,
    description: &str,
) -> DbResult<i64> {
    let name = name.trim();
    if name.is_empty() {
        return Err("database name must not be empty".into());
    }
    let t = now();
    c.execute(
        "INSERT INTO databases(name,description,category,color,icon,created_at,updated_at)
         VALUES(?,?,?,?,?,?,?)",
        params![name, description, category, color, icon, t, t],
    )
    .map_err(e)?;
    Ok(c.last_insert_rowid())
}

pub fn list_databases(c: &Connection) -> DbResult<Value> {
    let reference: Option<i64> = get_reference(c)?;
    let mut st = c
        .prepare(
            "SELECT id,name,description,category,color,icon,game_count,index_mode,created_at,updated_at
             FROM databases ORDER BY name COLLATE NOCASE",
        )
        .map_err(e)?;
    let rows = st
        .query_map([], |r| {
            let id: i64 = r.get(0)?;
            Ok(json!({"id":id,"name":r.get::<_,String>(1)?,"description":r.get::<_,String>(2)?,
              "category":r.get::<_,String>(3)?,"color":r.get::<_,i64>(4)?,"icon":r.get::<_,String>(5)?,
              "gameCount":r.get::<_,i64>(6)?,"indexMode":r.get::<_,String>(7)?,
              "createdAt":r.get::<_,i64>(8)?,"updatedAt":r.get::<_,i64>(9)?,
              "isReference": Some(id)==reference}))
        })
        .map_err(e)?;
    Ok(Value::Array(
        rows.collect::<Result<Vec<_>, _>>().map_err(e)?,
    ))
}

pub fn get_reference(c: &Connection) -> DbResult<Option<i64>> {
    c.query_row("SELECT value FROM meta WHERE key='reference_db'", [], |r| {
        r.get::<_, String>(0)
    })
    .optional()
    .map_err(e)
    .map(|o| o.and_then(|s| s.parse().ok()))
}

pub fn set_reference(c: &Connection, id: Option<i64>) -> DbResult<()> {
    match id {
        Some(id) => c
            .execute(
                "INSERT OR REPLACE INTO meta(key,value) VALUES('reference_db',?)",
                params![id.to_string()],
            )
            .map_err(e)?,
        None => c
            .execute("DELETE FROM meta WHERE key='reference_db'", [])
            .map_err(e)?,
    };
    Ok(())
}

pub fn rename_database(c: &Connection, id: i64, name: &str) -> DbResult<()> {
    if name.trim().is_empty() {
        return Err("database name must not be empty".into());
    }
    c.execute(
        "UPDATE databases SET name=?,updated_at=? WHERE id=?",
        params![name.trim(), now(), id],
    )
    .map_err(e)?;
    Ok(())
}

pub fn update_database_style(
    c: &Connection,
    id: i64,
    color: i64,
    icon: &str,
    category: &str,
) -> DbResult<()> {
    c.execute(
        "UPDATE databases SET color=?,icon=?,category=?,updated_at=? WHERE id=?",
        params![color, icon, category, now(), id],
    )
    .map_err(e)?;
    Ok(())
}

/// Deletes in bounded chunks so a huge database never holds one giant transaction.
pub fn delete_database(c: &mut Connection, id: i64, cancel: &AtomicBool) -> DbResult<()> {
    loop {
        if cancel.load(Ordering::Relaxed) {
            return Err("cancelled".into());
        }
        let tx = c
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(e)?;
        let n = tx
            .execute(
                "DELETE FROM games WHERE id IN (SELECT id FROM games WHERE db_id=? LIMIT 2000)",
                params![id],
            )
            .map_err(e)?;
        tx.commit().map_err(e)?;
        if n == 0 {
            break;
        }
    }
    let tx = c
        .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
        .map_err(e)?;
    let _ = tx.execute(
        "DELETE FROM import_errors WHERE job_id IN (SELECT id FROM import_jobs WHERE db_id=?)",
        params![id],
    );
    tx.execute("DELETE FROM import_jobs WHERE db_id=?", params![id])
        .map_err(e)?;
    tx.execute("DELETE FROM databases WHERE id=?", params![id])
        .map_err(e)?;
    tx.commit().map_err(e)?;
    if get_reference(c)? == Some(id) {
        set_reference(c, None)?;
    }
    Ok(())
}

// ------------------------------------------------------------------- import

#[derive(Clone, Debug)]
pub struct ImportOptions {
    pub batch_size: usize,
    pub index_mode: IndexMode,
    pub resume_job: Option<i64>,
    /// Stop (resumably, state 'cancelled') after this many committed batches.
    pub max_batches: Option<u64>,
}

impl Default for ImportOptions {
    fn default() -> Self {
        ImportOptions {
            batch_size: 1000,
            index_mode: IndexMode::Balanced(24),
            resume_job: None,
            max_batches: None,
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct ImportProgress {
    pub job_id: i64,
    pub processed: u64,
    pub imported: u64,
    pub duplicates: u64,
    pub invalid: u64,
    pub bytes_read: u64,
    pub total_bytes: u64,
    pub games_per_sec: f64,
    pub state: String,
}

impl ImportProgress {
    pub fn to_json(&self) -> Value {
        let frac = if self.total_bytes > 0 {
            self.bytes_read as f64 / self.total_bytes as f64
        } else {
            0.0
        };
        let remaining = if self.games_per_sec > 0.0 && frac > 0.0 && frac < 1.0 {
            let est_total = self.processed as f64 / frac;
            ((est_total - self.processed as f64) / self.games_per_sec).max(0.0)
        } else {
            0.0
        };
        json!({"jobId":self.job_id,"processed":self.processed,"imported":self.imported,
          "duplicates":self.duplicates,"invalid":self.invalid,"bytesRead":self.bytes_read,
          "totalBytes":self.total_bytes,"fraction":frac,"gamesPerSec":self.games_per_sec,
          "etaSeconds":remaining,"state":self.state})
    }
}

struct Caches {
    players: HashMap<String, i64>,
    events: HashMap<(String, String), i64>,
}

const CACHE_CAP: usize = 200_000;

fn player_id(tx: &rusqlite::Transaction, c: &mut Caches, name: &str) -> DbResult<i64> {
    if let Some(&id) = c.players.get(name) {
        return Ok(id);
    }
    if c.players.len() >= CACHE_CAP {
        c.players.clear();
    }
    tx.prepare_cached("INSERT OR IGNORE INTO players(name) VALUES(?)")
        .map_err(e)?
        .execute(params![name])
        .map_err(e)?;
    let id: i64 = tx
        .prepare_cached("SELECT id FROM players WHERE name=?")
        .map_err(e)?
        .query_row(params![name], |r| r.get(0))
        .map_err(e)?;
    c.players.insert(name.to_string(), id);
    Ok(id)
}

fn event_id(tx: &rusqlite::Transaction, c: &mut Caches, name: &str, site: &str) -> DbResult<i64> {
    let key = (name.to_string(), site.to_string());
    if let Some(&id) = c.events.get(&key) {
        return Ok(id);
    }
    if c.events.len() >= CACHE_CAP {
        c.events.clear();
    }
    tx.prepare_cached("INSERT OR IGNORE INTO events(name,site) VALUES(?,?)")
        .map_err(e)?
        .execute(params![name, site])
        .map_err(e)?;
    let id: i64 = tx
        .prepare_cached("SELECT id FROM events WHERE name=? AND site=?")
        .map_err(e)?
        .query_row(params![name, site], |r| r.get(0))
        .map_err(e)?;
    c.events.insert(key, id);
    Ok(id)
}

const STD_TAGS: [&str; 15] = [
    "Event",
    "Site",
    "Date",
    "Round",
    "White",
    "Black",
    "Result",
    "WhiteElo",
    "BlackElo",
    "ECO",
    "Opening",
    "Variation",
    "FEN",
    "SetUp",
    "PlyCount",
];

#[derive(PartialEq, Eq, Debug)]
pub enum Inserted {
    New(i64),
    Duplicate,
}

fn or_q(s: Option<&str>) -> &str {
    match s {
        Some(v) if !v.trim().is_empty() => v.trim(),
        _ => "?",
    }
}

fn insert_game(
    tx: &rusqlite::Transaction,
    caches: &mut Caches,
    db_id: i64,
    g: &ParsedGame,
) -> DbResult<Inserted> {
    let white = player_id(tx, caches, or_q(g.header("White")))?;
    let black = player_id(tx, caches, or_q(g.header("Black")))?;
    let ev = event_id(tx, caches, or_q(g.header("Event")), or_q(g.header("Site")))?;
    let date = g
        .header("Date")
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or("????.??.??");
    let year: Option<i64> = date.split('.').next().and_then(|y| y.parse().ok());
    let welo: Option<i64> = g.header("WhiteElo").and_then(|s| s.trim().parse().ok());
    let belo: Option<i64> = g.header("BlackElo").and_then(|s| s.trim().parse().ok());
    let t = now();

    let n = tx
        .prepare_cached(
            "INSERT OR IGNORE INTO games(db_id,white_id,black_id,white_elo,black_elo,result,event_id,
              date,year,round,eco,opening,variation,ply_count,flags,fingerprint,created_at,updated_at)
             VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        )
        .map_err(e)?
        .execute(params![
            db_id, white, black, welo, belo, g.result, ev, date, year,
            or_q(g.header("Round")), g.header("ECO"), g.header("Opening"), g.header("Variation"),
            g.ply_count, g.flags, g.fingerprint, t, t
        ])
        .map_err(e)?;
    if n == 0 {
        return Ok(Inserted::Duplicate);
    }
    let gid = tx.last_insert_rowid();

    let extra: Vec<(&String, &String)> = g
        .headers
        .iter()
        .filter(|(k, _)| {
            !STD_TAGS.iter().any(|s| s.eq_ignore_ascii_case(k))
                || k.eq_ignore_ascii_case("FEN")
                || k.eq_ignore_ascii_case("SetUp")
        })
        .map(|(k, v)| (k, v))
        .collect();
    let extra_json = if extra.is_empty() {
        String::new()
    } else {
        json!(extra).to_string()
    };
    tx.prepare_cached("INSERT INTO game_data(game_id,extra_headers,movetext) VALUES(?,?,?)")
        .map_err(e)?
        .execute(params![gid, extra_json, g.movetext])
        .map_err(e)?;

    if !g.positions.is_empty() {
        let mut st = tx
            .prepare_cached("INSERT OR IGNORE INTO position_index(hash,game_id,ply) VALUES(?,?,?)")
            .map_err(e)?;
        for (h, ply) in &g.positions {
            st.execute(params![h, gid, ply]).map_err(e)?;
        }
    }
    Ok(Inserted::New(gid))
}

#[derive(Debug, Default, Clone)]
pub struct ImportSummary {
    pub job_id: i64,
    pub processed: u64,
    pub imported: u64,
    pub duplicates: u64,
    pub invalid: u64,
    pub cancelled: bool,
    pub seconds: f64,
}

pub fn run_import(
    conn: &mut Connection,
    db_id: i64,
    path: &Path,
    opts: &ImportOptions,
    cancel: &AtomicBool,
    on_progress: &mut dyn FnMut(&ImportProgress),
) -> DbResult<ImportSummary> {
    let file = File::open(path).map_err(|x| format!("cannot open {}: {x}", path.display()))?;
    let total = file.metadata().map_err(e)?.len();
    let t = now();

    let (job_id, mut offset, mut processed, mut imported, mut dups, mut invalid) = match opts.resume_job {
        Some(j) => conn
            .query_row(
                "SELECT committed_offset,processed,imported,duplicates,invalid FROM import_jobs WHERE id=? AND db_id=?",
                params![j, db_id],
                |r| Ok((j, r.get::<_, i64>(0)? as u64, r.get::<_, i64>(1)? as u64, r.get::<_, i64>(2)? as u64, r.get::<_, i64>(3)? as u64, r.get::<_, i64>(4)? as u64)),
            )
            .map_err(|_| format!("import job {j} not found for this database"))?,
        None => {
            conn.execute(
                "INSERT INTO import_jobs(db_id,source_path,file_size,state,started_at,updated_at) VALUES(?,?,?,?,?,?)",
                params![db_id, path.to_string_lossy(), total as i64, "running", t, t],
            )
            .map_err(e)?;
            (conn.last_insert_rowid(), 0, 0, 0, 0, 0)
        }
    };
    conn.execute(
        "UPDATE import_jobs SET state='running' WHERE id=?",
        params![job_id],
    )
    .map_err(e)?;

    let reader = BufReader::with_capacity(1 << 20, file);
    let mut games = GameReader::resume(reader, offset, processed).map_err(e)?;
    let mut caches = Caches {
        players: HashMap::new(),
        events: HashMap::new(),
    };
    let started = Instant::now();
    let base_processed = processed;
    let mut last_emit = Instant::now();
    let mut cancelled = false;
    let mut eof = false;
    let mut batches_done = 0u64;

    let make_progress =
        |processed: u64, imported: u64, dups: u64, invalid: u64, offset: u64, state: &str| {
            let secs = started.elapsed().as_secs_f64().max(1e-6);
            ImportProgress {
                job_id,
                processed,
                imported,
                duplicates: dups,
                invalid,
                bytes_read: offset,
                total_bytes: total,
                games_per_sec: (processed - base_processed) as f64 / secs,
                state: state.to_string(),
            }
        };

    while !eof {
        if cancel.load(Ordering::Relaxed) {
            cancelled = true;
            break;
        }
        // Read + validate a bounded batch outside the transaction.
        let mut batch: Vec<(u64, u64, Result<ParsedGame, String>)> =
            Vec::with_capacity(opts.batch_size);
        let mut batch_end = offset;
        while batch.len() < opts.batch_size {
            match games.next_game().map_err(e)? {
                Some(raw) => {
                    batch_end = raw.end_offset;
                    let parsed = parse_game(&raw.text, opts.index_mode).map_err(|x| x.message);
                    batch.push((raw.number, raw.start_offset, parsed));
                }
                None => {
                    eof = true;
                    break;
                }
            }
        }
        if batch.is_empty() {
            break;
        }

        let tx = conn.transaction().map_err(e)?;
        let (mut b_new, mut b_dup, mut b_bad) = (0u64, 0u64, 0u64);
        for (number, start, parsed) in &batch {
            match parsed {
                Ok(g) => match insert_game(&tx, &mut caches, db_id, g)? {
                    Inserted::New(_) => b_new += 1,
                    Inserted::Duplicate => b_dup += 1,
                },
                Err(msg) => {
                    b_bad += 1;
                    tx.execute(
                        "INSERT INTO import_errors(job_id,game_number,byte_offset,message)
                         SELECT ?,?,?,? WHERE (SELECT COUNT(*) FROM import_errors WHERE job_id=?) < 10000",
                        params![job_id, *number as i64, *start as i64, msg, job_id],
                    )
                    .map_err(e)?;
                }
            }
        }
        processed += batch.len() as u64;
        imported += b_new;
        dups += b_dup;
        invalid += b_bad;
        offset = batch_end;
        tx.execute(
            "UPDATE import_jobs SET committed_offset=?,processed=?,imported=?,duplicates=?,invalid=?,updated_at=? WHERE id=?",
            params![offset as i64, processed as i64, imported as i64, dups as i64, invalid as i64, now(), job_id],
        )
        .map_err(e)?;
        tx.execute(
            "UPDATE databases SET game_count=game_count+?,updated_at=?,index_mode=? WHERE id=?",
            params![b_new as i64, now(), opts.index_mode.as_str(), db_id],
        )
        .map_err(e)?;
        tx.commit().map_err(e)?;
        batches_done += 1;
        if opts.max_batches.is_some_and(|m| batches_done >= m) && !eof {
            cancelled = true;
        }

        // Throttled progress (never per game).
        if last_emit.elapsed().as_millis() >= 150 {
            on_progress(&make_progress(
                processed, imported, dups, invalid, offset, "running",
            ));
            last_emit = Instant::now();
        }
        if cancelled {
            break;
        }
    }

    let state = if cancelled { "cancelled" } else { "done" };
    conn.execute(
        "UPDATE import_jobs SET state=?,updated_at=? WHERE id=?",
        params![state, now(), job_id],
    )
    .map_err(e)?;
    on_progress(&make_progress(
        processed,
        imported,
        dups,
        invalid,
        if eof { total } else { offset },
        state,
    ));
    Ok(ImportSummary {
        job_id,
        processed: processed - base_processed,
        imported,
        duplicates: dups,
        invalid,
        cancelled,
        seconds: started.elapsed().as_secs_f64(),
    })
}

/// Imports a single PGN string (Play-mode autosave, "Save As", paste). Returns the new game id.
pub fn save_pgn_text(
    conn: &mut Connection,
    db_id: i64,
    pgn: &str,
    mode: IndexMode,
) -> DbResult<Value> {
    let games = crate::pgn::split_games(pgn);
    let mut caches = Caches {
        players: HashMap::new(),
        events: HashMap::new(),
    };
    let tx = conn.transaction().map_err(e)?;
    let (mut ids, mut dups, mut bad) = (Vec::new(), 0, Vec::new());
    for raw in &games {
        match parse_game(&raw.text, mode) {
            Ok(g) => match insert_game(&tx, &mut caches, db_id, &g)? {
                Inserted::New(id) => ids.push(id),
                Inserted::Duplicate => dups += 1,
            },
            Err(x) => bad.push(json!({"game":raw.number,"error":x.message})),
        }
    }
    tx.execute(
        "UPDATE databases SET game_count=game_count+?,updated_at=? WHERE id=?",
        params![ids.len() as i64, now(), db_id],
    )
    .map_err(e)?;
    tx.commit().map_err(e)?;
    Ok(json!({"ids":ids,"duplicates":dups,"invalid":bad}))
}

pub fn import_errors(c: &Connection, job_id: i64, limit: i64) -> DbResult<Value> {
    let mut st = c
        .prepare("SELECT game_number,byte_offset,message FROM import_errors WHERE job_id=? ORDER BY game_number LIMIT ?")
        .map_err(e)?;
    let rows = st
        .query_map(params![job_id, limit], |r| {
            Ok(json!({"game":r.get::<_,i64>(0)?,"offset":r.get::<_,i64>(1)?,"message":r.get::<_,String>(2)?}))
        })
        .map_err(e)?;
    Ok(Value::Array(
        rows.collect::<Result<Vec<_>, _>>().map_err(e)?,
    ))
}

pub fn unfinished_jobs(c: &Connection) -> DbResult<Value> {
    let mut st = c
        .prepare("SELECT id,db_id,source_path,file_size,committed_offset,processed,state FROM import_jobs WHERE state IN ('running','cancelled')")
        .map_err(e)?;
    let rows = st
        .query_map([], |r| {
            Ok(json!({"jobId":r.get::<_,i64>(0)?,"dbId":r.get::<_,i64>(1)?,"path":r.get::<_,String>(2)?,
              "fileSize":r.get::<_,i64>(3)?,"committedOffset":r.get::<_,i64>(4)?,
              "processed":r.get::<_,i64>(5)?,"state":r.get::<_,String>(6)?}))
        })
        .map_err(e)?;
    Ok(Value::Array(
        rows.collect::<Result<Vec<_>, _>>().map_err(e)?,
    ))
}

// ------------------------------------------------------------------- search

fn like_prefix(s: &str) -> String {
    let esc = s
        .replace('\\', "\\\\")
        .replace('%', "\\%")
        .replace('_', "\\_");
    format!("{esc}%")
}

/// Builds the WHERE clause (always scoped to a database) from a JSON filter.
fn build_where(db_id: i64, f: &Value) -> (String, Vec<SqlValue>) {
    let mut w = vec!["g.db_id=?".to_string()];
    let mut p: Vec<SqlValue> = vec![SqlValue::Integer(db_id)];
    let s = |k: &str| {
        f.get(k)
            .and_then(|v| v.as_str())
            .map(str::trim)
            .filter(|x| !x.is_empty())
    };
    let n = |k: &str| f.get(k).and_then(|v| v.as_i64());

    if let Some(x) = s("player") {
        w.push("(g.white_id IN (SELECT id FROM players WHERE name LIKE ? ESCAPE '\\') OR g.black_id IN (SELECT id FROM players WHERE name LIKE ? ESCAPE '\\'))".into());
        p.push(SqlValue::Text(like_prefix(x)));
        p.push(SqlValue::Text(like_prefix(x)));
    }
    if let Some(x) = s("white") {
        w.push("g.white_id IN (SELECT id FROM players WHERE name LIKE ? ESCAPE '\\')".into());
        p.push(SqlValue::Text(like_prefix(x)));
    }
    if let Some(x) = s("black") {
        w.push("g.black_id IN (SELECT id FROM players WHERE name LIKE ? ESCAPE '\\')".into());
        p.push(SqlValue::Text(like_prefix(x)));
    }
    if let Some(x) = s("event") {
        w.push("g.event_id IN (SELECT id FROM events WHERE name LIKE ? ESCAPE '\\')".into());
        p.push(SqlValue::Text(format!(
            "%{}%",
            x.replace('%', "\\%").replace('_', "\\_")
        )));
    }
    if let Some(x) = s("eco") {
        w.push("g.eco LIKE ? ESCAPE '\\'".into());
        p.push(SqlValue::Text(like_prefix(x)));
    }
    if let Some(x) = s("opening") {
        w.push("g.opening LIKE ? ESCAPE '\\'".into());
        p.push(SqlValue::Text(format!(
            "%{}%",
            x.replace('%', "\\%").replace('_', "\\_")
        )));
    }
    if let Some(arr) = f.get("results").and_then(|v| v.as_array()) {
        let codes: Vec<i64> = arr.iter().filter_map(|v| v.as_i64()).collect();
        if !codes.is_empty() {
            w.push(format!(
                "g.result IN ({})",
                codes.iter().map(|_| "?").collect::<Vec<_>>().join(",")
            ));
            p.extend(codes.into_iter().map(SqlValue::Integer));
        }
    }
    if let Some(x) = s("dateFrom") {
        w.push("g.date>=?".into());
        p.push(SqlValue::Text(x.to_string()));
    }
    if let Some(x) = s("dateTo") {
        w.push("g.date<=?".into());
        p.push(SqlValue::Text(x.to_string()));
    }
    if let Some(x) = n("eloMin") {
        w.push("MAX(COALESCE(g.white_elo,0),COALESCE(g.black_elo,0))>=?".into());
        p.push(SqlValue::Integer(x));
    }
    if let Some(x) = n("eloMax") {
        w.push("MAX(COALESCE(g.white_elo,0),COALESCE(g.black_elo,0))<=?".into());
        p.push(SqlValue::Integer(x));
    }
    if f.get("hasComments").and_then(|v| v.as_bool()) == Some(true) {
        w.push("(g.flags & 1)!=0".into());
    }
    if f.get("hasVariations").and_then(|v| v.as_bool()) == Some(true) {
        w.push("(g.flags & 2)!=0".into());
    }
    if f.get("favorite").and_then(|v| v.as_bool()) == Some(true) {
        w.push("g.favorite=1".into());
    }
    (w.join(" AND "), p)
}

fn order_clause(sort: &str, desc: bool) -> String {
    let col = match sort {
        "date" => "g.date",
        "white" => "pw.name",
        "black" => "pb.name",
        "event" => "ev.name",
        "eco" => "g.eco",
        "rating" => "MAX(COALESCE(g.white_elo,0),COALESCE(g.black_elo,0))",
        "result" => "g.result",
        "moves" => "g.ply_count",
        _ => "g.id",
    };
    format!(
        "{col} {}, g.id {}",
        if desc { "DESC" } else { "ASC" },
        if desc { "DESC" } else { "ASC" }
    )
}

pub fn count_games(c: &Connection, db_id: i64, filter: &Value) -> DbResult<i64> {
    let (w, p) = build_where(db_id, filter);
    c.query_row(
        &format!("SELECT COUNT(*) FROM games g WHERE {w}"),
        params_from_iter(p),
        |r| r.get(0),
    )
    .map_err(e)
}

pub fn search_games(
    c: &Connection,
    db_id: i64,
    filter: &Value,
    sort: &str,
    desc: bool,
    offset: i64,
    limit: i64,
) -> DbResult<Value> {
    let (w, mut p) = build_where(db_id, filter);
    p.push(SqlValue::Integer(limit.clamp(1, 500)));
    p.push(SqlValue::Integer(offset.max(0)));
    let sql = format!(
        "SELECT g.id,pw.name,pb.name,g.white_elo,g.black_elo,g.result,ev.name,ev.site,g.date,g.round,
                g.eco,g.opening,g.variation,g.ply_count,g.flags,g.favorite
         FROM games g JOIN players pw ON pw.id=g.white_id JOIN players pb ON pb.id=g.black_id
         JOIN events ev ON ev.id=g.event_id WHERE {w} ORDER BY {} LIMIT ? OFFSET ?",
        order_clause(sort, desc)
    );
    let mut st = c.prepare(&sql).map_err(e)?;
    let rows = st
        .query_map(params_from_iter(p), |r| {
            Ok(json!({"id":r.get::<_,i64>(0)?,"white":r.get::<_,String>(1)?,"black":r.get::<_,String>(2)?,
              "whiteElo":r.get::<_,Option<i64>>(3)?,"blackElo":r.get::<_,Option<i64>>(4)?,
              "result":result_str(r.get::<_,i64>(5)?),"event":r.get::<_,String>(6)?,"site":r.get::<_,String>(7)?,
              "date":r.get::<_,String>(8)?,"round":r.get::<_,String>(9)?,"eco":r.get::<_,Option<String>>(10)?,
              "opening":r.get::<_,Option<String>>(11)?,"variation":r.get::<_,Option<String>>(12)?,
              "plyCount":r.get::<_,i64>(13)?,"flags":r.get::<_,i64>(14)?,"favorite":r.get::<_,i64>(15)? != 0}))
        })
        .map_err(e)?;
    Ok(Value::Array(
        rows.collect::<Result<Vec<_>, _>>().map_err(e)?,
    ))
}

fn load_game_parts(c: &Connection, id: i64) -> DbResult<(Vec<(String, String)>, String, i64, i64)> {
    c.query_row(
        "SELECT pw.name,pb.name,g.white_elo,g.black_elo,g.result,ev.name,ev.site,g.date,g.round,g.eco,
                g.opening,g.variation,d.extra_headers,d.movetext,g.db_id
         FROM games g JOIN players pw ON pw.id=g.white_id JOIN players pb ON pb.id=g.black_id
         JOIN events ev ON ev.id=g.event_id JOIN game_data d ON d.game_id=g.id WHERE g.id=?",
        params![id],
        |r| {
            let mut h: Vec<(String, String)> = vec![
                ("Event".into(), r.get(5)?), ("Site".into(), r.get(6)?), ("Date".into(), r.get(7)?),
                ("Round".into(), r.get(8)?), ("White".into(), r.get(0)?), ("Black".into(), r.get(1)?),
                ("Result".into(), result_str(r.get::<_, i64>(4)?).to_string()),
            ];
            if let Some(x) = r.get::<_, Option<i64>>(2)? { h.push(("WhiteElo".into(), x.to_string())); }
            if let Some(x) = r.get::<_, Option<i64>>(3)? { h.push(("BlackElo".into(), x.to_string())); }
            if let Some(x) = r.get::<_, Option<String>>(9)? { h.push(("ECO".into(), x)); }
            if let Some(x) = r.get::<_, Option<String>>(10)? { h.push(("Opening".into(), x)); }
            if let Some(x) = r.get::<_, Option<String>>(11)? { h.push(("Variation".into(), x)); }
            let extra: String = r.get(12)?;
            if !extra.is_empty() {
                if let Ok(v) = serde_json::from_str::<Vec<(String, String)>>(&extra) {
                    h.extend(v);
                }
            }
            Ok((h, r.get::<_, String>(13)?, r.get::<_, i64>(4)?, r.get::<_, i64>(14)?))
        },
    )
    .map_err(|x| format!("game {id}: {x}"))
}

/// Loads exactly one game and returns reconstructed PGN (the existing Dart PgnParser/GameTree path consumes it).
pub fn get_game_pgn(c: &Connection, id: i64) -> DbResult<Value> {
    let (h, mt, res, db_id) = load_game_parts(c, id)?;
    Ok(json!({"id":id,"dbId":db_id,"pgn":compose_pgn(&h, &mt, res)}))
}

pub fn set_favorite(c: &Connection, id: i64, value: bool) -> DbResult<()> {
    c.execute(
        "UPDATE games SET favorite=?,updated_at=? WHERE id=?",
        params![value as i64, now(), id],
    )
    .map_err(e)?;
    Ok(())
}

pub fn delete_games(c: &mut Connection, ids: &[i64]) -> DbResult<i64> {
    let tx = c.transaction().map_err(e)?;
    let mut total = 0i64;
    for id in ids {
        let db: Option<i64> = tx
            .query_row("SELECT db_id FROM games WHERE id=?", params![id], |r| {
                r.get(0)
            })
            .optional()
            .map_err(e)?;
        if let Some(db) = db {
            tx.execute("DELETE FROM games WHERE id=?", params![id])
                .map_err(e)?;
            tx.execute(
                "UPDATE databases SET game_count=game_count-1,updated_at=? WHERE id=?",
                params![now(), db],
            )
            .map_err(e)?;
            total += 1;
        }
    }
    tx.commit().map_err(e)?;
    Ok(total)
}

/// Copies (or moves) games into another database. Duplicates in the target are skipped.
pub fn copy_games(
    c: &mut Connection,
    ids: &[i64],
    target: i64,
    delete_source: bool,
) -> DbResult<Value> {
    let mode: String = c
        .query_row(
            "SELECT index_mode FROM databases WHERE id=?",
            params![target],
            |r| r.get(0),
        )
        .map_err(|_| "target database not found".to_string())?;
    let mode = IndexMode::parse(&mode);
    let mut caches = Caches {
        players: HashMap::new(),
        events: HashMap::new(),
    };
    let (mut copied, mut dups, mut failed) = (0i64, 0i64, 0i64);
    let mut copied_ids = Vec::new();
    {
        let tx = c.transaction().map_err(e)?;
        for id in ids {
            let (h, mt, _, _) = match load_game_parts(&tx, *id) {
                Ok(x) => x,
                Err(_) => {
                    failed += 1;
                    continue;
                }
            };
            let text = format!(
                "{}\n{}\n",
                h.iter()
                    .map(|(k, v)| format!(
                        "[{k} \"{}\"]",
                        v.replace('\\', "\\\\").replace('"', "\\\"")
                    ))
                    .collect::<Vec<_>>()
                    .join("\n"),
                mt
            );
            match parse_game(&text, mode) {
                Ok(g) => match insert_game(&tx, &mut caches, target, &g)? {
                    Inserted::New(_) => {
                        copied += 1;
                        copied_ids.push(*id)
                    }
                    Inserted::Duplicate => {
                        dups += 1;
                        copied_ids.push(*id)
                    }
                },
                Err(_) => failed += 1,
            }
        }
        tx.execute(
            "UPDATE databases SET game_count=game_count+?,updated_at=? WHERE id=?",
            params![copied, now(), target],
        )
        .map_err(e)?;
        tx.commit().map_err(e)?;
    }
    if delete_source {
        delete_games(c, &copied_ids)?;
    }
    Ok(json!({"copied":copied,"duplicates":dups,"failed":failed}))
}

pub fn position_search(
    c: &Connection,
    db_id: i64,
    fen: &str,
    limit: i64,
    offset: i64,
) -> DbResult<Value> {
    let mode: String = c
        .query_row(
            "SELECT index_mode FROM databases WHERE id=?",
            params![db_id],
            |r| r.get(0),
        )
        .map_err(e)?;
    if mode == "off" {
        return Err("Position search is unavailable: this database was imported without a position index (mode: off). Rebuild it with indexing enabled.".into());
    }
    let h = fen_hash(fen).map_err(|x| x.message)?;
    let mut st = c
        .prepare(
            "SELECT g.id,pw.name,pb.name,g.result,g.date,ev.name,x.ply
             FROM position_index x JOIN games g ON g.id=x.game_id JOIN players pw ON pw.id=g.white_id
             JOIN players pb ON pb.id=g.black_id JOIN events ev ON ev.id=g.event_id
             WHERE x.hash=? AND g.db_id=? ORDER BY g.date DESC, g.id LIMIT ? OFFSET ?",
        )
        .map_err(e)?;
    let rows = st
        .query_map(params![h, db_id, limit.clamp(1, 500), offset.max(0)], |r| {
            Ok(json!({"id":r.get::<_,i64>(0)?,"white":r.get::<_,String>(1)?,"black":r.get::<_,String>(2)?,
              "result":result_str(r.get::<_,i64>(3)?),"date":r.get::<_,String>(4)?,"event":r.get::<_,String>(5)?,
              "ply":r.get::<_,i64>(6)?}))
        })
        .map_err(e)?;
    Ok(json!({"indexMode":mode,"rows":rows.collect::<Result<Vec<_>, _>>().map_err(e)?}))
}

pub fn database_stats(c: &Connection, db_id: i64) -> DbResult<Value> {
    c.query_row(
        "SELECT COUNT(*),COUNT(DISTINCT white_id)+0,MIN(NULLIF(substr(date,1,4),'????')),MAX(NULLIF(substr(date,1,4),'????')),
                AVG(white_elo),SUM(flags&1!=0),SUM(flags&2!=0),SUM(result=1),SUM(result=2),SUM(result=3),COUNT(DISTINCT event_id)
         FROM games WHERE db_id=?",
        params![db_id],
        |r| {
            Ok(json!({"games":r.get::<_,i64>(0)?,"whitePlayers":r.get::<_,i64>(1)?,"firstYear":r.get::<_,Option<String>>(2)?,
              "lastYear":r.get::<_,Option<String>>(3)?,"avgElo":r.get::<_,Option<f64>>(4)?,
              "annotated":r.get::<_,Option<i64>>(5)?.unwrap_or(0),"withVariations":r.get::<_,Option<i64>>(6)?.unwrap_or(0),
              "whiteWins":r.get::<_,Option<i64>>(7)?.unwrap_or(0),"blackWins":r.get::<_,Option<i64>>(8)?.unwrap_or(0),
              "draws":r.get::<_,Option<i64>>(9)?.unwrap_or(0),"events":r.get::<_,i64>(10)?}))
        },
    )
    .map_err(e)
}

pub fn integrity_check(c: &Connection) -> DbResult<Value> {
    let ic: String = c
        .query_row("PRAGMA integrity_check", [], |r| r.get(0))
        .map_err(e)?;
    let fk: i64 = c
        .query_row("SELECT COUNT(*) FROM pragma_foreign_key_check", [], |r| {
            r.get(0)
        })
        .map_err(e)?;
    Ok(json!({"integrity":ic,"foreignKeyViolations":fk}))
}

// ------------------------------------------------------------------- export

/// Streams a database (or id list) to a PGN file: constant memory.
pub fn export_pgn(
    c: &Connection,
    db_id: i64,
    ids: Option<&[i64]>,
    path: &Path,
    cancel: &AtomicBool,
    on_progress: &mut dyn FnMut(u64, u64),
) -> DbResult<u64> {
    let total: u64 = match ids {
        Some(v) => v.len() as u64,
        None => c
            .query_row(
                "SELECT game_count FROM databases WHERE id=?",
                params![db_id],
                |r| r.get::<_, i64>(0),
            )
            .map_err(e)? as u64,
    };
    let mut out = BufWriter::with_capacity(1 << 20, File::create(path).map_err(e)?);
    let mut n = 0u64;
    let mut last = Instant::now();
    let write_one = |id: i64, out: &mut BufWriter<File>| -> DbResult<()> {
        let (h, mt, res, _) = load_game_parts(c, id)?;
        out.write_all(compose_pgn(&h, &mt, res).as_bytes())
            .map_err(e)
    };
    match ids {
        Some(list) => {
            for id in list {
                if cancel.load(Ordering::Relaxed) {
                    break;
                }
                write_one(*id, &mut out)?;
                n += 1;
            }
        }
        None => {
            let mut st = c
                .prepare("SELECT id FROM games WHERE db_id=? ORDER BY id")
                .map_err(e)?;
            let mut rows = st.query(params![db_id]).map_err(e)?;
            while let Some(r) = rows.next().map_err(e)? {
                if cancel.load(Ordering::Relaxed) {
                    break;
                }
                write_one(r.get(0).map_err(e)?, &mut out)?;
                n += 1;
                if last.elapsed().as_millis() >= 150 {
                    on_progress(n, total);
                    last = Instant::now();
                }
            }
        }
    }
    out.flush().map_err(e)?;
    on_progress(n, total);
    Ok(n)
}
