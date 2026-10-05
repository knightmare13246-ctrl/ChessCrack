use chesscrack_core::db::{self, ImportOptions};
use chesscrack_core::pgn::{fen_hash, parse_game, split_games, IndexMode};
use serde_json::json;
use std::sync::atomic::AtomicBool;

const KASPAROV_TOPALOV: &str = r#"[Event "Hoogovens Group A"]
[Site "Wijk aan Zee NED"]
[Date "1999.01.20"]
[Round "4"]
[White "Kasparov, Garry"]
[Black "Topalov, Veselin"]
[Result "1-0"]
[WhiteElo "2812"]
[BlackElo "2700"]
[ECO "B06"]

1. e4 d6 2. d4 Nf6 3. Nc3 g6 4. Be3 Bg7 5. Qd2 c6 6. f3 b5 7. Nge2 Nbd7 8. Bh6
Bxh6 9. Qxh6 Bb7 10. a3 e5 11. O-O-O Qe7 12. Kb1 a6 13. Nc1 O-O-O 14. Nb3 exd4
15. Rxd4 c5 16. Rd1 Nb6 17. g3 Kb8 18. Na5 Ba8 19. Bh3 d5 20. Qf4+ Ka7 21. Rhe1
d4 22. Nd5 Nbxd5 23. exd5 Qd6 24. Rxd4 cxd4 25. Re7+ Kb6 26. Qxd4+ Kxa5 27. b4+
Ka4 28. Qc3 Qxd5 29. Ra7 Bb7 30. Rxb7 Qc4 31. Qxf6 Kxa3 32. Qxa6+ Kxb4 33. c3+
Kxc3 34. Qa1+ Kd2 35. Qb2+ Kd1 36. Bf1 Rd2 37. Rd7 Rxd7 38. Bxc4 bxc4 39. Qxh8
Rd3 40. Qa8 c3 41. Qa4+ Ke1 42. f4 f5 43. Kc1 Rd2 44. Qa7 1-0
"#;

const ANNOTATED: &str = r#"[Event "Annotated"]
[Site "?"]
[Date "2020.01.01"]
[Round "1"]
[White "A"]
[Black "B"]
[Result "*"]

1. e4 {[%clk 0:03:00] [%cal Ge2e4] best by test} e5 $1 (1... c5 2. Nf3 (2. Nc3 Nc6) 2... d6) 2. Nf3 Nc6! *
"#;

fn mem_db() -> (rusqlite::Connection, i64) {
    let c = db::open(":memory:").unwrap();
    let id = db::create_database(&c, "T", "custom", 1, "folder", "").unwrap();
    (c, id)
}

#[test]
fn parses_a_real_game_and_validates_every_move() {
    let g = parse_game(KASPAROV_TOPALOV, IndexMode::Full).unwrap();
    assert_eq!(g.ply_count, 87);
    assert_eq!(g.result, 1);
    assert_eq!(g.header("WhiteElo"), Some("2812"));
    assert_eq!(g.positions.len(), 88); // start + each ply
}

#[test]
fn preserves_comments_nags_and_variations_verbatim() {
    let g = parse_game(ANNOTATED, IndexMode::Off).unwrap();
    assert!(g.flags & 1 != 0 && g.flags & 2 != 0 && g.flags & 4 != 0);
    assert!(g.movetext.contains("[%cal Ge2e4]"));
    assert!(g.movetext.contains("(1... c5 2. Nf3 (2. Nc3 Nc6) 2... d6)"));
    assert_eq!(g.ply_count, 4);
}

#[test]
fn rejects_illegal_moves_including_inside_variations() {
    let bad = "[White \"a\"]\n[Black \"b\"]\n\n1. e4 e5 2. Ke4 *\n";
    assert!(parse_game(bad, IndexMode::Off)
        .unwrap_err()
        .message
        .contains("illegal"));
    let bad_var = "[White \"a\"]\n[Black \"b\"]\n\n1. e4 e5 (1... e4) *\n";
    assert!(parse_game(bad_var, IndexMode::Off).is_err());
    let unbalanced = "[White \"a\"]\n[Black \"b\"]\n\n1. e4 (1. d4 e5 *\n";
    assert!(parse_game(unbalanced, IndexMode::Off).is_err());
}

#[test]
fn custom_fen_start_is_respected() {
    let pgn = "[White \"a\"]\n[Black \"b\"]\n[SetUp \"1\"]\n[FEN \"4k3/8/8/8/8/8/4P3/4K3 w - - 0 1\"]\n\n1. e4 Kd7 *\n";
    let g = parse_game(pgn, IndexMode::Off).unwrap();
    assert_eq!(g.ply_count, 2);
    assert!(g.flags & 8 != 0);
}

#[test]
fn splits_multi_game_stream_and_ignores_brackets_inside_comments() {
    let text = format!("{KASPAROV_TOPALOV}\n\n[Event \"x\"]\n[White \"a\"]\n[Black \"b\"]\n\n1. e4 {{ a comment\n[not a header]\n}} e5 *\n");
    let games = split_games(&text);
    assert_eq!(games.len(), 2);
    assert!(games[1].text.contains("[not a header]"));
    assert!(parse_game(&games[1].text, IndexMode::Off).is_ok());
}

#[test]
fn fingerprint_is_deterministic_and_ignores_whitespace_and_case() {
    let a = parse_game(KASPAROV_TOPALOV, IndexMode::Off).unwrap();
    let b = parse_game(
        &KASPAROV_TOPALOV.replace("Kasparov, Garry", "  KASPAROV, garry "),
        IndexMode::Off,
    )
    .unwrap();
    assert_eq!(a.fingerprint, b.fingerprint);
    let c = parse_game(
        &KASPAROV_TOPALOV.replace("1. e4 d6", "1. d4 d6"),
        IndexMode::Off,
    );
    if let Ok(c) = c {
        assert_ne!(a.fingerprint, c.fingerprint);
    }
}

#[test]
fn zobrist_matches_between_game_index_and_fen_lookup() {
    let g = parse_game("[White \"a\"]\n[Black \"b\"]\n\n1. e4 *\n", IndexMode::Full).unwrap();
    let after_e4 = fen_hash("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1").unwrap();
    assert_eq!(g.positions[1].0, after_e4);
    // en-passant square that cannot be captured must not change the hash (EnPassantMode::Legal).
    let no_ep = fen_hash("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1").unwrap();
    assert_eq!(after_e4, no_ep);
}

fn write_tmp(name: &str, body: &str) -> std::path::PathBuf {
    let p = std::env::temp_dir().join(format!("cc_test_{}_{name}", std::process::id()));
    std::fs::write(&p, body).unwrap();
    p
}

#[test]
fn import_counts_duplicates_and_invalid_and_never_aborts() {
    let (mut c, id) = mem_db();
    let bad =
        "[Event \"bad\"]\n[White \"x\"]\n[Black \"y\"]\n\n1. e4 e5 2. Qh5 Nc6 3. Qxf7 Qxf7 *\n";
    let body = format!("{KASPAROV_TOPALOV}\n{ANNOTATED}\n{bad}\n{KASPAROV_TOPALOV}\n");
    let path = write_tmp("imp.pgn", &body);
    let mut last = None;
    let sum = db::run_import(
        &mut c,
        id,
        &path,
        &ImportOptions::default(),
        &AtomicBool::new(false),
        &mut |p| last = Some(p.clone()),
    )
    .unwrap();
    assert_eq!(sum.processed, 4);
    assert_eq!(sum.imported, 2);
    assert_eq!(sum.duplicates, 1);
    assert_eq!(sum.invalid, 1);
    let errs = db::import_errors(&c, sum.job_id, 10).unwrap();
    assert_eq!(errs.as_array().unwrap().len(), 1);
    assert_eq!(errs[0]["game"], 3);
    assert_eq!(db::count_games(&c, id, &json!({})).unwrap(), 2);
    let dbs = db::list_databases(&c).unwrap();
    assert_eq!(dbs[0]["gameCount"], 2); // real count, kept transactionally
    assert!(last.is_some());
}

#[test]
fn stored_game_round_trips_through_get_game_pgn() {
    let (mut c, id) = mem_db();
    let path = write_tmp("rt.pgn", ANNOTATED);
    db::run_import(
        &mut c,
        id,
        &path,
        &ImportOptions::default(),
        &AtomicBool::new(false),
        &mut |_| {},
    )
    .unwrap();
    let gid: i64 = c
        .query_row("SELECT id FROM games", [], |r| r.get(0))
        .unwrap();
    let out = db::get_game_pgn(&c, gid).unwrap();
    let pgn = out["pgn"].as_str().unwrap();
    assert!(pgn.contains("[%cal Ge2e4]") && pgn.contains("(2. Nc3 Nc6)"));
    // the exported PGN must itself re-parse identically
    let again = parse_game(pgn, IndexMode::Off).unwrap();
    assert_eq!(again.ply_count, 4);
}

#[test]
fn search_filter_sort_pagination_and_position_search() {
    let (mut c, id) = mem_db();
    let path = write_tmp("srch.pgn", &format!("{KASPAROV_TOPALOV}\n{ANNOTATED}"));
    db::run_import(
        &mut c,
        id,
        &path,
        &ImportOptions {
            index_mode: IndexMode::Full,
            ..Default::default()
        },
        &AtomicBool::new(false),
        &mut |_| {},
    )
    .unwrap();

    let r = db::search_games(&c, id, &json!({"player":"kasp"}), "date", true, 0, 10).unwrap();
    assert_eq!(r.as_array().unwrap().len(), 1);
    assert_eq!(r[0]["white"], "Kasparov, Garry");
    assert_eq!(db::count_games(&c, id, &json!({"eco":"B0"})).unwrap(), 1);
    assert_eq!(
        db::count_games(&c, id, &json!({"hasVariations":true})).unwrap(),
        1
    );
    assert_eq!(db::count_games(&c, id, &json!({"eloMin":2800})).unwrap(), 1);
    assert_eq!(db::count_games(&c, id, &json!({"results":[2]})).unwrap(), 0);
    let p0 = db::search_games(&c, id, &json!({}), "", false, 0, 1).unwrap();
    let p1 = db::search_games(&c, id, &json!({}), "", false, 1, 1).unwrap();
    assert_ne!(p0[0]["id"], p1[0]["id"]);

    // both games start 1.e4 e5/d6; after 1.e4 both match
    let ps = db::position_search(
        &c,
        id,
        "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
        10,
        0,
    )
    .unwrap();
    assert_eq!(ps["rows"].as_array().unwrap().len(), 2);
    // a LIKE wildcard in user input must be treated literally
    assert_eq!(db::count_games(&c, id, &json!({"player":"%"})).unwrap(), 0);
}

#[test]
fn position_search_is_honest_when_index_is_off() {
    let (mut c, id) = mem_db();
    let path = write_tmp("off.pgn", KASPAROV_TOPALOV);
    db::run_import(
        &mut c,
        id,
        &path,
        &ImportOptions {
            index_mode: IndexMode::Off,
            ..Default::default()
        },
        &AtomicBool::new(false),
        &mut |_| {},
    )
    .unwrap();
    let e = db::position_search(
        &c,
        id,
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        10,
        0,
    )
    .unwrap_err();
    assert!(e.contains("not") || e.contains("unavailable"));
}

#[test]
fn cancel_leaves_committed_batches_valid_and_import_can_resume() {
    let (mut c, id) = mem_db();
    let mut body = String::new();
    let mut buf = Vec::new();
    chesscrack_core::synth::write_games(&mut buf, 400, 7).unwrap();
    body.push_str(&String::from_utf8(buf).unwrap());
    let path = write_tmp("resume.pgn", &body);

    // Deterministic interruption: stop after 2 committed batches (simulates a killed import).
    let cancel = AtomicBool::new(false);
    let opts = ImportOptions {
        batch_size: 50,
        max_batches: Some(2),
        ..Default::default()
    };
    let first = db::run_import(&mut c, id, &path, &opts, &cancel, &mut |_| {}).unwrap();
    assert!(first.cancelled);
    assert_eq!(first.imported, 100);
    let integrity = db::integrity_check(&c).unwrap();
    assert_eq!(integrity["integrity"], "ok");
    assert_eq!(integrity["foreignKeyViolations"], 0);

    let job = db::unfinished_jobs(&c).unwrap()[0]["jobId"]
        .as_i64()
        .unwrap();
    let resumed = db::run_import(
        &mut c,
        id,
        &path,
        &ImportOptions {
            resume_job: Some(job),
            batch_size: 50,
            ..Default::default()
        },
        &AtomicBool::new(false),
        &mut |_| {},
    )
    .unwrap();
    assert!(!resumed.cancelled);
    assert_eq!(db::count_games(&c, id, &json!({})).unwrap(), 400);
    assert_eq!(
        resumed.duplicates, 0,
        "resume must continue at the committed offset, not re-read"
    );
}

#[test]
fn copy_move_delete_keep_counts_and_foreign_keys_consistent() {
    let (mut c, a) = mem_db();
    let b = db::create_database(&c, "B", "custom", 2, "folder", "").unwrap();
    let path = write_tmp("cm.pgn", &format!("{KASPAROV_TOPALOV}\n{ANNOTATED}"));
    db::run_import(
        &mut c,
        a,
        &path,
        &ImportOptions::default(),
        &AtomicBool::new(false),
        &mut |_| {},
    )
    .unwrap();
    let ids: Vec<i64> = c
        .prepare("SELECT id FROM games")
        .unwrap()
        .query_map([], |r| r.get(0))
        .unwrap()
        .map(|x| x.unwrap())
        .collect();

    let r = db::copy_games(&mut c, &ids, b, false).unwrap();
    assert_eq!(r["copied"], 2);
    assert_eq!(db::count_games(&c, a, &json!({})).unwrap(), 2);
    assert_eq!(db::count_games(&c, b, &json!({})).unwrap(), 2);
    let again = db::copy_games(&mut c, &ids, b, false).unwrap();
    assert_eq!(again["duplicates"], 2);

    db::delete_games(&mut c, &ids).unwrap();
    let dbs = db::list_databases(&c).unwrap();
    let count_a = dbs
        .as_array()
        .unwrap()
        .iter()
        .find(|d| d["id"] == a)
        .unwrap()["gameCount"]
        .clone();
    assert_eq!(count_a, 0);

    db::delete_database(&mut c, b, &AtomicBool::new(false)).unwrap();
    let integrity = db::integrity_check(&c).unwrap();
    assert_eq!(integrity["foreignKeyViolations"], 0);
    assert_eq!(db::list_databases(&c).unwrap().as_array().unwrap().len(), 1);
}

#[test]
fn reference_database_set_and_cleared_on_delete() {
    let (mut c, a) = mem_db();
    db::set_reference(&c, Some(a)).unwrap();
    assert_eq!(db::get_reference(&c).unwrap(), Some(a));
    assert_eq!(db::list_databases(&c).unwrap()[0]["isReference"], true);
    db::delete_database(&mut c, a, &AtomicBool::new(false)).unwrap();
    assert_eq!(db::get_reference(&c).unwrap(), None);
}

#[test]
fn refuses_newer_schema_instead_of_destroying_it() {
    let p = std::env::temp_dir().join(format!("cc_newer_{}.db", std::process::id()));
    {
        let c = rusqlite::Connection::open(&p).unwrap();
        c.execute_batch("PRAGMA user_version=99;").unwrap();
    }
    let err = db::open(p.to_str().unwrap()).unwrap_err();
    assert!(err.contains("newer"));
}

#[test]
fn ffi_bridge_never_panics_on_garbage() {
    use chesscrack_core::ffi::{handle_request, open_handle};
    let p = std::env::temp_dir().join(format!("cc_ffi_{}.db", std::process::id()));
    let _ = std::fs::remove_file(&p);
    let h = open_handle(p.to_str().unwrap()).unwrap();
    assert!(handle_request(h, "{not json").contains("bad request"));
    assert!(handle_request(h, r#"{"op":"nope"}"#).contains("unknown op"));
    assert!(handle_request(999_999, r#"{"op":"version"}"#).contains("invalid database handle"));
    assert!(handle_request(h, r#"{"op":"get_game","id":42}"#).contains("error"));
    assert!(handle_request(h, r#"{"op":"version"}"#).contains("schema"));
}
