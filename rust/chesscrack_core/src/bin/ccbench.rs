//! ccbench: generate synthetic PGN, import it, then time the core queries.
//! usage: ccbench <games> [batch_size] [index_mode: off|balanced|full]

use chesscrack_core::ffi::{handle_request, open_handle};
use chesscrack_core::synth;
use serde_json::{json, Value};
use std::io::BufWriter;
use std::time::Instant;

fn call(h: i64, req: Value) -> Value {
    let r: Value = serde_json::from_str(&handle_request(h, &req.to_string())).unwrap();
    if let Some(e) = r.get("error") {
        panic!("request {req} failed: {e}");
    }
    r["ok"].clone()
}

fn ms<F: FnOnce() -> R, R>(label: &str, f: F) -> R {
    let t = Instant::now();
    let r = f();
    println!(
        "[BENCH] {label:<34} {:>9.2} ms",
        t.elapsed().as_secs_f64() * 1000.0
    );
    r
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let games: u64 = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(10_000);
    let batch: i64 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(1000);
    let mode = args.get(3).cloned().unwrap_or_else(|| "balanced".into());

    let dir = std::env::temp_dir().join(format!("ccbench_{games}_{batch}_{mode}"));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let pgn = dir.join("synthetic.pgn");
    let dbp = dir.join("lib.db");

    ms(&format!("generate {games} synthetic games"), || {
        let mut w = BufWriter::new(std::fs::File::create(&pgn).unwrap());
        synth::write_games(&mut w, games, 0xC0FFEE).unwrap();
    });
    println!(
        "[BENCH] pgn size {:.1} MB",
        std::fs::metadata(&pgn).unwrap().len() as f64 / 1e6
    );

    let h = ms("open+migrate", || {
        open_handle(dbp.to_str().unwrap()).unwrap()
    });
    let dbid = call(h, json!({"op":"create_database","name":"Bench"}))["id"]
        .as_i64()
        .unwrap();

    let t = Instant::now();
    let job = call(h, json!({"op":"start_import","dbId":dbid,"path":pgn.to_str().unwrap(),"batchSize":batch,"indexMode":mode}))["jobId"].as_i64().unwrap();
    let mut peak = 0f64;
    loop {
        std::thread::sleep(std::time::Duration::from_millis(250));
        let st = call(h, json!({"op":"job_status","jobId":job}));
        peak = peak.max(st["gamesPerSec"].as_f64().unwrap_or(0.0));
        match st["state"].as_str().unwrap() {
            "done" => {
                println!(
                    "[BENCH] import {games} games: {:.2}s  =>  {:.0} games/s   summary={}",
                    t.elapsed().as_secs_f64(),
                    games as f64 / t.elapsed().as_secs_f64(),
                    st["summary"]
                );
                break;
            }
            "failed" | "cancelled" => panic!("import ended: {st}"),
            _ => {}
        }
    }
    println!("[BENCH] db size {:.1} MB (wal-checkpointed on close)", {
        let _ = call(h, json!({"op":"vacuum"}));
        std::fs::metadata(&dbp).unwrap().len() as f64 / 1e6
    });

    // Re-import same file => everything must dedupe.
    let t = Instant::now();
    let job2 = call(h, json!({"op":"start_import","dbId":dbid,"path":pgn.to_str().unwrap(),"batchSize":batch,"indexMode":mode}))["jobId"].as_i64().unwrap();
    loop {
        std::thread::sleep(std::time::Duration::from_millis(100));
        let st = call(h, json!({"op":"job_status","jobId":job2}));
        if st["state"] == "done" {
            println!(
                "[BENCH] re-import (all duplicates): {:.2}s summary={}",
                t.elapsed().as_secs_f64(),
                st["summary"]
            );
            break;
        }
    }

    ms("list_databases", || call(h, json!({"op":"list_databases"})));
    ms("search page0 (default order)", || {
        call(h, json!({"op":"search_games","dbId":dbid,"limit":50}))
    });
    ms("search deep page (offset 50%)", || {
        call(
            h,
            json!({"op":"search_games","dbId":dbid,"limit":50,"offset":games/2}),
        )
    });
    ms("player prefix 'Kasp'", || {
        call(
            h,
            json!({"op":"search_games","dbId":dbid,"filter":{"player":"Kasp"},"limit":50}),
        )
    });
    ms("count player prefix", || {
        call(
            h,
            json!({"op":"count_games","dbId":dbid,"filter":{"player":"Kasp"}}),
        )
    });
    ms("event contains 'Open 1999'", || {
        call(
            h,
            json!({"op":"search_games","dbId":dbid,"filter":{"event":"Open 1999"},"limit":50}),
        )
    });
    ms("ECO prefix 'B1'", || {
        call(
            h,
            json!({"op":"search_games","dbId":dbid,"filter":{"eco":"B1"},"limit":50}),
        )
    });
    ms("filter elo>=2600 result=1-0", || {
        call(
            h,
            json!({"op":"search_games","dbId":dbid,"filter":{"eloMin":2600,"results":[1]},"limit":50}),
        )
    });
    ms("sort by date desc", || {
        call(
            h,
            json!({"op":"search_games","dbId":dbid,"sort":"date","desc":true,"limit":50}),
        )
    });
    ms("sort by white", || {
        call(
            h,
            json!({"op":"search_games","dbId":dbid,"sort":"white","limit":50}),
        )
    });
    ms("get_game #1", || call(h, json!({"op":"get_game","id":1})));
    ms("get_game middle", || {
        call(h, json!({"op":"get_game","id":games/2}))
    });
    ms("stats", || call(h, json!({"op":"stats","dbId":dbid})));
    if mode != "off" {
        let r = ms("position_search (after 1.e4)", || {
            call(
                h,
                json!({"op":"position_search","dbId":dbid,"fen":"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1","limit":50}),
            )
        });
        println!(
            "[BENCH]   -> {} hits on page",
            r["rows"].as_array().map(|a| a.len()).unwrap_or(0)
        );
    }
    let exp = dir.join("export.pgn");
    let jid = call(
        h,
        json!({"op":"start_export","dbId":dbid,"path":exp.to_str().unwrap()}),
    )["jobId"]
        .as_i64()
        .unwrap();
    let t = Instant::now();
    loop {
        std::thread::sleep(std::time::Duration::from_millis(50));
        let st = call(h, json!({"op":"job_status","jobId":jid}));
        if st["state"] == "done" {
            println!(
                "[BENCH] export {} games: {:.2}s ({:.1} MB)",
                st["done"],
                t.elapsed().as_secs_f64(),
                std::fs::metadata(&exp).unwrap().len() as f64 / 1e6
            );
            break;
        }
    }
    ms("integrity_check", || {
        call(h, json!({"op":"integrity_check"}))
    });
    let _ = peak;
}
