//! Streaming PGN reader + validating game parser.
//!
//! Design goals (see the ChessCrack database spec):
//! * never hold more than one game's text (plus a bounded batch) in memory;
//! * the movetext is stored **verbatim** (comments, NAGs, variations, `[%clk]`,
//!   `[%cal]` arrows...) so nothing is destroyed; the parser only *validates* it;
//! * a malformed game yields a `GameError`, never aborts the stream;
//! * byte offsets are tracked so an import can resume after the process is killed.

use shakmaty::fen::Fen;
use shakmaty::san::San;
use shakmaty::uci::UciMove;
use shakmaty::zobrist::{Zobrist64, ZobristHash};
use shakmaty::{CastlingMode, Chess, EnPassantMode, Position};
use std::io::{BufRead, Read, Seek, SeekFrom};

/// One game's raw text as it appeared in the file.
#[derive(Debug, Clone)]
pub struct RawGame {
    /// 1-based ordinal of the game in the source file.
    pub number: u64,
    pub start_offset: u64,
    /// Offset of the first byte *after* this game (resume point).
    pub end_offset: u64,
    pub text: String,
}

/// Incremental splitter of a PGN byte stream into games.
pub struct GameReader<R: BufRead> {
    reader: R,
    offset: u64,
    number: u64,
    pending: Option<(String, u64)>,
    done: bool,
}

impl<R: BufRead + Seek> GameReader<R> {
    /// Start reading at `start_offset`; `already_read` is the number of games
    /// consumed before that offset (so game numbers stay stable on resume).
    pub fn resume(mut reader: R, start_offset: u64, already_read: u64) -> std::io::Result<Self> {
        reader.seek(SeekFrom::Start(start_offset))?;
        Ok(Self::new_at(reader, start_offset, already_read))
    }
}

impl<R: BufRead> GameReader<R> {
    pub fn new(reader: R) -> Self {
        Self::new_at(reader, 0, 0)
    }

    fn new_at(reader: R, offset: u64, number: u64) -> Self {
        GameReader {
            reader,
            offset,
            number,
            pending: None,
            done: false,
        }
    }

    fn read_line(&mut self) -> std::io::Result<Option<(String, u64)>> {
        let start = self.offset;
        let mut buf = Vec::with_capacity(128);
        let n = self.reader.read_until(b'\n', &mut buf)?;
        if n == 0 {
            return Ok(None);
        }
        self.offset += n as u64;
        // UTF-8 first; fall back to Latin-1, which is common in legacy PGN.
        let s = match String::from_utf8(buf) {
            Ok(s) => s,
            Err(e) => e.into_bytes().iter().map(|&b| b as char).collect(),
        };
        let s = s.trim_start_matches('\u{feff}').to_string();
        Ok(Some((s, start)))
    }

    /// Returns the next game, or `None` at EOF.
    pub fn next_game(&mut self) -> std::io::Result<Option<RawGame>> {
        if self.done {
            return Ok(None);
        }
        let mut text = String::new();
        let mut start_offset = 0u64;
        let mut have_header = false;
        let mut in_movetext = false;
        let mut brace_depth = 0i32;
        let mut in_line_comment = false;

        loop {
            let (line, line_start) = match self.pending.take() {
                Some(p) => p,
                None => match self.read_line()? {
                    Some(l) => l,
                    None => {
                        self.done = true;
                        break;
                    }
                },
            };
            let trimmed = line.trim();
            if trimmed.is_empty() {
                if have_header {
                    text.push('\n');
                }
                continue;
            }
            if trimmed.starts_with('%') && brace_depth == 0 {
                continue; // PGN escape line
            }
            let is_header = trimmed.starts_with('[') && brace_depth == 0 && !in_line_comment;
            if is_header {
                if in_movetext {
                    // A header after movetext = next game begins.
                    self.pending = Some((line, line_start));
                    break;
                }
                if !have_header {
                    start_offset = line_start;
                    have_header = true;
                }
                text.push_str(trimmed);
                text.push('\n');
            } else {
                if !have_header {
                    // Headerless game: start here.
                    start_offset = line_start;
                    have_header = true;
                }
                in_movetext = true;
                in_line_comment = false;
                for ch in trimmed.chars() {
                    match ch {
                        '{' if !in_line_comment => brace_depth += 1,
                        '}' if brace_depth > 0 => brace_depth -= 1,
                        ';' if brace_depth == 0 => {
                            in_line_comment = true;
                        }
                        _ => {}
                    }
                }
                in_line_comment = false;
                text.push_str(trimmed);
                text.push('\n');
            }
        }

        if !have_header {
            return Ok(None);
        }
        self.number += 1;
        let end_offset = match &self.pending {
            Some((_, off)) => *off,
            None => self.offset,
        };
        Ok(Some(RawGame {
            number: self.number,
            start_offset,
            end_offset,
            text,
        }))
    }
}

pub const FLAG_COMMENTS: i64 = 1;
pub const FLAG_VARIATIONS: i64 = 2;
pub const FLAG_NAGS: i64 = 4;
pub const FLAG_CUSTOM_FEN: i64 = 8;

/// How many mainline plies get a position-hash row.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IndexMode {
    /// Metadata only; no position index.
    Off,
    /// First `n` plies of the mainline (openings) - small and fast.
    Balanced(u32),
    /// Every mainline ply.
    Full,
}

impl IndexMode {
    pub fn max_ply(self) -> u32 {
        match self {
            IndexMode::Off => 0,
            IndexMode::Balanced(n) => n,
            IndexMode::Full => u32::MAX,
        }
    }
    pub fn as_str(self) -> &'static str {
        match self {
            IndexMode::Off => "off",
            IndexMode::Balanced(_) => "balanced",
            IndexMode::Full => "full",
        }
    }
    pub fn parse(s: &str) -> IndexMode {
        match s {
            "off" => IndexMode::Off,
            "full" => IndexMode::Full,
            _ => IndexMode::Balanced(24),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ParsedGame {
    pub headers: Vec<(String, String)>,
    pub movetext: String,
    pub result: i64, // 0 '*', 1 '1-0', 2 '0-1', 3 draw
    pub ply_count: u32,
    pub flags: i64,
    pub fingerprint: i64,
    pub positions: Vec<(i64, u32)>,
    pub start_fen: Option<String>,
}

impl ParsedGame {
    pub fn header(&self, key: &str) -> Option<&str> {
        self.headers
            .iter()
            .find(|(k, _)| k.eq_ignore_ascii_case(key))
            .map(|(_, v)| v.as_str())
    }
}

#[derive(Debug, Clone)]
pub struct GameError {
    pub message: String,
}

impl std::fmt::Display for GameError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.message)
    }
}

fn err<T>(m: impl Into<String>) -> Result<T, GameError> {
    Err(GameError { message: m.into() })
}

pub fn result_code(s: &str) -> i64 {
    match s.trim() {
        "1-0" => 1,
        "0-1" => 2,
        "1/2-1/2" | "1/2" | "½-½" => 3,
        _ => 0,
    }
}

pub fn result_str(c: i64) -> &'static str {
    match c {
        1 => "1-0",
        2 => "0-1",
        3 => "1/2-1/2",
        _ => "*",
    }
}

/// Stable 64-bit FNV-1a (deterministic across builds/platforms, unlike `DefaultHasher`).
struct Fnv(u64);
impl Fnv {
    fn new() -> Self {
        Fnv(0xcbf29ce484222325)
    }
    fn bytes(&mut self, b: &[u8]) {
        for &x in b {
            self.0 ^= x as u64;
            self.0 = self.0.wrapping_mul(0x100000001b3);
        }
        self.0 ^= 0xff; // field separator
        self.0 = self.0.wrapping_mul(0x100000001b3);
    }
}

fn norm(s: &str) -> String {
    s.trim().to_lowercase()
}

fn parse_headers(lines: &str) -> (Vec<(String, String)>, usize) {
    // Returns headers and the byte index where movetext starts.
    let mut headers = Vec::new();
    let mut idx = 0usize;
    for line in lines.split_inclusive('\n') {
        let t = line.trim();
        if t.starts_with('[') && t.ends_with(']') {
            if let Some((k, v)) = parse_tag(t) {
                headers.push((k, v));
            }
            idx += line.len();
        } else if t.is_empty() {
            idx += line.len();
        } else {
            break;
        }
    }
    (headers, idx)
}

fn parse_tag(t: &str) -> Option<(String, String)> {
    let inner = t.strip_prefix('[')?.strip_suffix(']')?.trim();
    let sp = inner.find(char::is_whitespace)?;
    let key = inner[..sp].to_string();
    let rest = inner[sp..].trim();
    let rest = rest.strip_prefix('"')?;
    let mut val = String::new();
    let mut chars = rest.chars();
    while let Some(c) = chars.next() {
        match c {
            '\\' => {
                if let Some(n) = chars.next() {
                    val.push(n);
                }
            }
            '"' => break,
            _ => val.push(c),
        }
    }
    Some((key, val))
}

/// Parse + fully validate one game. Illegal moves anywhere (including variations) are errors.
pub fn parse_game(raw: &str, mode: IndexMode) -> Result<ParsedGame, GameError> {
    let (headers, mt_start) = parse_headers(raw);
    let movetext = raw[mt_start..].trim().to_string();

    let mut start_fen = None;
    let mut root = Chess::default();
    let mut custom_fen = false;
    if let Some((_, fen)) = headers.iter().find(|(k, _)| k.eq_ignore_ascii_case("FEN")) {
        let f: Fen = match fen.parse() {
            Ok(f) => f,
            Err(e) => return err(format!("invalid FEN tag: {e}")),
        };
        root = match f.into_position(CastlingMode::Standard) {
            Ok(p) => p,
            Err(e) => return err(format!("illegal FEN position: {e}")),
        };
        start_fen = Some(fen.clone());
        custom_fen = true;
    }

    let mut flags = if custom_fen { FLAG_CUSTOM_FEN } else { 0 };
    let mut result_tok: Option<i64> = None;

    let mut cur = root.clone();
    let mut prev: Option<Chess> = None;
    let mut stack: Vec<(Option<Chess>, Chess)> = Vec::new();
    let mut ply = 0u32;
    let mut positions = Vec::new();
    let mut fp = Fnv::new();
    let max_ply = mode.max_ply();
    let want_positions = mode != IndexMode::Off;

    if want_positions {
        let h: Zobrist64 = cur.zobrist_hash(EnPassantMode::Legal);
        positions.push((h.0 as i64, 0u32));
    }

    let b = movetext.as_bytes();
    let n = b.len();
    let mut i = 0usize;
    while i < n {
        let c = b[i];
        match c {
            b' ' | b'\t' | b'\r' | b'\n' => i += 1,
            b'{' => {
                flags |= FLAG_COMMENTS;
                match movetext[i..].find('}') {
                    Some(e) => i += e + 1,
                    None => return err("unterminated { comment"),
                }
            }
            b';' => {
                flags |= FLAG_COMMENTS;
                i = movetext[i..].find('\n').map(|e| i + e + 1).unwrap_or(n);
            }
            b'(' => {
                flags |= FLAG_VARIATIONS;
                let Some(p) = prev.clone() else {
                    return err("variation opened before any move");
                };
                stack.push((prev.take(), cur.clone()));
                cur = p;
                i += 1;
            }
            b')' => {
                match stack.pop() {
                    Some((p, c2)) => {
                        prev = p;
                        cur = c2;
                    }
                    None => return err("unbalanced ) in movetext"),
                }
                i += 1;
            }
            b'$' => {
                flags |= FLAG_NAGS;
                i += 1;
                while i < n && b[i].is_ascii_digit() {
                    i += 1;
                }
            }
            _ => {
                let s = i;
                while i < n
                    && !matches!(
                        b[i],
                        b' ' | b'\t' | b'\r' | b'\n' | b'{' | b'(' | b')' | b';'
                    )
                {
                    i += 1;
                }
                let mut tok = &movetext[s..i];
                if matches!(tok, "1-0" | "0-1" | "1/2-1/2" | "*") {
                    if stack.is_empty() {
                        result_tok = Some(result_code(tok));
                    }
                    continue;
                }
                // strip move number: "12." "12..." "12.e4"
                let digits = tok.bytes().take_while(|x| x.is_ascii_digit()).count();
                if digits > 0 && tok.as_bytes().get(digits) == Some(&b'.') {
                    tok = tok[digits..].trim_start_matches('.');
                    if tok.is_empty() {
                        continue;
                    }
                } else if digits == tok.len() {
                    continue; // bare number
                }
                // strip suffix annotations (!, ?, !!, ?!, ...) -> implicit NAG
                let clean = tok.trim_end_matches(['!', '?']);
                if clean.len() != tok.len() {
                    flags |= FLAG_NAGS;
                }
                if clean == "--" || clean == "Z0" {
                    return err("null moves are not supported");
                }
                if clean.is_empty() {
                    continue;
                }
                let san: San = match clean.parse() {
                    Ok(s) => s,
                    Err(e) => return err(format!("bad SAN '{clean}' at ply {}: {e}", ply + 1)),
                };
                let mv = match san.to_move(&cur) {
                    Ok(m) => m,
                    Err(_) => {
                        return err(format!("illegal move '{clean}' at ply {}", ply + 1));
                    }
                };
                let next = {
                    let mut p = cur.clone();
                    p.play_unchecked(&mv);
                    p
                };
                if stack.is_empty() {
                    ply += 1;
                    let uci = UciMove::from_move(&mv, CastlingMode::Standard).to_string();
                    fp.bytes(uci.as_bytes());
                    if want_positions && ply <= max_ply {
                        let h: Zobrist64 = next.zobrist_hash(EnPassantMode::Legal);
                        positions.push((h.0 as i64, ply));
                    }
                }
                prev = Some(std::mem::replace(&mut cur, next));
            }
        }
    }
    if !stack.is_empty() {
        return err("unbalanced ( in movetext");
    }

    // Final fingerprint: normalised identity headers + start FEN + mainline UCI (already folded in).
    let get = |k: &str| {
        headers
            .iter()
            .find(|(hk, _)| hk.eq_ignore_ascii_case(k))
            .map(|(_, v)| norm(v))
            .unwrap_or_default()
    };
    let mut meta = Fnv::new();
    for k in ["White", "Black", "Date", "Round", "Event", "Result"] {
        meta.bytes(get(k).as_bytes());
    }
    meta.bytes(start_fen.as_deref().unwrap_or("").as_bytes());
    let fingerprint = (meta.0 ^ fp.0.rotate_left(17)) as i64;

    let tag_result = headers
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case("Result"))
        .map(|(_, v)| result_code(v));
    let result = match (tag_result, result_tok) {
        (Some(r), _) if r != 0 => r,
        (_, Some(r)) => r,
        (Some(r), None) => r,
        _ => 0,
    };

    Ok(ParsedGame {
        headers,
        movetext,
        result,
        ply_count: ply,
        flags,
        fingerprint,
        positions,
        start_fen,
    })
}

/// Zobrist hash of an arbitrary FEN, using the same function as the position index.
pub fn fen_hash(fen: &str) -> Result<i64, GameError> {
    let f: Fen = fen.parse().map_err(|e| GameError {
        message: format!("invalid FEN: {e}"),
    })?;
    let pos: Chess = f
        .into_position(CastlingMode::Standard)
        .map_err(|e| GameError {
            message: format!("illegal FEN: {e}"),
        })?;
    let h: Zobrist64 = pos.zobrist_hash(EnPassantMode::Legal);
    Ok(h.0 as i64)
}

/// Rebuild a full PGN text from stored columns.
pub fn compose_pgn(headers: &[(String, String)], movetext: &str, result: i64) -> String {
    let mut out = String::with_capacity(movetext.len() + 256);
    for (k, v) in headers {
        out.push('[');
        out.push_str(k);
        out.push_str(" \"");
        for c in v.chars() {
            if c == '"' || c == '\\' {
                out.push('\\');
            }
            out.push(c);
        }
        out.push_str("\"]\n");
    }
    out.push('\n');
    out.push_str(movetext.trim());
    let t = movetext.trim_end();
    let ends_with_result = ["1-0", "0-1", "1/2-1/2", "*"]
        .iter()
        .any(|r| t.ends_with(r));
    if !ends_with_result {
        out.push(' ');
        out.push_str(result_str(result));
    }
    out.push_str("\n\n");
    out
}

/// Convenience used by tests: split an in-memory PGN string.
pub fn split_games(text: &str) -> Vec<RawGame> {
    let mut r = GameReader::new(std::io::Cursor::new(text.as_bytes()));
    let mut v = Vec::new();
    while let Ok(Some(g)) = r.next_game() {
        v.push(g);
    }
    v
}

#[allow(dead_code)]
fn _assert_traits(_: &dyn Read) {}
