/* ==================== SAFE KEY-VALUE (localStorage → memory) ==================== */
const _mem = {};
let _lsOk = false;
try { window.localStorage.setItem("__t", "1"); window.localStorage.removeItem("__t"); _lsOk = true; } catch (e) {}
const LS = {
  get: (k) => { try { return _lsOk ? window.localStorage.getItem(k) : (k in _mem ? _mem[k] : null); } catch (e) { return k in _mem ? _mem[k] : null; } },
  set: (k, v) => { try { if (_lsOk) window.localStorage.setItem(k, v); else _mem[k] = v; } catch (e) { _mem[k] = v; } },
};
const jget = (k, d) => { const v = LS.get(k); if (v == null) return d; try { return JSON.parse(v); } catch (e) { return d; } };
const jset = (k, v) => LS.set(k, JSON.stringify(v));

/* ==================== INDEXEDDB (for the SQLite blob) ==================== */
function idbOpen() {
  return new Promise((res, rej) => {
    const r = indexedDB.open("cuttracker_db", 1);
    r.onupgradeneeded = () => r.result.createObjectStore("kv");
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  });
}
async function idbGet(key) {
  const db = await idbOpen();
  return new Promise((res, rej) => {
    const t = db.transaction("kv", "readonly").objectStore("kv").get(key);
    t.onsuccess = () => res(t.result); t.onerror = () => rej(t.error);
  });
}
async function idbSet(key, val) {
  const db = await idbOpen();
  return new Promise((res, rej) => {
    const t = db.transaction("kv", "readwrite").objectStore("kv").put(val, key);
    t.onsuccess = () => res(true); t.onerror = () => rej(t.error);
  });
}

/* ==================== BACKEND (SQLite via sql.js, else localStorage) ==================== */
let SQLDB = null;         // sql.js Database instance
let USING_SQL = false;

async function persistSql() {
  if (USING_SQL && SQLDB) { try { await idbSet("sqlite", SQLDB.export()); } catch (e) {} }
}

export async function initBackend() {
  try {
    if (typeof window === "undefined" || !window.initSqlJs) throw new Error("sql.js not present");
    const wasmUrl = window.__SQL_WASM__ || "https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.10.3/sql-wasm.wasm";
    const SQL = await window.initSqlJs({ locateFile: () => wasmUrl });
    const saved = await idbGet("sqlite");
    SQLDB = saved ? new SQL.Database(new Uint8Array(saved)) : new SQL.Database();
    SQLDB.run(`
      CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, created TEXT);
      CREATE TABLE IF NOT EXISTS kv(uid INTEGER, k TEXT, v TEXT, PRIMARY KEY(uid,k));
      CREATE TABLE IF NOT EXISTS foods(id INTEGER PRIMARY KEY AUTOINCREMENT, uid INTEGER, name TEXT, kcal REAL, protein REAL);
      CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT);
    `);
    USING_SQL = true;
    await persistSql();
    return "sqlite";
  } catch (e) {
    USING_SQL = false;
    return "localStorage";
  }
}

export const Backend = {
  mode: () => (USING_SQL ? "sqlite" : "localStorage"),

  async listUsers() {
    if (USING_SQL) {
      const rows = []; const s = SQLDB.prepare("SELECT id,name,created FROM users ORDER BY id");
      while (s.step()) rows.push(s.getAsObject()); s.free(); return rows;
    }
    return jget("ct2.users", []);
  },

  async addUser(name) {
    if (USING_SQL) {
      SQLDB.run("INSERT INTO users(name,created) VALUES(?,?)", [name, new Date().toISOString()]);
      const s = SQLDB.prepare("SELECT last_insert_rowid() AS id"); s.step();
      const id = s.getAsObject().id; s.free(); await persistSql(); return id;
    }
    const users = jget("ct2.users", []);
    const id = (users.reduce((m, u) => Math.max(m, u.id), 0) || 0) + 1;
    users.push({ id, name, created: new Date().toISOString() });
    jset("ct2.users", users); return id;
  },

  async renameUser(id, name) {
    if (USING_SQL) { SQLDB.run("UPDATE users SET name=? WHERE id=?", [name, id]); await persistSql(); return; }
    const users = jget("ct2.users", []).map((u) => (u.id === id ? { ...u, name } : u));
    jset("ct2.users", users);
  },

  async getMeta(k) {
    if (USING_SQL) { const s = SQLDB.prepare("SELECT v FROM meta WHERE k=?"); s.bind([k]); const v = s.step() ? s.getAsObject().v : null; s.free(); return v; }
    return jget("ct2.meta", {})[k] ?? null;
  },
  async setMeta(k, v) {
    if (USING_SQL) { SQLDB.run("INSERT INTO meta(k,v) VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=?", [k, v, v]); await persistSql(); return; }
    const m = jget("ct2.meta", {}); m[k] = v; jset("ct2.meta", m);
  },

  async getUserData(uid) {
    if (USING_SQL) {
      const out = {}; const s = SQLDB.prepare("SELECT k,v FROM kv WHERE uid=?"); s.bind([uid]);
      while (s.step()) { const r = s.getAsObject(); try { out[r.k] = JSON.parse(r.v); } catch (e) { out[r.k] = r.v; } }
      s.free(); return out;
    }
    return jget("ct2.kv." + uid, {});
  },
  async setUserKV(uid, k, v) {
    const json = JSON.stringify(v);
    if (USING_SQL) { SQLDB.run("INSERT INTO kv(uid,k,v) VALUES(?,?,?) ON CONFLICT(uid,k) DO UPDATE SET v=?", [uid, k, json, json]); await persistSql(); return; }
    const all = jget("ct2.kv." + uid, {}); all[k] = v; jset("ct2.kv." + uid, all);
  },

  async getFoods(uid) {
    if (USING_SQL) {
      const rows = []; const s = SQLDB.prepare("SELECT id,name,kcal,protein FROM foods WHERE uid=? ORDER BY id DESC"); s.bind([uid]);
      while (s.step()) rows.push(s.getAsObject()); s.free(); return rows;
    }
    return jget("ct2.foods." + uid, []);
  },
  async addFood(uid, f) {
    if (USING_SQL) {
      SQLDB.run("INSERT INTO foods(uid,name,kcal,protein) VALUES(?,?,?,?)", [uid, f.name, f.kcal, f.protein]);
      await persistSql(); return;
    }
    const list = jget("ct2.foods." + uid, []);
    list.unshift({ id: Date.now(), name: f.name, kcal: f.kcal, protein: f.protein });
    jset("ct2.foods." + uid, list);
  },
  async deleteFood(uid, id) {
    if (USING_SQL) { SQLDB.run("DELETE FROM foods WHERE id=?", [id]); await persistSql(); return; }
    jset("ct2.foods." + uid, jget("ct2.foods." + uid, []).filter((f) => f.id !== id));
  },

  exportBlob() { return USING_SQL && SQLDB ? SQLDB.export() : null; },
};
