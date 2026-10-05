//! C ABI for Dart FFI. Deliberately tiny and coarse-grained:
//! `cc_open`, `cc_request` (JSON in / JSON out), `cc_free`, `cc_close`.
//! Long operations (import / export / delete) run on their own thread with their own
//! SQLite connection (WAL allows concurrent readers) and are polled via `job_status`.

use crate::db::{self, ImportOptions};
use crate::pgn::IndexMode;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

struct Handle {
    path: String,
    conn: Mutex<rusqlite::Connection>,
}

struct Job {
    cancel: AtomicBool,
    status: Mutex<Value>,
}

#[derive(Default)]
struct Registry {
    handles: HashMap<i64, Arc<Handle>>,
    jobs: HashMap<i64, Arc<Job>>,
}

static REG: OnceLock<Mutex<Registry>> = OnceLock::new();
static NEXT: AtomicI64 = AtomicI64::new(1);

fn reg() -> &'static Mutex<Registry> {
    REG.get_or_init(|| Mutex::new(Registry::default()))
}

fn s(v: &Value, k: &str) -> Option<String> {
    v.get(k).and_then(|x| x.as_str()).map(|x| x.to_string())
}
fn n(v: &Value, k: &str) -> Option<i64> {
    v.get(k).and_then(|x| x.as_i64())
}
fn need_n(v: &Value, k: &str) -> Result<i64, String> {
    n(v, k).ok_or_else(|| format!("missing integer field '{k}'"))
}
fn ids(v: &Value) -> Vec<i64> {
    v.get("ids")
        .and_then(|x| x.as_array())
        .map(|a| a.iter().filter_map(|i| i.as_i64()).collect())
        .unwrap_or_default()
}

fn spawn_job(
    h: &Arc<Handle>,
    init: Value,
    work: impl FnOnce(&Arc<Job>, &str) + Send + 'static,
) -> i64 {
    let id = NEXT.fetch_add(1, Ordering::SeqCst);
    let job = Arc::new(Job {
        cancel: AtomicBool::new(false),
        status: Mutex::new(init),
    });
    reg().lock().unwrap().jobs.insert(id, job.clone());
    let path = h.path.clone();
    std::thread::spawn(move || {
        let j = job.clone();
        let r = catch_unwind(AssertUnwindSafe(|| work(&j, &path)));
        if r.is_err() {
            *j.status.lock().unwrap() =
                json!({"state":"failed","error":"internal error (panic) in native core"});
        }
    });
    id
}

fn dispatch(h: &Arc<Handle>, req: &Value) -> Result<Value, String> {
    let op = s(req, "op").ok_or("missing 'op'")?;
    match op.as_str() {
        // ---- jobs (do not touch the shared connection)
        "job_status" => {
            let id = need_n(req, "jobId")?;
            let job = reg()
                .lock()
                .unwrap()
                .jobs
                .get(&id)
                .cloned()
                .ok_or("unknown job")?;
            let st = job.status.lock().unwrap().clone();
            Ok(st)
        }
        "cancel_job" => {
            let id = need_n(req, "jobId")?;
            if let Some(job) = reg().lock().unwrap().jobs.get(&id) {
                job.cancel.store(true, Ordering::SeqCst);
            }
            Ok(json!(true))
        }
        "start_import" => {
            let db_id = need_n(req, "dbId")?;
            let file = s(req, "path").ok_or("missing 'path'")?;
            let opts = ImportOptions {
                batch_size: n(req, "batchSize").unwrap_or(1000).clamp(50, 20000) as usize,
                index_mode: IndexMode::parse(
                    &s(req, "indexMode").unwrap_or_else(|| "balanced".into()),
                ),
                resume_job: n(req, "resumeJob"),
                max_batches: n(req, "maxBatches").map(|x| x.max(1) as u64),
            };
            let id = spawn_job(
                h,
                json!({"state":"running","processed":0}),
                move |job, path| {
                    let result = db::open(path).and_then(|mut c| {
                        let job2 = job.clone();
                        db::run_import(
                            &mut c,
                            db_id,
                            Path::new(&file),
                            &opts,
                            &job.cancel,
                            &mut |p| {
                                *job2.status.lock().unwrap() = p.to_json();
                            },
                        )
                    });
                    match result {
                        Ok(sum) => {
                            let mut st = job.status.lock().unwrap();
                            st["state"] = json!(if sum.cancelled { "cancelled" } else { "done" });
                            st["seconds"] = json!(sum.seconds);
                            st["summary"] = json!({"imported":sum.imported,"duplicates":sum.duplicates,"invalid":sum.invalid,"processed":sum.processed});
                        }
                        Err(e) => *job.status.lock().unwrap() = json!({"state":"failed","error":e}),
                    }
                },
            );
            Ok(json!({"jobId": id}))
        }
        "start_export" => {
            let db_id = need_n(req, "dbId")?;
            let file = s(req, "path").ok_or("missing 'path'")?;
            let sel = req.get("ids").map(|_| ids(req));
            let id = spawn_job(
                h,
                json!({"state":"running","done":0,"total":0}),
                move |job, path| {
                    let r = db::open(path).and_then(|c| {
                        let j2 = job.clone();
                        db::export_pgn(
                            &c,
                            db_id,
                            sel.as_deref(),
                            Path::new(&file),
                            &job.cancel,
                            &mut |d, t| {
                                *j2.status.lock().unwrap() =
                                    json!({"state":"running","done":d,"total":t});
                            },
                        )
                    });
                    *job.status.lock().unwrap() = match r {
                        Ok(cnt) => {
                            json!({"state": if job.cancel.load(Ordering::SeqCst) {"cancelled"} else {"done"},"done":cnt,"total":cnt})
                        }
                        Err(e) => json!({"state":"failed","error":e}),
                    };
                },
            );
            Ok(json!({"jobId": id}))
        }
        "start_delete_database" => {
            let db_id = need_n(req, "dbId")?;
            let id = spawn_job(h, json!({"state":"running"}), move |job, path| {
                let r = db::open(path)
                    .and_then(|mut c| db::delete_database(&mut c, db_id, &job.cancel));
                *job.status.lock().unwrap() = match r {
                    Ok(()) => json!({"state":"done"}),
                    Err(e) => json!({"state":"failed","error":e}),
                };
            });
            Ok(json!({"jobId": id}))
        }
        // ---- short operations on the shared connection
        _ => {
            let mut c = h
                .conn
                .lock()
                .map_err(|_| "database lock poisoned".to_string())?;
            match op.as_str() {
                "list_databases" => db::list_databases(&c),
                "create_database" => {
                    let id = db::create_database(
                        &c,
                        &s(req, "name").unwrap_or_default(),
                        &s(req, "category").unwrap_or_else(|| "custom".into()),
                        n(req, "color").unwrap_or(0),
                        &s(req, "icon").unwrap_or_else(|| "folder".into()),
                        &s(req, "description").unwrap_or_default(),
                    )?;
                    Ok(json!({"id": id}))
                }
                "rename_database" => {
                    db::rename_database(&c, need_n(req, "id")?, &s(req, "name").unwrap_or_default())
                        .map(|_| json!(true))
                }
                "style_database" => db::update_database_style(
                    &c,
                    need_n(req, "id")?,
                    n(req, "color").unwrap_or(0),
                    &s(req, "icon").unwrap_or_else(|| "folder".into()),
                    &s(req, "category").unwrap_or_else(|| "custom".into()),
                )
                .map(|_| json!(true)),
                "set_reference" => db::set_reference(&c, n(req, "id")).map(|_| json!(true)),
                "get_reference" => db::get_reference(&c).map(|r| json!(r)),
                "search_games" => {
                    let f = req.get("filter").cloned().unwrap_or(json!({}));
                    let rows = db::search_games(
                        &c,
                        need_n(req, "dbId")?,
                        &f,
                        &s(req, "sort").unwrap_or_default(),
                        req.get("desc").and_then(|v| v.as_bool()).unwrap_or(false),
                        n(req, "offset").unwrap_or(0),
                        n(req, "limit").unwrap_or(50),
                    )?;
                    Ok(json!({"rows": rows}))
                }
                "count_games" => db::count_games(
                    &c,
                    need_n(req, "dbId")?,
                    &req.get("filter").cloned().unwrap_or(json!({})),
                )
                .map(|x| json!(x)),
                "get_game" => db::get_game_pgn(&c, need_n(req, "id")?),
                "save_pgn" => db::save_pgn_text(
                    &mut c,
                    need_n(req, "dbId")?,
                    &s(req, "pgn").unwrap_or_default(),
                    IndexMode::parse(&s(req, "indexMode").unwrap_or_else(|| "balanced".into())),
                ),
                "favorite" => db::set_favorite(
                    &c,
                    need_n(req, "id")?,
                    req.get("value").and_then(|v| v.as_bool()).unwrap_or(true),
                )
                .map(|_| json!(true)),
                "delete_games" => db::delete_games(&mut c, &ids(req)).map(|x| json!(x)),
                "delete_database" => {
                    let cancel = AtomicBool::new(false);
                    db::delete_database(&mut c, need_n(req, "dbId")?, &cancel).map(|_| json!(true))
                }
                "copy_games" => db::copy_games(&mut c, &ids(req), need_n(req, "target")?, false),
                "move_games" => db::copy_games(&mut c, &ids(req), need_n(req, "target")?, true),
                "position_search" => db::position_search(
                    &c,
                    need_n(req, "dbId")?,
                    &s(req, "fen").unwrap_or_default(),
                    n(req, "limit").unwrap_or(50),
                    n(req, "offset").unwrap_or(0),
                ),
                "stats" => db::database_stats(&c, need_n(req, "dbId")?),
                "integrity_check" => db::integrity_check(&c),
                "vacuum" => c
                    .execute_batch("VACUUM")
                    .map(|_| json!(true))
                    .map_err(|e| e.to_string()),
                "import_errors" => {
                    db::import_errors(&c, need_n(req, "jobId")?, n(req, "limit").unwrap_or(200))
                }
                "unfinished_imports" => db::unfinished_jobs(&c),
                "version" => {
                    Ok(json!({"core":env!("CARGO_PKG_VERSION"),"schema":db::SCHEMA_VERSION}))
                }
                other => Err(format!("unknown op '{other}'")),
            }
        }
    }
}

/// Run a JSON request against an open handle (also used by tests / bench).
pub fn handle_request(handle: i64, request: &str) -> String {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let h = reg().lock().unwrap().handles.get(&handle).cloned();
        let h = match h {
            Some(h) => h,
            None => return json!({"error":"invalid database handle"}),
        };
        let req: Value = match serde_json::from_str(request) {
            Ok(v) => v,
            Err(e) => return json!({"error": format!("bad request JSON: {e}")}),
        };
        match dispatch(&h, &req) {
            Ok(v) => json!({"ok": v}),
            Err(e) => json!({"error": e}),
        }
    }))
    .unwrap_or_else(|_| json!({"error":"internal error (panic) in native core"}));
    out.to_string()
}

pub fn open_handle(path: &str) -> Result<i64, String> {
    let conn = db::open(path)?;
    let id = NEXT.fetch_add(1, Ordering::SeqCst);
    reg().lock().unwrap().handles.insert(
        id,
        Arc::new(Handle {
            path: path.to_string(),
            conn: Mutex::new(conn),
        }),
    );
    Ok(id)
}

fn cstr(p: *const c_char) -> Option<String> {
    if p.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(p) }
        .to_str()
        .ok()
        .map(|s| s.to_string())
}

fn into_c(s: String) -> *mut c_char {
    CString::new(s.replace('\0', " ")).unwrap().into_raw()
}

/// Opens (creating/migrating) a database. Returns a handle > 0, or 0 on failure (see `cc_last_error`).
#[no_mangle]
pub extern "C" fn cc_open(path: *const c_char) -> i64 {
    let Some(p) = cstr(path) else { return 0 };
    match catch_unwind(|| open_handle(&p)) {
        Ok(Ok(h)) => h,
        Ok(Err(e)) => {
            *LAST_ERR.lock().unwrap() = e;
            0
        }
        Err(_) => {
            *LAST_ERR.lock().unwrap() = "panic while opening database".into();
            0
        }
    }
}

static LAST_ERR: Mutex<String> = Mutex::new(String::new());

#[no_mangle]
pub extern "C" fn cc_last_error() -> *mut c_char {
    into_c(LAST_ERR.lock().unwrap().clone())
}

#[no_mangle]
pub extern "C" fn cc_request(handle: i64, json_request: *const c_char) -> *mut c_char {
    let req = cstr(json_request).unwrap_or_default();
    into_c(handle_request(handle, &req))
}

#[no_mangle]
pub extern "C" fn cc_close(handle: i64) {
    reg().lock().unwrap().handles.remove(&handle);
}

/// # Safety
/// `p` must come from `cc_request` / `cc_last_error`, and be freed exactly once.
#[no_mangle]
pub unsafe extern "C" fn cc_free(p: *mut c_char) {
    if !p.is_null() {
        drop(CString::from_raw(p));
    }
}
