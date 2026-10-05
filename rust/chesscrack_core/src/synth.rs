//! Synthetic PGN generator. **Performance testing only** - games are random legal moves,
//! never shown as real gameplay. Metadata follows a realistic skewed distribution.

use shakmaty::san::SanPlus;
use shakmaty::{Chess, Position};
use std::fmt::Write as _;
use std::io::Write;

pub struct Rng(u64);
impl Rng {
    pub fn new(seed: u64) -> Self {
        Rng(seed.max(1))
    }
    pub fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x
    }
    pub fn below(&mut self, n: u64) -> u64 {
        self.next_u64() % n.max(1)
    }
}

const SYL: [&str; 24] = [
    "Kas", "Kar", "An", "Kram", "Car", "Nak", "Ding", "Lev", "Gel", "Smy", "Pet", "Ta", "Bot",
    "Fis", "Spas", "Alek", "Mor", "Ivan", "Nep", "Gri", "Rap", "Sho", "Vach", "Aro",
];
const END: [&str; 12] = [
    "parov", "pov", "and", "nik", "lsen", "amura", "ov", "ski", "man", "ier", "yan", "ssen",
];
const FIRST: [&str; 10] = [
    "Garry",
    "Anatoly",
    "Viswanathan",
    "Magnus",
    "Fabiano",
    "Hikaru",
    "Boris",
    "Mikhail",
    "Vladimir",
    "Levon",
];

fn player(rng: &mut Rng, pool: u64) -> String {
    // Skewed: low ids are drawn far more often (a few players dominate).
    let a = rng.below(pool);
    let b = rng.below(pool);
    let id = a.min(b);
    format!(
        "{}{}, {}",
        SYL[(id % 24) as usize],
        END[((id / 24) % 12) as usize],
        FIRST[((id / 288) % 10) as usize]
    ) + &if id >= 2880 {
        format!(" {}", id / 2880)
    } else {
        String::new()
    }
}

pub fn write_games<W: Write>(out: &mut W, count: u64, seed: u64) -> std::io::Result<()> {
    let mut rng = Rng::new(seed);
    let pool = (count / 8).clamp(500, 60_000);
    for g in 0..count {
        let white = player(&mut rng, pool);
        let black = player(&mut rng, pool);
        let year = 1950 + rng.below(75);
        let month = 1 + rng.below(12);
        let day = 1 + rng.below(28);
        let res = match rng.below(100) {
            0..=36 => "1-0",
            37..=62 => "1/2-1/2",
            _ => "0-1",
        };
        let eco = format!(
            "{}{:02}",
            (b'A' + rng.below(5) as u8) as char,
            rng.below(100)
        );
        let mut h = String::new();
        let _ = writeln!(h, "[Event \"Open {} #{}\"]", year, rng.below(400));
        let _ = writeln!(h, "[Site \"City {}\"]", rng.below(300));
        let _ = writeln!(h, "[Date \"{year}.{month:02}.{day:02}\"]");
        let _ = writeln!(h, "[Round \"{}\"]", 1 + rng.below(11));
        let _ = writeln!(
            h,
            "[White \"{white}\"]\n[Black \"{black}\"]\n[Result \"{res}\"]"
        );
        let _ = writeln!(
            h,
            "[WhiteElo \"{}\"]\n[BlackElo \"{}\"]",
            1700 + rng.below(1100),
            1700 + rng.below(1100)
        );
        let _ = writeln!(h, "[ECO \"{eco}\"]\n[GameId \"{g}\"]");
        out.write_all(h.as_bytes())?;
        out.write_all(b"\n")?;

        let plies = 16 + rng.below(70);
        let with_comments = rng.below(100) < 15;
        let with_variation = rng.below(100) < 3;
        let mut pos = Chess::default();
        let mut text = String::new();
        let mut line_len = 0usize;
        for ply in 0..plies {
            let legal = pos.legal_moves();
            if legal.is_empty() {
                break;
            }
            let m = legal[rng.below(legal.len() as u64) as usize].clone();
            let alt = if with_variation && ply == 6 && legal.len() > 1 {
                let a = legal[rng.below(legal.len() as u64) as usize].clone();
                if a != m {
                    Some(a)
                } else {
                    None
                }
            } else {
                None
            };
            let before = pos.clone();
            let san = SanPlus::from_move_and_play_unchecked(&mut pos, &m).to_string();
            let mut tok = String::new();
            if ply % 2 == 0 {
                let _ = write!(tok, "{}. ", ply / 2 + 1);
            }
            tok.push_str(&san);
            if with_comments && ply % 11 == 3 {
                let _ = write!(
                    tok,
                    " {{[%clk 0:{:02}:{:02}] interesting}}",
                    rng.below(60),
                    rng.below(60)
                );
            }
            if let Some(a) = alt {
                let mut b2 = before.clone();
                let asan = SanPlus::from_move_and_play_unchecked(&mut b2, &a).to_string();
                let num = if ply % 2 == 0 {
                    format!("{}. ", ply / 2 + 1)
                } else {
                    format!("{}... ", ply / 2 + 1)
                };
                let _ = write!(tok, " ({num}{asan})");
            }
            tok.push(' ');
            if line_len + tok.len() > 78 {
                text.push('\n');
                line_len = 0;
            }
            line_len += tok.len();
            text.push_str(&tok);
        }
        text.push_str(res);
        text.push_str("\n\n");
        out.write_all(text.as_bytes())?;
    }
    Ok(())
}
