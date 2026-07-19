import { useState, useEffect, useCallback, useMemo, useRef, createContext, useContext } from "react";
import {
  Home, Dumbbell, BookOpen, TrendingUp, Utensils, Plus, Minus, Check, ChevronRight, ChevronLeft,
  X, Play, Settings as SettingsIcon, Flame, Droplet, Scale, Clock, Award, ArrowUp,
  RotateCcw, Footprints, Moon, Heart, Activity, User, Users, Target, Salad, Egg, Drumstick,
  Sparkles, Save, ChevronDown, CalendarDays, Trophy
} from "lucide-react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, AreaChart, Area } from "recharts";

/* ============================ THEME ============================ */
const T = {
  bg: "#0C0C0D", surface: "#161618", surface2: "#1E1E21", line: "#2A2A2E",
  text: "#EDEAE3", muted: "#8B8B92", faint: "#5A5A60",
  accent: "#F0A23C", accentSoft: "rgba(240,162,60,0.42)", accentDim: "rgba(240,162,60,0.12)",
  success: "#7FCB86", danger: "#E06C5A", muscleBase: "#34343B", blue: "#6FA8DC",
};

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

async function initBackend() {
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

const Backend = {
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

/* ============================ HELPERS ============================ */
const todayStr = () => new Date().toISOString().slice(0, 10);
const fmtDay = (iso) => new Date(iso + "T00:00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" });
const fmtFull = () => new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
const epley = (w, r) => Math.round(w * (1 + r / 30));
const topReps = (range) => parseInt(String(range).split("-").pop(), 10);
const lowReps = (range) => parseInt(String(range).split("-")[0], 10);
const round5 = (n) => Math.round(n / 5) * 5;
const round10 = (n) => Math.round(n / 10) * 10;
const daysBetween = (a, b) => Math.round((new Date(b) - new Date(a)) / 86400000);
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

/* ============================ KNOWLEDGE BASE ============================ */
const yt = (n) => "https://www.youtube.com/results?search_query=" + encodeURIComponent(n + " proper form technique");
const L = (g, view, primary, secondary, target, desc, cues) => ({ g, view, primary, secondary, target, desc, cues });

// Respects user's excluded lifts: no deadlift, RDL, walking lunge, single-arm DB row.
const LIB = {
  // ---- CHEST ----
  "Barbell Bench Press": L("Chest", "front", ["chest"], ["frontDelts"], "Chest, Front Delts, Triceps",
    "The main horizontal press and your key upper-body strength driver. Keep it heavy while cutting.",
    ["Retract and pin the shoulder blades", "Lower to mid-chest with a slight arch", "Drive up and slightly back over the shoulders"]),
  "Incline Barbell Press": L("Chest", "front", ["chest"], ["frontDelts"], "Upper Chest, Front Delts",
    "Barbell incline targets the upper chest with heavy loading.", ["30–45° bench angle", "Lower to the upper chest", "Keep blades retracted"]),
  "Incline Dumbbell Press": L("Chest", "front", ["chest"], ["frontDelts"], "Upper Chest, Front Delts",
    "Dumbbells give a deeper, joint-friendly stretch on the upper chest.", ["Bench at 30°", "Lower for an upper-chest stretch", "Press up and slightly together"]),
  "Flat Dumbbell Press": L("Chest", "front", ["chest"], ["frontDelts"], "Chest, Triceps",
    "Dumbbell version of the flat press for a bigger range of motion.", ["Control the descent", "Wrists stacked over elbows", "Press without clashing the bells"]),
  "Pec Deck Fly": L("Chest", "front", ["chest"], [], "Chest (isolation)",
    "Constant-tension chest isolation — great low-fatigue stimulus on a cut.", ["Soft bend in the elbows", "Squeeze pecs at the front", "Control the negative"]),
  "Cable Crossover": L("Chest", "front", ["chest"], ["frontDelts"], "Chest (isolation)",
    "Cables keep tension through the whole range for a strong contraction.", ["Slight forward lean", "Bring hands together and down", "Squeeze, then control back"]),
  "Push-Up": L("Chest", "front", ["chest"], ["frontDelts"], "Chest, Triceps, Core",
    "Bodyweight staple you can do anywhere — great finisher.", ["Body in a straight line", "Elbows ~45° from torso", "Full lockout at the top"]),
  "Machine Chest Press": L("Chest", "front", ["chest"], ["frontDelts"], "Chest, Triceps",
    "Fixed-path press — safe to push close to failure with no spotter.", ["Handles at mid-chest height", "Press without shrugging", "Control the return"]),
  "Smith Machine Bench Press": L("Chest", "front", ["chest"], ["frontDelts"], "Chest, Triceps",
    "Guided-bar bench press — same stimulus, easier to bail out of.", ["Bar path fixed, still tuck elbows", "Lower to mid-chest", "Drive up under control"]),
  "Incline Cable Fly": L("Chest", "front", ["chest"], ["frontDelts"], "Upper Chest (isolation)",
    "Low-to-high cable angle biases the upper chest under constant tension.", ["Set pulleys low", "Sweep hands up and in", "Squeeze at the top, don't shrug"]),
  "Decline Dumbbell Press": L("Chest", "front", ["chest"], ["frontDelts"], "Lower Chest, Triceps",
    "Decline angle shifts emphasis to the lower chest fibers.", ["Bench declined ~15–20°", "Lower under control", "Press up and slightly in"]),
  "Weighted Dips": L("Chest", "front", ["chest"], ["frontDelts"], "Lower Chest, Triceps",
    "Add load once bodyweight dips get easy — big lower-chest builder.", ["Lean forward for chest emphasis", "Lower to a deep stretch", "Press up without swinging"]),

  // ---- BACK ----
  "Wide Grip Lat Pulldown": L("Back", "back", ["lats"], ["upperBack", "rearDelts"], "Lats, Upper Back",
    "Builds lat width for the V-taper.", ["Pull elbows down and in", "Bar to the upper chest", "Control the stretch at the top"]),
  "Lat Pulldown": L("Back", "back", ["lats"], ["upperBack", "rearDelts"], "Lats",
    "Vertical pull; vary the grip from your wide-grip day.", ["Chest up, slight lean", "Pull to the collarbone", "Feel the lats, not the arms"]),
  "Chest Supported Row": L("Back", "back", ["upperBack", "lats"], ["rearDelts", "traps"], "Mid Back, Lats",
    "Strict back thickness with zero lower-back strain — ideal in a deficit.", ["Let the pad take your weight", "Row to the lower ribs", "Squeeze the blades"]),
  "Seated Cable Row": L("Back", "back", ["lats", "upperBack"], ["rearDelts"], "Mid Back, Lats",
    "Horizontal pull with constant tension.", ["Sit tall, small lean to stretch", "Drive elbows back", "No lower-back heaving"]),
  "Barbell Row": L("Back", "back", ["lats", "upperBack"], ["rearDelts", "traps"], "Back (compound)",
    "Heavy horizontal pull for overall back mass.", ["Hinge to ~45°, flat back", "Row to the lower chest/belly", "Control — no jerking"]),
  "T-Bar Row": L("Back", "back", ["upperBack", "lats"], ["traps", "rearDelts"], "Mid Back",
    "Supported-feel heavy row that hammers the mid-back.", ["Neutral grip, flat back", "Drive elbows back", "Squeeze at the top"]),
  "Straight Arm Pulldown": L("Back", "back", ["lats"], [], "Lats (isolation)",
    "Isolates the lats through shoulder extension.", ["Slight elbow bend, locked", "Pull the bar to the thighs", "Feel the lats stretch and contract"]),
  "Assisted Pull-Up": L("Back", "back", ["lats"], ["upperBack", "rearDelts"], "Lats, Upper Back",
    "Machine-assisted bodyweight pull — builds toward strict pull-ups.", ["Full stretch at the bottom", "Pull chest toward the bar", "Lower with control, no dropping"]),
  "Single Arm Lat Pulldown": L("Back", "back", ["lats"], ["upperBack"], "Lats (unilateral)",
    "Unilateral pulldown to even out left/right lat development.", ["Anchor the working side", "Pull elbow down and back", "Control the stretch each rep"]),
  "Machine High Row": L("Back", "back", ["upperBack", "lats"], ["rearDelts"], "Mid Back",
    "Chest-supported machine row — thickness without spinal load.", ["Chest against the pad", "Drive elbows back and up", "Squeeze the shoulder blades"]),
  "Reverse Grip Cable Row": L("Back", "back", ["lats", "upperBack"], ["biceps"], "Lats, Biceps",
    "Underhand grip shifts more work onto the lats and biceps.", ["Palms up on the handle", "Row to the lower ribs", "Elbows brush the sides"]),
  "Pull-Up": L("Back", "back", ["lats"], ["upperBack", "rearDelts"], "Lats, Upper Back",
    "The bodyweight benchmark pull once you're strong enough for full reps.", ["Dead hang start", "Pull chin over the bar", "Lower fully under control"]),

  // ---- SHOULDERS ----
  "Overhead Press": L("Shoulders", "front", ["frontDelts", "sideDelts"], ["traps"], "Shoulders (compound)",
    "The main vertical press for shoulder strength and size.", ["Brace the core, glutes tight", "Press in a straight line", "Bar over mid-foot at lockout"]),
  "Machine Shoulder Press": L("Shoulders", "front", ["frontDelts", "sideDelts"], [], "Shoulders",
    "Stable pressing — safe to push near failure when tired.", ["Handles at shoulder height", "Press without shrugging", "Don't lock out harshly"]),
  "Dumbbell Lateral Raise": L("Shoulders", "front", ["sideDelts"], ["traps"], "Side Delts",
    "The key to shoulder width. High reps, strict form.", ["Lead with the elbows", "Raise to shoulder height", "Slight pour-the-jug tilt"]),
  "Cable Lateral Raise": L("Shoulders", "front", ["sideDelts"], [], "Side Delts",
    "Constant cable tension on the side delts.", ["Cable behind the body", "Lead with the elbow", "Controlled down"]),
  "Face Pull": L("Shoulders", "back", ["rearDelts"], ["traps", "upperBack"], "Rear Delts, Upper Back",
    "Shoulder-health insurance for the rear delts and rotators.", ["Cable at face height", "Pull to the forehead", "Elbows high, rotate hands back"]),
  "Rear Delt Fly": L("Shoulders", "back", ["rearDelts"], ["upperBack"], "Rear Delts",
    "Direct rear-delt work for 3D shoulders.", ["Hinge forward slightly", "Lead with elbows, wide arc", "Pause at the top"]),
  "Front Raise": L("Shoulders", "front", ["frontDelts"], [], "Front Delts",
    "Targets the front delts (usually a bonus after pressing).", ["Raise to eye level", "No swinging", "Controlled lowering"]),
  "Dumbbell Shoulder Press": L("Shoulders", "front", ["frontDelts", "sideDelts"], ["triceps"], "Shoulders",
    "Free-weight press with a bigger stabilizer demand than machines.", ["Start at ear height", "Press up without arching hard", "Control the descent"]),
  "Arnold Press": L("Shoulders", "front", ["frontDelts", "sideDelts"], ["traps"], "All-round Shoulders",
    "Rotating press that hits front and side delts through the arc.", ["Start palms facing you", "Rotate out as you press", "Reverse the rotation lowering"]),
  "Machine Lateral Raise": L("Shoulders", "front", ["sideDelts"], [], "Side Delts",
    "Fixed path lets you push side-delt sets hard with strict form.", ["Pads on the outside of the upper arm", "Raise without shrugging", "Slow negative"]),
  "Upright Row": L("Shoulders", "front", ["sideDelts", "traps"], [], "Side Delts, Traps",
    "Vertical pull that adds width to the shoulders and traps.", ["Grip just outside the thighs", "Lead with the elbows, pull to chest height", "Don't pull above shoulder height"]),
  "Landmine Press": L("Shoulders", "front", ["frontDelts"], ["chest"], "Front Delts, Chest",
    "Shoulder-friendly angled press — easy on cranky joints.", ["Bar in the rack of the shoulder", "Press up and slightly forward", "Control it back down"]),

  // ---- ARMS ----
  "Barbell Curl": L("Arms", "front", ["biceps"], ["forearms"], "Biceps",
    "Classic biceps mass builder; strict reps retain muscle on a cut.", ["Elbows pinned to sides", "No swinging", "Control the lowering"]),
  "EZ Bar Curl": L("Arms", "front", ["biceps"], ["forearms"], "Biceps",
    "Wrist-friendly angled bar, still loads the biceps heavily.", ["Elbows at your sides", "Curl under control", "Full squeeze at the top"]),
  "Incline Dumbbell Curl": L("Arms", "front", ["biceps"], ["forearms"], "Biceps (long head)",
    "Incline stretches the long head for peak development.", ["Lie back on a 45–60° bench", "Let arms hang, then curl", "Slow eccentric"]),
  "Hammer Curl": L("Arms", "front", ["biceps", "forearms"], [], "Biceps (brachialis), Forearms",
    "Neutral grip adds arm thickness.", ["Palms face each other", "Wrists neutral and firm", "No body english"]),
  "Rope Tricep Pushdown": L("Arms", "back", ["triceps"], [], "Triceps",
    "Cable triceps staple; spread the rope at the bottom.", ["Pin elbows to sides", "Spread the rope at lockout", "Torso still"]),
  "Overhead Cable Tricep Extension": L("Arms", "back", ["triceps"], [], "Triceps (long head)",
    "Overhead puts the long head on stretch — best for size.", ["Upper arms beside the head", "Full stretch behind the head", "Extend without flaring"]),
  "Skull Crushers": L("Arms", "back", ["triceps"], [], "Triceps",
    "EZ-bar lying extension for heavy triceps loading.", ["Lower to the forehead/behind", "Elbows pointed up", "Extend without flaring"]),
  "Dips": L("Arms", "front", ["chest"], ["frontDelts"], "Triceps, Lower Chest",
    "Bodyweight compound for triceps and lower chest.", ["Upright = triceps, lean = chest", "Lower to ~90°", "Don't shrug at the top"]),
  "Cable Curl": L("Arms", "front", ["biceps"], ["forearms"], "Biceps",
    "Constant tension biceps work — no dead spot at the top or bottom.", ["Elbows fixed at your sides", "Curl through the full range", "Control the negative"]),
  "Preacher Curl": L("Arms", "front", ["biceps"], [], "Biceps (short head)",
    "Pad locks the upper arm so the biceps do all the work.", ["Upper arms flat on the pad", "Don't bounce out of the bottom", "Squeeze at the top"]),
  "Machine Tricep Extension": L("Arms", "back", ["triceps"], [], "Triceps",
    "Fixed-path triceps isolation, easy to load progressively.", ["Elbows pinned at the pivot", "Extend to full lockout", "Control back to the stretch"]),
  "Close Grip Bench Press": L("Arms", "front", ["triceps"], ["chest"], "Triceps, Chest",
    "Compound press that lets you overload the triceps heavily.", ["Hands just inside shoulder width", "Elbows track close to the body", "Press up without flaring"]),
  "Diamond Push-Up": L("Arms", "front", ["triceps"], ["chest"], "Triceps, Chest",
    "Bodyweight triceps finisher — no equipment needed.", ["Hands form a diamond under the chest", "Elbows stay close to the body", "Full lockout at the top"]),

  // ---- LEGS ----
  "Barbell Squat": L("Legs", "front", ["quads"], ["abs"], "Quads, Glutes, Core",
    "Main lower-body strength lift — heavy 6–8s protect leg muscle in a deficit.", ["Brace hard before descending", "Sit to depth between the hips", "Drive through mid-foot"]),
  "Hack Squat": L("Legs", "front", ["quads"], [], "Quads, Glutes",
    "Machine squat that hammers the quads on a fixed path.", ["Feet slightly low for quads", "Descend deep and controlled", "Drive through the whole foot"]),
  "Leg Press": L("Legs", "front", ["quads"], [], "Quads, Glutes",
    "Loadable quad work without spinal fatigue.", ["Feet shoulder-width", "Lower to ~90°", "Don't lock out hard"]),
  "Goblet Squat": L("Legs", "front", ["quads"], ["abs"], "Quads, Core",
    "Simple, joint-friendly squat with a dumbbell — great warm-up or main.", ["Hold the bell at the chest", "Elbows inside the knees at the bottom", "Chest tall"]),
  "Bulgarian Split Squat": L("Legs", "front", ["quads"], ["abs"], "Quads, Glutes",
    "Single-leg builder for balanced legs (not walking lunges).", ["Rear foot on a bench", "Drop straight down", "Drive through the front heel"]),
  "Leg Extension": L("Legs", "front", ["quads"], [], "Quads (isolation)",
    "Pure quad isolation and a strong finisher.", ["Pause and squeeze at the top", "Control the negative", "Point toes to bias the sweep"]),
  "Lying Leg Curl": L("Legs", "back", ["hamstrings"], ["calves"], "Hamstrings",
    "Direct hamstring flexion — essential since we skip deadlift variations.", ["Hips pressed into the pad", "Curl all the way up", "Slow eccentric"]),
  "Seated Leg Curl": L("Legs", "back", ["hamstrings"], ["calves"], "Hamstrings",
    "Seated version emphasises the hamstrings under stretch.", ["Thighs locked down", "Curl fully under", "Controlled release"]),
  "Hip Thrust": L("Legs", "back", ["glutes"], ["hamstrings"], "Glutes, Hamstrings",
    "The best direct glute builder — fills the gap left by skipping deadlifts.", ["Chin tucked, ribs down", "Drive hips to full lockout", "Squeeze hard at the top"]),
  "Standing Calf Raise": L("Legs", "back", ["calves"], [], "Calves (gastrocnemius)",
    "Straight-leg raise for the larger calf muscle.", ["Full stretch at the bottom", "Rise onto the big toe", "Pause at the top"]),
  "Seated Calf Raise": L("Legs", "back", ["calves"], [], "Calves (soleus)",
    "Bent knee targets the soleus.", ["Deep stretch each rep", "Slow tempo", "Squeeze at the top"]),
  "Front Squat": L("Legs", "front", ["quads"], ["abs"], "Quads, Core",
    "Front-loaded squat that's brutal on the quads and upright posture.", ["Bar rests on the front delts", "Elbows up, torso upright", "Sit straight down between the hips"]),
  "Smith Machine Squat": L("Legs", "front", ["quads"], ["abs"], "Quads, Glutes",
    "Guided-bar squat — lets you push hard without balance worries.", ["Feet slightly forward of the bar", "Descend under control", "Drive up through the whole foot"]),
  "Walking Step-Up": L("Legs", "front", ["quads"], ["glutes"], "Quads, Glutes",
    "Single-leg step pattern that builds balanced leg strength.", ["Step onto a knee-height box", "Drive through the front heel", "Stand tall at the top, don't push off the back foot"]),
  "Glute Bridge": L("Legs", "back", ["glutes"], ["hamstrings"], "Glutes",
    "Bodyweight/light-load glute builder, easy on the lower back.", ["Feet hip-width, knees bent", "Drive hips up, squeeze glutes", "Lower under control"]),
  "Machine Hip Abduction": L("Legs", "back", ["glutes"], [], "Glutes (medius)",
    "Isolates the outer glutes — good for hip stability and shape.", ["Sit tall, back against the pad", "Push knees outward against resistance", "Control the return"]),

  // ---- CORE ----
  "Hanging Leg Raise": L("Core", "front", ["abs"], [], "Lower Abs",
    "Hardcore lower-ab work off a bar.", ["No swinging", "Curl the pelvis up", "Lower under control"]),
  "Cable Crunch": L("Core", "front", ["abs"], [], "Abs",
    "Loadable ab flexion for progressive overload.", ["Hips fixed, hinge at the spine", "Crunch down with the abs", "Control back up"]),
  "Plank": L("Core", "front", ["abs"], [], "Core (isometric)",
    "Simple anti-extension core stability hold.", ["Straight line head-to-heels", "Brace and squeeze glutes", "Don't let the hips sag"]),
  "Machine Ab Crunch": L("Core", "front", ["abs"], [], "Abs",
    "Loadable, joint-friendly ab flexion — easy to progress weekly.", ["Hips fixed against the pad", "Crunch down through the ribs", "Control the return, don't bounce"]),
  "Cable Woodchop": L("Core", "front", ["abs"], [], "Obliques, Core",
    "Rotational core work that carries over to real-world twisting strength.", ["Pivot the back foot as you rotate", "Pull from high to low (or low to high)", "Control the return, don't yank"]),
  "Hollow Body Hold": L("Core", "front", ["abs"], [], "Core (isometric)",
    "Bodyweight anti-extension hold — no equipment needed.", ["Lower back pressed into the floor", "Arms and legs extended, held just off the ground", "Breathe steadily, don't let the back arch"]),
  "Ab Wheel Rollout": L("Core", "front", ["abs"], [], "Abs, Core",
    "Advanced anti-extension move — very effective once you're ready for it.", ["Start on your knees", "Roll out only as far as you can control", "Brace hard and pull back to start"]),
  "Russian Twist": L("Core", "front", ["abs"], [], "Obliques",
    "Simple rotational core finisher, weighted or bodyweight.", ["Lean back to ~45°, feet up or down", "Rotate the torso side to side", "Keep the movement controlled, not flung"]),
};

const GROUPS = ["Chest", "Back", "Shoulders", "Legs", "Arms", "Core"];

/* ---- 5-day PPLUL program (loads/rep guidance adapt via goal, exercise list stays practical) ---- */
const PROGRAM = {
  Push: { focus: "Chest · Shoulders · Triceps", items: [
    { name: "Barbell Bench Press", sets: 4, reps: "6-8" },
    { name: "Incline Dumbbell Press", sets: 3, reps: "8-10" },
    { name: "Pec Deck Fly", sets: 3, reps: "10-12" },
    { name: "Dumbbell Lateral Raise", sets: 4, reps: "12-15" },
    { name: "Rope Tricep Pushdown", sets: 3, reps: "10-12" },
    { name: "Overhead Cable Tricep Extension", sets: 3, reps: "10-12" },
  ]},
  Pull: { focus: "Back · Rear Delts · Biceps", items: [
    { name: "Wide Grip Lat Pulldown", sets: 4, reps: "8-10" },
    { name: "Chest Supported Row", sets: 4, reps: "8-10" },
    { name: "Seated Cable Row", sets: 3, reps: "10-12" },
    { name: "Face Pull", sets: 3, reps: "12-15" },
    { name: "Rear Delt Fly", sets: 3, reps: "12-15" },
    { name: "Barbell Curl", sets: 3, reps: "8-10" },
    { name: "Hammer Curl", sets: 3, reps: "10-12" },
  ]},
  Legs: { focus: "Quads · Hamstrings · Calves", items: [
    { name: "Barbell Squat", sets: 4, reps: "6-8" },
    { name: "Leg Press", sets: 4, reps: "10-12" },
    { name: "Leg Extension", sets: 3, reps: "12-15" },
    { name: "Lying Leg Curl", sets: 4, reps: "10-12" },
    { name: "Standing Calf Raise", sets: 4, reps: "15-20" },
    { name: "Seated Calf Raise", sets: 3, reps: "15-20" },
  ]},
  Upper: { focus: "Chest · Back · Shoulders · Arms", items: [
    { name: "Incline Barbell Press", sets: 3, reps: "8-10" },
    { name: "Lat Pulldown", sets: 3, reps: "8-10" },
    { name: "Seated Cable Row", sets: 3, reps: "10-12" },
    { name: "Machine Shoulder Press", sets: 3, reps: "8-10" },
    { name: "Dumbbell Lateral Raise", sets: 3, reps: "12-15" },
    { name: "EZ Bar Curl", sets: 3, reps: "10-12" },
    { name: "Rope Tricep Pushdown", sets: 3, reps: "10-12" },
  ]},
  Lower: { focus: "Quads · Glutes · Hamstrings", items: [
    { name: "Hack Squat", sets: 4, reps: "8-10" },
    { name: "Leg Press", sets: 3, reps: "10-12" },
    { name: "Lying Leg Curl", sets: 4, reps: "10-12" },
    { name: "Hip Thrust", sets: 3, reps: "8-10" },
    { name: "Leg Extension", sets: 3, reps: "12-15" },
    { name: "Seated Calf Raise", sets: 4, reps: "15-20" },
  ]},
};
const DAY_ORDER = ["Push", "Pull", "Legs", "Upper", "Lower"];
const WEEKDAY = { 1: "Push", 2: "Pull", 3: "Legs", 4: "Upper", 5: "Lower" };

/* ---- Foods for quick-add, filtered by diet preference (kcal, protein per portion) ---- */
const FOOD_DB = {
  base: [
    { name: "Oats 50g + whey", kcal: 330, protein: 37 },
    { name: "Greek yogurt 200g", kcal: 120, protein: 20 },
    { name: "Whey scoop", kcal: 120, protein: 24 },
    { name: "Milk 250ml", kcal: 150, protein: 8 },
    { name: "Peanut butter 2 tbsp", kcal: 190, protein: 8 },
    { name: "Banana", kcal: 105, protein: 1 },
    { name: "Rice 1 cup", kcal: 200, protein: 4 },
    { name: "Roti (1)", kcal: 120, protein: 3 },
    { name: "Dal 1 cup", kcal: 180, protein: 12 },
  ],
  veg: [
    { name: "Paneer 100g", kcal: 265, protein: 18 },
    { name: "Tofu 100g", kcal: 120, protein: 12 },
    { name: "Soya chunks 50g dry", kcal: 175, protein: 26 },
    { name: "Rajma 1 cup", kcal: 210, protein: 13 },
    { name: "Chickpeas 1 cup", kcal: 210, protein: 12 },
  ],
  egg: [
    { name: "Whole eggs (2)", kcal: 156, protein: 12 },
    { name: "Egg whites (3)", kcal: 51, protein: 11 },
    { name: "Paneer 100g", kcal: 265, protein: 18 },
    { name: "Soya chunks 50g dry", kcal: 175, protein: 26 },
  ],
  nonveg: [
    { name: "Chicken breast 100g", kcal: 165, protein: 31 },
    { name: "Fish 100g", kcal: 180, protein: 22 },
    { name: "Tuna can (100g)", kcal: 110, protein: 25 },
    { name: "Whole eggs (2)", kcal: 156, protein: 12 },
    { name: "Egg whites (3)", kcal: 51, protein: 11 },
  ],
};
const foodsForPref = (pref) => [...FOOD_DB.base, ...(FOOD_DB[pref] || FOOD_DB.veg)];

/* ---- Sample "bachelor-simple" meal day per preference (portions scale to the calorie target) ---- */
const MEAL_DAYS = {
  veg: [
    { time: "Breakfast", name: "Oats + whey + banana", kcal: 435, protein: 38 },
    { time: "Lunch", name: "Rice + dal + paneer bhurji", kcal: 620, protein: 33 },
    { time: "Snack", name: "Greek yogurt + peanut butter", kcal: 310, protein: 28 },
    { time: "Dinner", name: "Roti + rajma + salad", kcal: 500, protein: 22 },
    { time: "Before bed", name: "Milk + whey", kcal: 270, protein: 32 },
  ],
  egg: [
    { time: "Breakfast", name: "3-egg omelette + 2 toast", kcal: 400, protein: 26 },
    { time: "Lunch", name: "Rice + dal + paneer", kcal: 600, protein: 34 },
    { time: "Snack", name: "Greek yogurt + banana", kcal: 260, protein: 22 },
    { time: "Dinner", name: "Roti + soya curry", kcal: 480, protein: 30 },
    { time: "Before bed", name: "Milk + whey", kcal: 270, protein: 32 },
  ],
  nonveg: [
    { time: "Breakfast", name: "3 eggs + 2 toast", kcal: 380, protein: 26 },
    { time: "Lunch", name: "Rice + chicken curry + salad", kcal: 620, protein: 45 },
    { time: "Snack", name: "Greek yogurt + peanut butter", kcal: 310, protein: 28 },
    { time: "Dinner", name: "Roti + fish/chicken + veg", kcal: 500, protein: 38 },
    { time: "Before bed", name: "Milk + whey", kcal: 270, protein: 32 },
  ],
};

/* ============================ COACH: PLAN GENERATOR ============================ */
function generatePlan(p) {
  const kg = +p.currentWeight, tgt = +p.targetWeight, cm = +p.height, age = +p.age;
  const male = p.sex !== "female";
  const bmr = 10 * kg + 6.25 * cm - 5 * age + (male ? 5 : -161);
  const af = p.activity === "active" ? 1.725 : p.activity === "moderate" ? 1.55 : 1.375;
  const tdee = bmr * af;
  const days = Math.max(14, daysBetween(todayStr(), p.targetDate || todayStr()) || 84);

  let calorieGoal, weeklyRate, feasible = true, suggestedDate = null, headline;
  if (p.goalType === "fatLoss") {
    const kgToLose = Math.max(0, kg - tgt);
    const reqDeficit = (kgToLose * 7700) / days;
    const safeMax = Math.min(0.25 * tdee, 850);
    const deficit = clamp(reqDeficit || 400, 250, safeMax);
    calorieGoal = round10(Math.max(tdee - deficit, 1.2 * bmr));
    weeklyRate = +(((tdee - calorieGoal) * 7) / 7700).toFixed(2);
    feasible = reqDeficit <= safeMax + 1;
    if (!feasible) { const need = Math.ceil((kgToLose * 7700) / safeMax); suggestedDate = new Date(Date.now() + need * 86400000).toISOString().slice(0, 10); }
    headline = `Lose ~${weeklyRate}kg/week in a ${Math.round(tdee - calorieGoal)} kcal daily deficit.`;
  } else if (p.goalType === "weightGain") {
    const kgToGain = Math.max(0, tgt - kg);
    const reqSurplus = (kgToGain * 7700) / days;
    const surplus = clamp(reqSurplus || 300, 150, 500);
    calorieGoal = round10(tdee + surplus);
    weeklyRate = +((surplus * 7) / 7700).toFixed(2);
    feasible = reqSurplus <= 500 + 1;
    if (!feasible) { const need = Math.ceil((kgToGain * 7700) / 500); suggestedDate = new Date(Date.now() + need * 86400000).toISOString().slice(0, 10); }
    headline = `Gain ~${weeklyRate}kg/week in a ${Math.round(calorieGoal - tdee)} kcal daily surplus (lean bulk).`;
  } else {
    calorieGoal = round10(tdee); weeklyRate = 0;
    headline = `Maintain around ${calorieGoal} kcal/day.`;
  }

  const proteinPerKg = p.goalType === "fatLoss" ? 2.0 : 1.8;
  const proteinGoal = Math.max(130, Math.round(proteinPerKg * kg));
  const stepGoal = p.goalType === "fatLoss" ? 10000 : 8000;

  const cardioNote = p.goalType === "fatLoss"
    ? "2–3 easy 15–20 min incline walks after lifting, plus daily steps. Don't overdo cardio — muscle retention is the priority."
    : "Keep cardio light (steps + warm-ups). Extra cardio just eats into your surplus.";
  const splitNote = p.goalType === "weightGain"
    ? "5-day PPLUL, lower reps on the first lift (6–8), push progressive overload every week."
    : "5-day PPLUL, keep the main lifts heavy (6–8) to hold strength, higher reps on isolation.";

  const meals = MEAL_DAYS[p.dietPref] || MEAL_DAYS.veg;
  return {
    tdee: Math.round(tdee), bmr: Math.round(bmr), calorieGoal, proteinGoal, stepGoal,
    weeklyRate, feasible, suggestedDate, headline, cardioNote, splitNote, meals,
  };
}

/* ============================ MUSCLE MAP ============================ */
const FRONT = [
  { t: "circle", cx: 100, cy: 30, r: 15 }, { t: "rect", x: 93, y: 43, w: 14, h: 10, rx: 4 },
  { t: "rect", x: 72, y: 60, w: 56, h: 86, rx: 14 }, { t: "rect", x: 72, y: 144, w: 56, h: 22, rx: 8 },
  { t: "poly", pts: "84,55 116,55 124,72 76,72", region: "traps" },
  { t: "circle", cx: 62, cy: 70, r: 12, region: "frontDelts" }, { t: "circle", cx: 138, cy: 70, r: 12, region: "frontDelts" },
  { t: "circle", cx: 52, cy: 74, r: 9, region: "sideDelts" }, { t: "circle", cx: 148, cy: 74, r: 9, region: "sideDelts" },
  { t: "rect", x: 74, y: 64, w: 23, h: 28, rx: 10, region: "chest" }, { t: "rect", x: 103, y: 64, w: 23, h: 28, rx: 10, region: "chest" },
  { t: "rect", x: 86, y: 96, w: 28, h: 46, rx: 6, region: "abs" },
  { t: "rect", x: 48, y: 78, w: 15, h: 32, rx: 7, region: "biceps" }, { t: "rect", x: 137, y: 78, w: 15, h: 32, rx: 7, region: "biceps" },
  { t: "rect", x: 45, y: 112, w: 14, h: 40, rx: 7, region: "forearms" }, { t: "rect", x: 141, y: 112, w: 14, h: 40, rx: 7, region: "forearms" },
  { t: "rect", x: 75, y: 166, w: 23, h: 66, rx: 11, region: "quads" }, { t: "rect", x: 102, y: 166, w: 23, h: 66, rx: 11, region: "quads" },
  { t: "rect", x: 78, y: 234, w: 18, h: 60, rx: 8, region: "calves" }, { t: "rect", x: 104, y: 234, w: 18, h: 60, rx: 8, region: "calves" },
];
const BACK = [
  { t: "circle", cx: 100, cy: 30, r: 15 }, { t: "rect", x: 93, y: 43, w: 14, h: 10, rx: 4 },
  { t: "rect", x: 72, y: 60, w: 56, h: 86, rx: 14 }, { t: "rect", x: 72, y: 144, w: 56, h: 22, rx: 8 },
  { t: "poly", pts: "86,56 114,56 126,84 74,84", region: "traps" },
  { t: "circle", cx: 62, cy: 70, r: 12, region: "rearDelts" }, { t: "circle", cx: 138, cy: 70, r: 12, region: "rearDelts" },
  { t: "circle", cx: 52, cy: 74, r: 9, region: "sideDelts" }, { t: "circle", cx: 148, cy: 74, r: 9, region: "sideDelts" },
  { t: "rect", x: 84, y: 84, w: 32, h: 22, rx: 6, region: "upperBack" },
  { t: "poly", pts: "74,90 99,90 93,140 78,132", region: "lats" }, { t: "poly", pts: "126,90 101,90 107,140 122,132", region: "lats" },
  { t: "rect", x: 90, y: 126, w: 20, h: 20, rx: 6, region: "lowerBack" },
  { t: "rect", x: 48, y: 78, w: 15, h: 32, rx: 7, region: "triceps" }, { t: "rect", x: 137, y: 78, w: 15, h: 32, rx: 7, region: "triceps" },
  { t: "rect", x: 45, y: 112, w: 14, h: 40, rx: 7, region: "forearms" }, { t: "rect", x: 141, y: 112, w: 14, h: 40, rx: 7, region: "forearms" },
  { t: "rect", x: 76, y: 146, w: 23, h: 32, rx: 11, region: "glutes" }, { t: "rect", x: 101, y: 146, w: 23, h: 32, rx: 11, region: "glutes" },
  { t: "rect", x: 75, y: 178, w: 23, h: 56, rx: 11, region: "hamstrings" }, { t: "rect", x: 102, y: 178, w: 23, h: 56, rx: 11, region: "hamstrings" },
  { t: "rect", x: 78, y: 236, w: 18, h: 58, rx: 8, region: "calves" }, { t: "rect", x: 104, y: 236, w: 18, h: 58, rx: 8, region: "calves" },
];
function MuscleMap({ view = "front", primary = [], secondary = [], size = 120 }) {
  const shapes = view === "back" ? BACK : FRONT;
  const col = (r) => (!r ? T.muscleBase : primary.includes(r) ? T.accent : secondary.includes(r) ? T.accentSoft : T.muscleBase);
  return (
    <svg viewBox="0 0 200 305" width={size} height={size * 1.45} style={{ overflow: "visible" }}>
      {shapes.map((s, i) => {
        const fill = col(s.region), stroke = T.bg;
        if (s.t === "circle") return <circle key={i} cx={s.cx} cy={s.cy} r={s.r} fill={fill} stroke={stroke} strokeWidth="0.6" />;
        if (s.t === "poly") return <polygon key={i} points={s.pts} fill={fill} stroke={stroke} strokeWidth="0.6" />;
        return <rect key={i} x={s.x} y={s.y} width={s.w} height={s.h} rx={s.rx} fill={fill} stroke={stroke} strokeWidth="0.6" />;
      })}
    </svg>
  );
}

/* ============================ UI ATOMS ============================ */
const Card = ({ children, style, onClick }) => (
  <div onClick={onClick} style={{ background: T.surface, border: `1px solid ${T.line}`, borderRadius: 18, padding: 16, ...style }}>{children}</div>
);
const Mono = ({ children, style }) => <span className="mono" style={style}>{children}</span>;
const Eyebrow = ({ children }) => (
  <div className="mono" style={{ fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.faint, marginBottom: 8 }}>{children}</div>
);
function Ring({ value, goal, size = 132, label, unit, color }) {
  const pct = Math.min(1, goal ? value / goal : 0), r = size / 2 - 10, c = 2 * Math.PI * r, done = pct >= 1;
  const stroke = done ? T.success : (color || T.accent);
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={T.surface2} strokeWidth="10" />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={stroke} strokeWidth="10" strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={c * (1 - pct)} style={{ transition: "stroke-dashoffset .6s ease" }} />
      </svg>
      <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
        <Mono style={{ fontSize: size > 110 ? 26 : 22, fontWeight: 600, color: done ? T.success : T.text, lineHeight: 1 }}>{Math.round(value)}</Mono>
        <Mono style={{ fontSize: 11, color: T.muted, marginTop: 2 }}>/ {goal}{unit}</Mono>
        {label && <span style={{ fontSize: 10, color: T.muted, marginTop: 4 }}>{label}</span>}
      </div>
    </div>
  );
}
function Stepper({ value, onChange, step = 1, min = 0, suffix }) {
  const btn = { width: 40, height: 40, borderRadius: 12, border: `1px solid ${T.line}`, background: T.surface2, color: T.text, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", flexShrink: 0 };
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
      <div style={btn} onClick={() => onChange(Math.max(min, +(value - step).toFixed(2)))}><Minus size={18} /></div>
      <div style={{ minWidth: 60, textAlign: "center" }}>
        <Mono style={{ fontSize: 20, fontWeight: 600 }}>{value}</Mono>
        {suffix && <Mono style={{ fontSize: 11, color: T.muted, marginLeft: 3 }}>{suffix}</Mono>}
      </div>
      <div style={btn} onClick={() => onChange(+(value + step).toFixed(2))}><Plus size={18} /></div>
    </div>
  );
}
const overlay = { position: "fixed", inset: 0, background: "rgba(0,0,0,.6)", backdropFilter: "blur(4px)", zIndex: 100, display: "flex", alignItems: "flex-end", justifyContent: "center" };
const sheet = { background: T.bg, borderTop: `1px solid ${T.line}`, borderRadius: "24px 24px 0 0", padding: "22px 22px calc(22px + env(safe-area-inset-bottom))", width: "100%", maxWidth: 480, maxHeight: "90vh", overflowY: "auto", animation: "slideUp .25s ease" };
const primaryBtn = { background: T.accent, color: "#1A1206", textAlign: "center", padding: 15, borderRadius: 14, fontWeight: 650, cursor: "pointer" };

/* ============================ APP CONTEXT ============================ */
const DEFAULT_DATA = { settings: {}, weight: [], history: {}, sessions: {}, diet: {}, water: {}, activity: {}, photos: [], plan: null };
const AppCtx = createContext(null);
const useApp = () => useContext(AppCtx);

/* ============================ ONBOARDING (the coach) ============================ */
const OptBtn = ({ active, onClick, icon, label, sub }) => (
  <div onClick={onClick} style={{
    display: "flex", alignItems: "center", gap: 12, padding: 14, borderRadius: 14, cursor: "pointer",
    background: active ? T.accentDim : T.surface, border: `1px solid ${active ? T.accent : T.line}`, marginBottom: 10,
  }}>
    {icon && <div style={{ color: active ? T.accent : T.muted }}>{icon}</div>}
    <div style={{ flex: 1 }}>
      <div style={{ fontWeight: 600, fontSize: 15 }}>{label}</div>
      {sub && <div style={{ fontSize: 12, color: T.muted, marginTop: 2 }}>{sub}</div>}
    </div>
    {active && <Check size={18} color={T.accent} />}
  </div>
);
const NumIn = ({ value, onChange, ph, suffix }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 8, background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "0 14px" }}>
    <input value={value} onChange={(e) => onChange(e.target.value)} inputMode="decimal" placeholder={ph} className="mono"
      style={{ flex: 1, background: "transparent", border: "none", outline: "none", color: T.text, fontSize: 18, padding: "13px 0" }} />
    {suffix && <Mono style={{ color: T.muted, fontSize: 14 }}>{suffix}</Mono>}
  </div>
);

function Onboarding({ onComplete, onCancel }) {
  const [step, setStep] = useState(0);
  const [f, setF] = useState({
    name: "", sex: "male", age: "", height: "", currentWeight: "", targetWeight: "",
    targetDate: new Date(Date.now() + 84 * 86400000).toISOString().slice(0, 10),
    activity: "moderate", goalType: "fatLoss", dietPref: "veg", units: "kg",
  });
  const set = (patch) => setF((p) => ({ ...p, ...patch }));
  const steps = ["name", "sex", "stats", "goal", "target", "activity", "diet", "summary"];
  const cur = steps[step];
  const canNext = () => {
    if (cur === "name") return f.name.trim().length > 0;
    if (cur === "stats") return +f.age > 0 && +f.height > 0 && +f.currentWeight > 0;
    if (cur === "target") return f.goalType === "maintain" ? true : +f.targetWeight > 0 && !!f.targetDate;
    return true;
  };
  const next = () => {
    if (cur === "target" && f.goalType === "maintain" && !f.targetWeight) set({ targetWeight: f.currentWeight });
    if (step < steps.length - 1) setStep(step + 1); else finish();
  };
  const back = () => (step === 0 ? onCancel && onCancel() : setStep(step - 1));
  const finish = () => {
    const profile = { ...f, targetWeight: f.targetWeight || f.currentWeight };
    onComplete(profile, generatePlan(profile));
  };
  const plan = cur === "summary" ? generatePlan({ ...f, targetWeight: f.targetWeight || f.currentWeight }) : null;

  return (
    <div style={{ minHeight: "100vh", background: T.bg, color: T.text, maxWidth: 480, margin: "0 auto", padding: "calc(20px + env(safe-area-inset-top)) 18px calc(40px + env(safe-area-inset-bottom))", boxSizing: "border-box" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 6 }}>
        <ChevronLeft size={24} color={T.muted} onClick={back} style={{ cursor: "pointer" }} />
        <div style={{ flex: 1, height: 4, background: T.surface2, borderRadius: 2, overflow: "hidden" }}>
          <div style={{ width: `${((step + 1) / steps.length) * 100}%`, height: "100%", background: T.accent, transition: "width .3s" }} />
        </div>
      </div>

      <div style={{ paddingTop: 26 }}>
        {cur === "name" && <>
          <Sparkles size={30} color={T.accent} />
          <h1 style={{ fontSize: 26, fontWeight: 650, margin: "14px 0 6px" }}>Let's build your plan</h1>
          <p style={{ color: T.muted, fontSize: 14, marginTop: 0, marginBottom: 22 }}>I'll act as your trainer and nutritionist. First — what should I call you?</p>
          <input value={f.name} onChange={(e) => set({ name: e.target.value })} placeholder="Your name"
            style={{ width: "100%", boxSizing: "border-box", background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "14px", color: T.text, fontSize: 17, outline: "none" }} />
        </>}

        {cur === "sex" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 4 }}>Biological sex</h1>
          <p style={{ color: T.muted, fontSize: 13, marginTop: 0, marginBottom: 20 }}>Used only to estimate your calorie needs accurately.</p>
          <OptBtn active={f.sex === "male"} onClick={() => set({ sex: "male" })} label="Male" />
          <OptBtn active={f.sex === "female"} onClick={() => set({ sex: "female" })} label="Female" />
        </>}

        {cur === "stats" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Your stats</h1>
          <Eyebrow>Age</Eyebrow><div style={{ marginBottom: 14 }}><NumIn value={f.age} onChange={(v) => set({ age: v })} ph="28" suffix="yrs" /></div>
          <Eyebrow>Height</Eyebrow><div style={{ marginBottom: 14 }}><NumIn value={f.height} onChange={(v) => set({ height: v })} ph="175" suffix="cm" /></div>
          <Eyebrow>Current weight</Eyebrow><NumIn value={f.currentWeight} onChange={(v) => set({ currentWeight: v })} ph="78" suffix="kg" />
        </>}

        {cur === "goal" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Your goal</h1>
          <OptBtn active={f.goalType === "fatLoss"} onClick={() => set({ goalType: "fatLoss" })} icon={<Flame size={22} />} label="Lose fat" sub="Cut while keeping muscle" />
          <OptBtn active={f.goalType === "weightGain"} onClick={() => set({ goalType: "weightGain" })} icon={<TrendingUp size={22} />} label="Build muscle" sub="Lean weight gain" />
          <OptBtn active={f.goalType === "maintain"} onClick={() => set({ goalType: "maintain" })} icon={<Target size={22} />} label="Maintain" sub="Recomp & hold" />
        </>}

        {cur === "target" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 4 }}>{f.goalType === "maintain" ? "Timeline" : "Target"}</h1>
          <p style={{ color: T.muted, fontSize: 13, marginTop: 0, marginBottom: 20 }}>By when do you want to see the result? I'll check if it's realistic.</p>
          {f.goalType !== "maintain" && <>
            <Eyebrow>Target weight</Eyebrow>
            <div style={{ marginBottom: 14 }}><NumIn value={f.targetWeight} onChange={(v) => set({ targetWeight: v })} ph={f.goalType === "fatLoss" ? "72" : "84"} suffix="kg" /></div>
          </>}
          <Eyebrow>Target date</Eyebrow>
          <input type="date" value={f.targetDate} onChange={(e) => set({ targetDate: e.target.value })}
            className="mono" style={{ width: "100%", boxSizing: "border-box", background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "13px 14px", color: T.text, fontSize: 16, outline: "none" }} />
        </>}

        {cur === "activity" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Daily activity</h1>
          <OptBtn active={f.activity === "light"} onClick={() => set({ activity: "light" })} label="Light" sub="Desk job, little walking" />
          <OptBtn active={f.activity === "moderate"} onClick={() => set({ activity: "moderate" })} label="Moderate" sub="On your feet / regular walks" />
          <OptBtn active={f.activity === "active"} onClick={() => set({ activity: "active" })} label="Active" sub="Physical job / lots of steps" />
        </>}

        {cur === "diet" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Diet preference</h1>
          <OptBtn active={f.dietPref === "veg"} onClick={() => set({ dietPref: "veg" })} icon={<Salad size={22} />} label="Vegetarian" />
          <OptBtn active={f.dietPref === "egg"} onClick={() => set({ dietPref: "egg" })} icon={<Egg size={22} />} label="Eggetarian" sub="Veg + eggs" />
          <OptBtn active={f.dietPref === "nonveg"} onClick={() => set({ dietPref: "nonveg" })} icon={<Drumstick size={22} />} label="Non-vegetarian" />
        </>}

        {cur === "summary" && plan && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 4 }}>Your plan, {f.name}</h1>
          <p style={{ color: T.muted, fontSize: 13, marginTop: 0, marginBottom: 16 }}>{plan.headline}</p>
          {!plan.feasible && <Card style={{ background: T.accentDim, borderColor: T.accent, marginBottom: 12 }}>
            <div style={{ fontSize: 13, color: T.text, lineHeight: 1.5 }}>
              That timeline is aggressive for muscle-safe progress. A healthier target date is <Mono style={{ color: T.accent }}>{plan.suggestedDate ? fmtDay(plan.suggestedDate) : "later"}</Mono>. You can still proceed — I'll cap the pace safely.
            </div>
          </Card>}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 12 }}>
            <Card><Eyebrow>Calories</Eyebrow><Mono style={{ fontSize: 24, fontWeight: 650 }}>{plan.calorieGoal}</Mono><div style={{ fontSize: 11, color: T.muted }}>kcal/day · TDEE {plan.tdee}</div></Card>
            <Card><Eyebrow>Protein</Eyebrow><Mono style={{ fontSize: 24, fontWeight: 650 }}>{plan.proteinGoal}g</Mono><div style={{ fontSize: 11, color: T.muted }}>per day</div></Card>
          </div>
          <Card style={{ marginBottom: 12 }}>
            <Eyebrow>Training</Eyebrow>
            <div style={{ fontSize: 14, lineHeight: 1.5 }}>{plan.splitNote}</div>
            <div style={{ fontSize: 13, color: T.muted, marginTop: 8 }}>{plan.cardioNote}</div>
          </Card>
          <div style={{ fontSize: 12, color: T.faint, textAlign: "center" }}>You can fine-tune anything later in Settings.</div>
        </>}
      </div>

      <div onClick={() => canNext() && next()} style={{ ...primaryBtn, marginTop: 26, opacity: canNext() ? 1 : 0.45 }}>
        {cur === "summary" ? "Create my plan" : "Continue"}
      </div>
    </div>
  );
}

/* ============================ PROFILE PICKER ============================ */
function ProfilePicker({ users, onPick, onCreate }) {
  return (
    <div style={{ minHeight: "100vh", background: T.bg, color: T.text, maxWidth: 480, margin: "0 auto", padding: "calc(40px + env(safe-area-inset-top)) 18px calc(40px + env(safe-area-inset-bottom))", boxSizing: "border-box" }}>
      <div style={{ width: 34, height: 34, borderRadius: 10, background: T.accent, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 16 }}>
        <Dumbbell size={20} color="#1A1206" />
      </div>
      <h1 style={{ fontSize: 26, fontWeight: 650, marginBottom: 4 }}>Who's training?</h1>
      <p style={{ color: T.muted, fontSize: 14, marginTop: 0, marginBottom: 24 }}>Pick a profile on this device, or add a new one.</p>
      {users.map((u) => (
        <div key={u.id} onClick={() => onPick(u.id)} style={{ display: "flex", alignItems: "center", gap: 14, padding: 16, borderRadius: 16, background: T.surface, border: `1px solid ${T.line}`, marginBottom: 12, cursor: "pointer" }}>
          <div style={{ width: 44, height: 44, borderRadius: 22, background: T.accentDim, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <User size={22} color={T.accent} />
          </div>
          <div style={{ flex: 1, fontWeight: 600, fontSize: 16 }}>{u.name}</div>
          <ChevronRight size={20} color={T.faint} />
        </div>
      ))}
      <div onClick={onCreate} style={{ display: "flex", alignItems: "center", gap: 10, padding: 16, borderRadius: 16, border: `1px dashed ${T.line}`, color: T.accent, cursor: "pointer", justifyContent: "center", fontWeight: 600 }}>
        <Plus size={18} /> Add profile
      </div>
    </div>
  );
}

/* ============================ DASHBOARD ============================ */
function Dashboard({ go, openActivity, openPlan }) {
  const A = useApp();
  const st = A.data.settings || {};
  const today = todayStr();
  const dow = new Date().getDay();
  const todayDay = WEEKDAY[dow] || null;
  const doneToday = !!A.data.sessions[today];

  const meals = A.data.diet[today] || [];
  const kcalToday = meals.reduce((a, b) => a + (b.kcal || 0), 0);
  const protToday = meals.reduce((a, b) => a + (b.protein || 0), 0);
  const calGoal = st.calorieGoal || 2000;
  const protGoal = st.proteinGoal || 150;
  const burnedToday = (A.data.activity[today] || {}).kcal || 0;
  const adjustedCalGoal = calGoal + burnedToday;

  const lastWeight = A.data.weight.length ? A.data.weight[A.data.weight.length - 1].weight : null;
  const cur = st.currentWeight ?? lastWeight;
  const tgt = st.targetWeight;
  const daysLeft = st.targetDate ? Math.max(0, daysBetween(today, st.targetDate)) : null;

  const act = A.data.activity[today] || { steps: 0, kcal: 0, min: 0 };
  const stepGoal = st.stepGoal || 10000;
  const last7 = Object.keys(A.data.sessions).filter((d) => { const df = daysBetween(d, today); return df >= 0 && df < 7; }).length;

  return (
    <div style={{ padding: "8px 16px 16px" }}>
      <div style={{ marginBottom: 18 }}>
        <Mono style={{ fontSize: 12, color: T.accent, letterSpacing: 1 }}>{fmtFull()}</Mono>
        <h1 style={{ fontSize: 26, fontWeight: 650, margin: "4px 0 0" }}>{st.name ? `Hi, ${st.name}` : "Today"}</h1>
      </div>

      <Card style={{ marginBottom: 14, padding: 0, overflow: "hidden" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: 16 }}>
          <div>
            <Eyebrow>{todayDay ? (doneToday ? "Logged today" : "Today's session") : "Rest day"}</Eyebrow>
            <div style={{ fontSize: 22, fontWeight: 650 }}>{todayDay || "Recover"}</div>
            <div style={{ fontSize: 13, color: T.muted, marginTop: 2 }}>{todayDay ? PROGRAM[todayDay].focus : "Walk, hydrate, sleep 7+ hrs"}</div>
          </div>
          {todayDay && (
            <div onClick={() => go("train", todayDay)} style={{ background: doneToday ? T.surface2 : T.accent, color: doneToday ? T.text : "#1A1206", borderRadius: 14, padding: "12px 16px", display: "flex", gap: 6, alignItems: "center", cursor: "pointer", fontWeight: 600, fontSize: 14 }}>
              {doneToday ? <><RotateCcw size={16} />Review</> : <><Play size={16} fill="#1A1206" />Start</>}
            </div>
          )}
        </div>
      </Card>

      {/* calories + protein */}
      <Card onClick={() => go("food")} style={{ cursor: "pointer", marginBottom: 14, display: "flex", justifyContent: "space-around", alignItems: "center" }}>
        <div style={{ textAlign: "center" }}><Ring value={kcalToday} goal={adjustedCalGoal} size={100} unit="" color={T.accent} /><div style={{ fontSize: 11, color: T.muted, marginTop: 6 }}>calories</div></div>
        <div style={{ textAlign: "center" }}><Ring value={protToday} goal={protGoal} size={100} unit="g" color={T.blue} /><div style={{ fontSize: 11, color: T.muted, marginTop: 6 }}>protein</div></div>
      </Card>

      {/* weight + plan */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginBottom: 14 }}>
        <Card onClick={() => go("progress")} style={{ cursor: "pointer" }}>
          <Eyebrow>Body weight</Eyebrow>
          {cur != null ? <>
            <div><Mono style={{ fontSize: 28, fontWeight: 650 }}>{cur}</Mono><Mono style={{ color: T.muted, fontSize: 13 }}> {st.units || "kg"}</Mono></div>
            {tgt != null && <div style={{ fontSize: 12, color: T.muted, marginTop: 4 }}>{Math.abs(cur - tgt).toFixed(1)} to {tgt}{daysLeft != null ? ` · ${daysLeft}d left` : ""}</div>}
          </> : <div style={{ color: T.muted, fontSize: 13, marginTop: 8 }}>Log a weigh-in</div>}
        </Card>
        <Card onClick={openPlan} style={{ cursor: "pointer" }}>
          <Eyebrow>Your plan</Eyebrow>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 2 }}>
            <Sparkles size={18} color={T.accent} />
            <div style={{ fontWeight: 600, fontSize: 14, textTransform: "capitalize" }}>{(st.goalType || "").replace("fatLoss", "Fat loss").replace("weightGain", "Muscle gain") || "Coach"}</div>
          </div>
          <div style={{ fontSize: 12, color: T.muted, marginTop: 6 }}>Tap for diet & training</div>
        </Card>
      </div>

      {/* activity */}
      <Card onClick={openActivity} style={{ cursor: "pointer", marginBottom: 14 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
          <Eyebrow>Today's activity</Eyebrow>
          <div style={{ display: "flex", alignItems: "center", gap: 4, color: T.accent, fontSize: 12, fontWeight: 600 }}><Plus size={14} /> log</div>
        </div>
        <div style={{ display: "flex", gap: 16 }}>
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}><Footprints size={16} color={T.accent} /><Mono style={{ fontSize: 22, fontWeight: 650 }}>{(act.steps || 0).toLocaleString()}</Mono></div>
            <div style={{ height: 5, background: T.surface2, borderRadius: 3, marginTop: 7, overflow: "hidden" }}><div style={{ width: `${Math.min(100, (act.steps || 0) / stepGoal * 100)}%`, height: "100%", background: (act.steps || 0) >= stepGoal ? T.success : T.accent }} /></div>
            <div style={{ fontSize: 11, color: T.muted, marginTop: 5 }}>steps · goal {stepGoal.toLocaleString()}</div>
          </div>
          <div style={{ width: 1, background: T.line }} />
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}><Flame size={16} color={T.accent} /><Mono style={{ fontSize: 22, fontWeight: 650 }}>{act.kcal || 0}</Mono><Mono style={{ fontSize: 12, color: T.muted }}>kcal</Mono></div>
            <div style={{ fontSize: 11, color: T.muted, marginTop: 14 }}>cardio · {act.min || 0} min</div>
          </div>
        </div>
      </Card>

      <Card>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <Dumbbell size={20} color={T.accent} />
          <div><Mono style={{ fontSize: 22, fontWeight: 650 }}>{last7}/5</Mono><div style={{ fontSize: 12, color: T.muted }}>sessions this week</div></div>
        </div>
      </Card>

      <div style={{ textAlign: "center", color: T.faint, fontSize: 12, marginTop: 22, lineHeight: 1.6 }}>
        <Moon size={13} style={{ verticalAlign: "middle" }} /> Hit {protGoal}g protein, keep lifts heavy, sleep 7+ hrs.
      </div>
    </div>
  );
}

/* ============================ PLAN SHEET ============================ */
function PlanSheet({ onClose }) {
  const A = useApp();
  const st = A.data.settings || {};
  const plan = A.data.plan;
  if (!plan) { return <div style={overlay} onClick={onClose}><div style={sheet} onClick={(e) => e.stopPropagation()}><p style={{ color: T.muted }}>No plan yet.</p></div></div>; }
  const mealKcal = plan.meals.reduce((a, b) => a + b.kcal, 0);
  const mealProt = plan.meals.reduce((a, b) => a + b.protein, 0);
  return (
    <div style={overlay} onClick={onClose}>
      <div style={sheet} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
          <h2 style={{ fontSize: 21, fontWeight: 650, margin: 0 }}>Your plan</h2>
          <X size={24} color={T.muted} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>
        <p style={{ color: T.muted, fontSize: 13, marginTop: 4, marginBottom: 16 }}>{plan.headline}</p>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10, marginBottom: 14 }}>
          <Card style={{ padding: 12 }}><Eyebrow>Cals</Eyebrow><Mono style={{ fontSize: 20, fontWeight: 650 }}>{plan.calorieGoal}</Mono></Card>
          <Card style={{ padding: 12 }}><Eyebrow>Protein</Eyebrow><Mono style={{ fontSize: 20, fontWeight: 650 }}>{plan.proteinGoal}g</Mono></Card>
          <Card style={{ padding: 12 }}><Eyebrow>Steps</Eyebrow><Mono style={{ fontSize: 20, fontWeight: 650 }}>{(plan.stepGoal / 1000)}k</Mono></Card>
        </div>

        <Card style={{ marginBottom: 14 }}>
          <Eyebrow>Training — 5-day PPLUL</Eyebrow>
          <div style={{ fontSize: 14, lineHeight: 1.5, marginBottom: 8 }}>{plan.splitNote}</div>
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            {DAY_ORDER.map((d) => <span key={d} className="mono" style={{ fontSize: 12, padding: "5px 10px", background: T.surface2, borderRadius: 8, border: `1px solid ${T.line}` }}>{d}</span>)}
          </div>
          <div style={{ fontSize: 13, color: T.muted, marginTop: 10 }}>{plan.cardioNote}</div>
        </Card>

        <Card>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 4 }}>
            <Eyebrow>Simple day of eating</Eyebrow>
            <Mono style={{ fontSize: 12, color: T.muted }}>~{mealKcal} kcal · {mealProt}g P</Mono>
          </div>
          <div style={{ fontSize: 12, color: T.muted, marginBottom: 10, textTransform: "capitalize" }}>{st.dietPref === "nonveg" ? "Non-veg" : st.dietPref} · scale portions to hit {plan.calorieGoal} kcal</div>
          {plan.meals.map((m, i) => (
            <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "9px 0", borderTop: i ? `1px solid ${T.surface2}` : "none" }}>
              <div><div style={{ fontSize: 14 }}>{m.name}</div><Mono style={{ fontSize: 11, color: T.faint }}>{m.time}</Mono></div>
              <Mono style={{ fontSize: 12, color: T.muted, whiteSpace: "nowrap" }}>{m.kcal} · {m.protein}g</Mono>
            </div>
          ))}
        </Card>

        {!plan.feasible && plan.suggestedDate && (
          <div style={{ fontSize: 12, color: T.accent, textAlign: "center", marginTop: 14 }}>Note: a muscle-safe date for this goal is ~{fmtDay(plan.suggestedDate)}.</div>
        )}
      </div>
    </div>
  );
}

/* ============================ TRAIN (per-exercise save/edit) ============================ */
function Train({ initialDay, openExercise }) {
  const A = useApp();
  const dow = new Date().getDay();
  const [day, setDay] = useState(initialDay || WEEKDAY[dow] || "Push");
  useEffect(() => { if (initialDay) setDay(initialDay); }, [initialDay]);
  const today = todayStr();
  const items = PROGRAM[day].items;

  const [work, setWork] = useState({});
  const [open, setOpen] = useState(null);
  const [flash, setFlash] = useState(null);
  const [timer, setTimer] = useState(null);

  useEffect(() => {
    const init = {};
    items.forEach((it) => {
      const hist = A.data.history[it.name] || [];
      const prev = hist.length ? hist[hist.length - 1] : null;
      const rows = prev ? prev.sets.map((x) => ({ weight: x.weight, reps: x.reps }))
        : Array.from({ length: it.sets }, () => ({ weight: 20, reps: lowReps(it.reps) }));
      while (rows.length < it.sets) rows.push({ ...rows[rows.length - 1] });
      init[it.name] = rows.slice(0, it.sets);
    });
    setWork(init); setOpen(items[0] ? items[0].name : null);
  }, [day]);

  useEffect(() => {
    if (timer == null) return;
    if (timer <= 0) { setTimer(null); return; }
    const id = setTimeout(() => setTimer((t) => t - 1), 1000);
    return () => clearTimeout(id);
  }, [timer]);

  const setSet = (ex, i, patch) => setWork((w) => ({ ...w, [ex]: w[ex].map((s, j) => (j === i ? { ...s, ...patch } : s)) }));
  const savedToday = (name) => { const h = A.data.history[name] || []; return h.length && h[h.length - 1].date === today; };

  const saveExercise = (name) => {
    const sets = (work[name] || []).filter((x) => x.reps > 0).map((x) => ({ weight: +x.weight || 0, reps: +x.reps || 0 }));
    if (!sets.length) return;
    A.update("history", (h) => ({ ...h, [name]: [...(h[name] || []).filter((e) => e.date !== today), { date: today, sets }] }));
    A.update("sessions", (s) => ({ ...s, [today]: { day, at: Date.now() } }));
    setFlash(name); setTimeout(() => setFlash((f) => (f === name ? null : f)), 1400);
    setTimer(90);
  };

  return (
    <div style={{ padding: "8px 16px 16px" }}>
      <h1 style={{ fontSize: 24, fontWeight: 650, margin: "0 0 4px" }}>Train</h1>
      <div style={{ fontSize: 13, color: T.muted, marginBottom: 14 }}>{PROGRAM[day].focus}</div>

      <div style={{ display: "flex", gap: 8, overflowX: "auto", paddingBottom: 4, marginBottom: 14 }} className="noscroll">
        {DAY_ORDER.map((d) => (
          <div key={d} onClick={() => setDay(d)} style={{ padding: "8px 16px", borderRadius: 12, whiteSpace: "nowrap", cursor: "pointer", fontSize: 14, fontWeight: 600, background: day === d ? T.accent : T.surface, color: day === d ? "#1A1206" : T.text, border: `1px solid ${day === d ? T.accent : T.line}` }}>{d}</div>
        ))}
      </div>

      {items.map((it) => {
        const lib = LIB[it.name] || { view: "front", primary: [], secondary: [] };
        const hist = A.data.history[it.name] || [];
        const prev = hist.length ? hist[hist.length - 1] : null;
        const rows = work[it.name] || [];
        const isOpen = open === it.name;
        const saved = savedToday(it.name);
        const allTop = prev && prev.date !== today && prev.sets.length >= it.sets && prev.sets.every((x) => x.reps >= topReps(it.reps));
        return (
          <Card key={it.name} style={{ marginBottom: 12, padding: 0, overflow: "hidden", borderColor: saved ? "rgba(127,203,134,0.5)" : T.line }}>
            <div onClick={() => setOpen(isOpen ? null : it.name)} style={{ display: "flex", alignItems: "center", gap: 10, padding: 12, cursor: "pointer" }}>
              <div style={{ width: 40, height: 56, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <MuscleMap view={lib.view} primary={lib.primary} secondary={lib.secondary} size={38} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 15 }}>{it.name}</div>
                <Mono style={{ fontSize: 12, color: T.muted }}>{it.sets} × {it.reps}</Mono>
                {allTop && <span style={{ marginLeft: 8, fontSize: 11, color: T.accent, fontWeight: 600 }}><ArrowUp size={11} style={{ verticalAlign: "middle" }} /> add weight</span>}
              </div>
              {(flash === it.name || saved) && (
                <div style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 12, fontWeight: 650, color: flash === it.name ? T.success : T.success, whiteSpace: "nowrap" }}>
                  <Check size={14} /> {flash === it.name ? "Saved" : "Logged"}
                </div>
              )}
              <ChevronDown size={18} color={T.faint} style={{ transform: isOpen ? "none" : "rotate(-90deg)", transition: ".2s", flexShrink: 0 }} />
            </div>

            {isOpen && (
              <div style={{ borderTop: `1px solid ${T.line}`, padding: 14 }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 10 }}>
                  <span style={{ fontSize: 12, color: T.muted }}>{prev ? <>Last: <Mono style={{ color: T.text }}>{prev.sets.map((x) => `${x.weight}×${x.reps}`).join("  ")}</Mono></> : "No history yet"}</span>
                  <span onClick={() => openExercise(it.name)} style={{ fontSize: 12, color: T.accent, cursor: "pointer", display: "flex", gap: 4, alignItems: "center" }}><Play size={12} /> tutorial</span>
                </div>
                {rows.map((st, i) => (
                  <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 0", borderTop: i ? `1px solid ${T.surface2}` : "none" }}>
                    <Mono style={{ width: 18, color: T.faint, fontSize: 13 }}>{i + 1}</Mono>
                    <div style={{ flex: 1 }}><Mono style={{ fontSize: 10, color: T.faint }}>WEIGHT</Mono><Stepper value={st.weight} step={2.5} onChange={(v) => setSet(it.name, i, { weight: v })} suffix="kg" /></div>
                    <div style={{ flex: 1 }}><Mono style={{ fontSize: 10, color: T.faint }}>REPS</Mono><Stepper value={st.reps} step={1} onChange={(v) => setSet(it.name, i, { reps: v })} /></div>
                  </div>
                ))}
                <div onClick={() => saveExercise(it.name)} style={{ ...primaryBtn, marginTop: 12, padding: 12, display: "flex", gap: 6, alignItems: "center", justifyContent: "center" }}>
                  <Save size={16} /> {saved ? "Update exercise" : "Save exercise"}
                </div>
              </div>
            )}
          </Card>
        );
      })}

      {timer != null && (
        <div style={{ position: "fixed", bottom: "calc(78px + env(safe-area-inset-bottom))", left: "50%", transform: "translateX(-50%)", background: T.surface, border: `1px solid ${T.accent}`, borderRadius: 999, padding: "10px 18px", display: "flex", gap: 10, alignItems: "center", zIndex: 50 }}>
          <Clock size={16} color={T.accent} /><Mono style={{ fontSize: 18, fontWeight: 600 }}>{Math.floor(timer / 60)}:{String(timer % 60).padStart(2, "0")}</Mono>
          <X size={16} color={T.muted} onClick={() => setTimer(null)} style={{ cursor: "pointer" }} />
        </div>
      )}
    </div>
  );
}

/* ============================ LIBRARY (grouped by body part) ============================ */
function Library({ openExercise }) {
  const [q, setQ] = useState("");
  const [openG, setOpenG] = useState({ Chest: true });
  const names = Object.keys(LIB);
  const ql = q.toLowerCase();
  return (
    <div style={{ padding: "8px 16px 16px" }}>
      <h1 style={{ fontSize: 24, fontWeight: 650, margin: "0 0 12px" }}>Exercise library</h1>
      <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search exercises"
        style={{ width: "100%", boxSizing: "border-box", background: T.surface, border: `1px solid ${T.line}`, borderRadius: 12, padding: "12px 14px", color: T.text, fontSize: 15, marginBottom: 14, outline: "none" }} />
      {GROUPS.map((g) => {
        const list = names.filter((n) => LIB[n].g === g && (!q || n.toLowerCase().includes(ql)));
        if (!list.length) return null;
        const isOpen = q ? true : openG[g];
        return (
          <div key={g} style={{ marginBottom: 12 }}>
            <div onClick={() => setOpenG((s) => ({ ...s, [g]: !s[g] }))} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "10px 4px", cursor: "pointer" }}>
              <div style={{ fontWeight: 650, fontSize: 16 }}>{g} <Mono style={{ fontSize: 12, color: T.faint }}>· {list.length}</Mono></div>
              <ChevronDown size={18} color={T.faint} style={{ transform: isOpen ? "none" : "rotate(-90deg)", transition: ".2s" }} />
            </div>
            {isOpen && (
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                {list.map((n) => {
                  const lib = LIB[n];
                  return (
                    <Card key={n} onClick={() => openExercise(n)} style={{ cursor: "pointer", padding: 12, display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center" }}>
                      <MuscleMap view={lib.view} primary={lib.primary} secondary={lib.secondary} size={58} />
                      <div style={{ fontWeight: 600, fontSize: 13, marginTop: 8, lineHeight: 1.25 }}>{n}</div>
                      <Mono style={{ fontSize: 10, color: T.muted, marginTop: 4 }}>{lib.target.split(",")[0]}</Mono>
                    </Card>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function ExerciseDetail({ name, onClose }) {
  const lib = LIB[name];
  if (!lib) return null;
  let prescribed = null;
  for (const d of DAY_ORDER) { const it = PROGRAM[d].items.find((x) => x.name === name); if (it) { prescribed = it; break; } }
  return (
    <div style={overlay} onClick={onClose}>
      <div style={sheet} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <h2 style={{ fontSize: 21, fontWeight: 650, margin: 0, maxWidth: "80%" }}>{name}</h2>
          <X size={24} color={T.muted} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>
        <div style={{ display: "flex", gap: 16, margin: "14px 0", alignItems: "center" }}>
          <div style={{ background: T.surface2, borderRadius: 16, padding: 10, border: `1px solid ${T.line}` }}>
            <MuscleMap view={lib.view} primary={lib.primary} secondary={lib.secondary} size={92} />
          </div>
          <div>
            <Eyebrow>Targets</Eyebrow>
            <div style={{ fontWeight: 600, fontSize: 15, marginBottom: 10 }}>{lib.target}</div>
            {prescribed && <><Eyebrow>Prescribed</Eyebrow><Mono style={{ fontSize: 18, fontWeight: 600, color: T.accent }}>{prescribed.sets} × {prescribed.reps}</Mono></>}
          </div>
        </div>
        <p style={{ fontSize: 14, color: T.muted, lineHeight: 1.6, margin: "0 0 16px" }}>{lib.desc}</p>
        <Eyebrow>Form cues</Eyebrow>
        <div style={{ marginBottom: 18 }}>
          {lib.cues.map((c, i) => (
            <div key={i} style={{ display: "flex", gap: 10, marginBottom: 8 }}>
              <Mono style={{ color: T.accent, fontSize: 13 }}>{String(i + 1).padStart(2, "0")}</Mono>
              <span style={{ fontSize: 14, lineHeight: 1.4 }}>{c}</span>
            </div>
          ))}
        </div>
        <a href={yt(name)} target="_blank" rel="noreferrer" style={{ display: "flex", gap: 8, alignItems: "center", justifyContent: "center", ...primaryBtn, textDecoration: "none" }}>
          <Play size={18} fill="#1A1206" /> Watch tutorial
        </a>
      </div>
    </div>
  );
}

/* ============================ NUTRITION (diet book) ============================ */
// Parses lines like "2 Rotis, 240, 6" -> {name, kcal, protein}. Also tolerates "Name, 240" (protein 0).
function parseMealLines(raw) {
  const lines = raw.split("\n").map((l) => l.trim()).filter(Boolean);
  const items = [];
  for (const line of lines) {
    const parts = line.split(",").map((p) => p.trim()).filter((p) => p !== "");
    if (parts.length < 2) continue;
    const protein = parts.length >= 3 ? parseFloat(parts[parts.length - 1]) : 0;
    const kcalIdx = parts.length >= 3 ? parts.length - 2 : parts.length - 1;
    const kcal = parseFloat(parts[kcalIdx]);
    const name = parts.slice(0, kcalIdx).join(", ").trim();
    if (!name || !(kcal >= 0)) continue;
    items.push({ name, kcal: Math.round(kcal), protein: Math.round(protein || 0) });
  }
  return items;
}

function Nutrition() {
  const A = useApp();
  const st = A.data.settings || {};
  const today = todayStr();
  const meals = A.data.diet[today] || [];
  const kcal = meals.reduce((a, b) => a + (b.kcal || 0), 0);
  const prot = meals.reduce((a, b) => a + (b.protein || 0), 0);
  const calGoal = st.calorieGoal || 2000;
  const protGoal = st.proteinGoal || 150;
  const water = A.data.water[today] || 0;
  const burned = (A.data.activity[today] || {}).kcal || 0;
  const adjustedGoal = calGoal + burned; // exercise calories are added back to today's allowance
  const remaining = adjustedGoal - kcal;
  const tdee = (A.data.plan && A.data.plan.tdee) || calGoal;
  const deficit = Math.round(tdee - (kcal - burned)); // + = deficit (below maintenance), - = surplus

  const [cName, setCName] = useState("");
  const [cK, setCK] = useState("");
  const [cP, setCP] = useState("");
  const [pending, setPending] = useState(null); // {name,kcal,protein} or {items:[...]} for a batch
  const [logText, setLogText] = useState("");
  const [showFormat, setShowFormat] = useState(false);

  const quick = [...foodsForPref(st.dietPref || "veg"), ...A.foods];
  const addMeal = (name, k, p) => A.update("diet", (d) => ({ ...d, [today]: [...(d[today] || []), { id: Date.now() + Math.random(), name, kcal: Math.round(k), protein: Math.round(p) }] }));
  const addMeals = (items) => A.update("diet", (d) => ({ ...d, [today]: [...(d[today] || []), ...items.map((it) => ({ id: Date.now() + Math.random(), ...it }))] }));
  const removeMeal = (id) => A.update("diet", (d) => ({ ...d, [today]: (d[today] || []).filter((m) => m.id !== id) }));
  const setWater = (n) => A.update("water", (w) => ({ ...w, [today]: Math.max(0, n) }));

  const parsedPreview = useMemo(() => parseMealLines(logText), [logText]);
  const previewTotals = parsedPreview.reduce((a, b) => ({ kcal: a.kcal + b.kcal, protein: a.protein + b.protein }), { kcal: 0, protein: 0 });
  const logParsed = () => { if (!parsedPreview.length) return; addMeals(parsedPreview); setLogText(""); };

  const submitCustom = () => {
    if (!cName.trim() || !(+cK >= 0) || !(+cP >= 0)) return;
    setPending({ name: cName.trim(), kcal: +cK || 0, protein: +cP || 0 });
  };
  const confirmPending = async (saveForFuture) => {
    addMeal(pending.name, pending.kcal, pending.protein);
    if (saveForFuture) await A.addFood({ name: pending.name, kcal: pending.kcal, protein: pending.protein });
    setPending(null); setCName(""); setCK(""); setCP("");
  };

  return (
    <div style={{ padding: "8px 16px 16px" }}>
      <h1 style={{ fontSize: 24, fontWeight: 650, margin: "0 0 14px" }}>Diet book</h1>

      <Card style={{ display: "flex", justifyContent: "space-around", alignItems: "center", marginBottom: 14 }}>
        <div style={{ textAlign: "center" }}><Ring value={kcal} goal={adjustedGoal} size={108} unit="" color={T.accent} /><div style={{ fontSize: 11, color: T.muted, marginTop: 6 }}>{remaining > 0 ? `${remaining} kcal left` : "calories"}</div></div>
        <div style={{ textAlign: "center" }}><Ring value={prot} goal={protGoal} size={108} unit="g" color={T.blue} /><div style={{ fontSize: 11, color: T.muted, marginTop: 6 }}>{prot >= protGoal ? "protein hit" : `${protGoal - prot}g protein left`}</div></div>
      </Card>

      {burned > 0 && (
        <div style={{ fontSize: 11, color: T.muted, textAlign: "center", marginTop: -8, marginBottom: 14 }}>
          Includes +{burned} kcal from today's activity, added to your allowance.
        </div>
      )}

      <Card style={{ marginBottom: 14 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <Eyebrow>Today's {deficit >= 0 ? "deficit" : "surplus"}</Eyebrow>
          <Flame size={15} color={T.accent} />
        </div>
        <Mono style={{ fontSize: 26, fontWeight: 650, color: deficit >= 0 ? T.success : T.danger }}>{Math.abs(deficit)}<span style={{ fontSize: 13, color: T.muted, fontWeight: 500 }}> kcal</span></Mono>
        <div style={{ fontSize: 12, color: T.muted, marginTop: 4 }}>vs. maintenance (~{Math.round(tdee)} kcal){burned > 0 ? `, net of ${burned} kcal burned` : ""}</div>
      </Card>

      <Card style={{ marginBottom: 14, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <Eyebrow>Water</Eyebrow>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <Minus size={18} onClick={() => setWater(water - 1)} style={{ cursor: "pointer", color: T.muted }} />
          <div style={{ display: "flex", alignItems: "baseline", gap: 4 }}><Mono style={{ fontSize: 18 }}>{(water * 0.25).toFixed(2)}</Mono><Mono style={{ fontSize: 12, color: T.muted }}>/ 3.5L</Mono></div>
          <Plus size={18} onClick={() => setWater(water + 1)} style={{ cursor: "pointer", color: T.accent }} />
          <Droplet size={16} color={water * 0.25 >= 3 ? T.success : T.faint} />
        </div>
      </Card>

      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
        <Eyebrow>Quick log a meal</Eyebrow>
        <span onClick={() => setShowFormat((s) => !s)} style={{ fontSize: 12, color: T.accent, cursor: "pointer" }}>{showFormat ? "hide format" : "format?"}</span>
      </div>
      {showFormat && (
        <Card style={{ marginBottom: 10, background: T.surface2 }}>
          <div style={{ fontSize: 12, color: T.muted, lineHeight: 1.6 }}>
            One item per line: <Mono style={{ color: T.text }}>name, kcal, protein</Mono>
            <div style={{ marginTop: 8, padding: 10, background: T.bg, borderRadius: 8 }}>
              <Mono style={{ fontSize: 12, color: T.muted, display: "block" }}>2 Rotis, 240, 6</Mono>
              <Mono style={{ fontSize: 12, color: T.muted, display: "block" }}>Dal tadka, 180, 12</Mono>
              <Mono style={{ fontSize: 12, color: T.muted, display: "block" }}>Paneer bhurji, 220, 14</Mono>
            </div>
            Protein is optional — <Mono style={{ color: T.text }}>name, kcal</Mono> also works.
          </div>
        </Card>
      )}
      <Card style={{ marginBottom: 16, padding: 12 }}>
        <textarea value={logText} onChange={(e) => setLogText(e.target.value)} placeholder={"2 Rotis, 240, 6\nDal tadka, 180, 12"} rows={3} className="mono"
          style={{ width: "100%", boxSizing: "border-box", background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 10, padding: "11px 12px", color: T.text, fontSize: 13, outline: "none", resize: "vertical" }} />
        {parsedPreview.length > 0 && (
          <div style={{ marginTop: 10 }}>
            {parsedPreview.map((it, i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", fontSize: 12, color: T.muted, padding: "4px 0" }}>
                <span>{it.name}</span><Mono>{it.kcal} · {it.protein}g</Mono>
              </div>
            ))}
            <div style={{ display: "flex", justifyContent: "space-between", fontSize: 13, fontWeight: 650, padding: "6px 0", borderTop: `1px solid ${T.line}`, marginTop: 4 }}>
              <span>Total ({parsedPreview.length} item{parsedPreview.length > 1 ? "s" : ""})</span><Mono>{previewTotals.kcal} · {previewTotals.protein}g</Mono>
            </div>
          </div>
        )}
        <div onClick={logParsed} style={{ ...primaryBtn, marginTop: 10, padding: 12, opacity: parsedPreview.length ? 1 : 0.45 }}>Log meal</div>
      </Card>

      <Eyebrow>Quick add</Eyebrow>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginBottom: 14 }}>
        {quick.map((f, i) => (
          <div key={f.id || i} onClick={() => addMeal(f.name, f.kcal, f.protein)} style={{ background: T.surface, border: `1px solid ${T.line}`, borderRadius: 12, padding: "10px 12px", cursor: "pointer" }}>
            <div style={{ fontSize: 13, marginBottom: 3 }}>{f.name}</div>
            <Mono style={{ fontSize: 11, color: T.muted }}>{f.kcal} kcal · {f.protein}g P</Mono>
          </div>
        ))}
      </div>

      <Eyebrow>Add single custom item</Eyebrow>
      <Card style={{ marginBottom: 16, padding: 12 }}>
        <input value={cName} onChange={(e) => setCName(e.target.value)} placeholder="Food name"
          style={{ width: "100%", boxSizing: "border-box", background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 10, padding: "11px 12px", color: T.text, fontSize: 14, outline: "none", marginBottom: 8 }} />
        <div style={{ display: "flex", gap: 8 }}>
          <div style={{ flex: 1, minWidth: 0 }}><NumIn value={cK} onChange={setCK} ph="e.g. 250" suffix="kcal" /></div>
          <div style={{ flex: 1, minWidth: 0 }}><NumIn value={cP} onChange={setCP} ph="e.g. 20" suffix="g" /></div>
        </div>
        <div onClick={submitCustom} style={{ ...primaryBtn, marginTop: 10, padding: 12, opacity: cName.trim() && cK !== "" && cP !== "" ? 1 : 0.45 }}>Add to today</div>
      </Card>

      <Eyebrow>Today's meals</Eyebrow>
      {meals.length === 0 ? <div style={{ color: T.muted, fontSize: 13, padding: "8px 0" }}>Nothing logged yet.</div>
        : meals.map((m) => (
          <div key={m.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "11px 0", borderBottom: `1px solid ${T.surface2}` }}>
            <span style={{ fontSize: 14 }}>{m.name}</span>
            <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
              <Mono style={{ fontSize: 12, color: T.muted }}>{m.kcal} · {m.protein}g</Mono>
              <X size={16} color={T.faint} onClick={() => removeMeal(m.id)} style={{ cursor: "pointer" }} />
            </div>
          </div>
        ))}

      {pending && (
        <div style={overlay} onClick={() => setPending(null)}>
          <div style={sheet} onClick={(e) => e.stopPropagation()}>
            <h2 style={{ fontSize: 20, fontWeight: 650, margin: "0 0 6px" }}>Save for next time?</h2>
            <p style={{ color: T.muted, fontSize: 14, marginTop: 0, marginBottom: 16 }}>Add <b style={{ color: T.text }}>{pending.name}</b> ({pending.kcal} kcal · {pending.protein}g) to your food library so it's one tap in future?</p>
            <div onClick={() => confirmPending(true)} style={{ ...primaryBtn, marginBottom: 10, display: "flex", gap: 8, alignItems: "center", justifyContent: "center" }}><Save size={17} /> Save &amp; add to today</div>
            <div onClick={() => confirmPending(false)} style={{ textAlign: "center", padding: 14, borderRadius: 14, border: `1px solid ${T.line}`, color: T.text, cursor: "pointer", fontWeight: 600 }}>Just add for today</div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ============================ PROGRESS ============================ */
function Progress({ openActivity }) {
  const A = useApp();
  const st = A.data.settings || {};
  const [tab, setTab] = useState("weight");
  const [exSel, setExSel] = useState(Object.keys(A.data.history)[0] || "Barbell Bench Press");
  const [wInput, setWInput] = useState("");

  const weightData = A.data.weight.map((w) => ({ d: fmtDay(w.date), v: w.weight }));
  const exHist = A.data.history[exSel] || [];
  const strengthData = exHist.map((e) => ({ d: fmtDay(e.date), v: e.sets.reduce((m, x) => Math.max(m, epley(x.weight, x.reps)), 0) }));
  const prs = Object.entries(A.data.history).map(([n, hist]) => {
    let best = 0, bestW = 0; hist.forEach((e) => e.sets.forEach((x) => { best = Math.max(best, epley(x.weight, x.reps)); bestW = Math.max(bestW, x.weight); }));
    return { n, best, bestW };
  }).filter((p) => p.best > 0).sort((a, b) => b.best - a.best);

  const logWeight = () => {
    const v = parseFloat(wInput); if (!v) return; const d = todayStr();
    A.update("weight", (prev) => [...prev.filter((x) => x.date !== d), { date: d, weight: v }].sort((a, b) => a.date.localeCompare(b.date)));
    A.update("settings", (s) => ({ ...s, currentWeight: v }));
    setWInput("");
  };
  const axis = { stroke: T.faint, fontSize: 11, tickLine: false };
  const ttStyle = { background: T.surface, border: `1px solid ${T.line}`, borderRadius: 10, color: T.text };

  return (
    <div style={{ padding: "8px 16px 16px" }}>
      <h1 style={{ fontSize: 24, fontWeight: 650, margin: "0 0 12px" }}>Progress</h1>
      <div style={{ display: "flex", gap: 6, marginBottom: 16 }}>
        {[["weight", "Weight"], ["strength", "Strength"], ["activity", "Activity"]].map(([k, l]) => (
          <div key={k} onClick={() => setTab(k)} style={{ flex: 1, textAlign: "center", padding: "9px 0", borderRadius: 11, cursor: "pointer", fontWeight: 600, fontSize: 13, background: tab === k ? T.surface : "transparent", color: tab === k ? T.text : T.muted, border: `1px solid ${tab === k ? T.line : "transparent"}` }}>{l}</div>
        ))}
      </div>

      {tab === "weight" && <>
        <Card style={{ marginBottom: 14 }}>
          <Eyebrow>Log weigh-in ({st.units || "kg"})</Eyebrow>
          <div style={{ display: "flex", gap: 10 }}>
            <input value={wInput} onChange={(e) => setWInput(e.target.value)} inputMode="decimal" placeholder="e.g. 78.4" className="mono"
              style={{ flex: 1, background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "12px 14px", color: T.text, fontSize: 16, outline: "none" }} />
            <div onClick={logWeight} style={{ ...primaryBtn, padding: "0 20px", display: "flex", alignItems: "center" }}>Log</div>
          </div>
        </Card>
        <Card>
          <Eyebrow>Weight trend</Eyebrow>
          {weightData.length > 1 ? (
            <ResponsiveContainer width="100%" height={200}>
              <AreaChart data={weightData} margin={{ left: -18, right: 6, top: 6 }}>
                <defs><linearGradient id="gw" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor={T.accent} stopOpacity={0.35} /><stop offset="100%" stopColor={T.accent} stopOpacity={0} /></linearGradient></defs>
                <CartesianGrid stroke={T.surface2} vertical={false} /><XAxis dataKey="d" {...axis} /><YAxis {...axis} domain={["dataMin - 1", "dataMax + 1"]} />
                <Tooltip contentStyle={ttStyle} /><Area type="monotone" dataKey="v" stroke={T.accent} strokeWidth={2.5} fill="url(#gw)" dot={{ r: 3, fill: T.accent }} />
              </AreaChart>
            </ResponsiveContainer>
          ) : <div style={{ color: T.muted, fontSize: 13, padding: "24px 0", textAlign: "center" }}>Log two or more weigh-ins to see your trend.</div>}
        </Card>
      </>}

      {tab === "strength" && <>
        <div style={{ display: "flex", gap: 8, overflowX: "auto", marginBottom: 14, paddingBottom: 4 }} className="noscroll">
          {Object.keys(A.data.history).length === 0 && <span style={{ color: T.muted, fontSize: 13 }}>Log workouts to track strength.</span>}
          {Object.keys(A.data.history).map((n) => (
            <div key={n} onClick={() => setExSel(n)} style={{ whiteSpace: "nowrap", padding: "7px 13px", borderRadius: 10, fontSize: 13, fontWeight: 600, cursor: "pointer", background: exSel === n ? T.accent : T.surface, color: exSel === n ? "#1A1206" : T.text, border: `1px solid ${exSel === n ? T.accent : T.line}` }}>{n}</div>
          ))}
        </div>
        {strengthData.length > 0 ? (
          <Card>
            <Eyebrow>Estimated 1RM · {exSel}</Eyebrow>
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={strengthData} margin={{ left: -18, right: 6, top: 6 }}>
                <CartesianGrid stroke={T.surface2} vertical={false} /><XAxis dataKey="d" {...axis} /><YAxis {...axis} domain={["dataMin - 2", "dataMax + 2"]} />
                <Tooltip contentStyle={ttStyle} /><Line type="monotone" dataKey="v" stroke={T.accent} strokeWidth={2.5} dot={{ r: 3, fill: T.accent }} />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        ) : <Card><div style={{ color: T.muted, fontSize: 13, textAlign: "center", padding: 12 }}>No logged sets yet for this lift.</div></Card>}
        {prs.length > 0 && <Card style={{ marginTop: 14 }}>
          <Eyebrow>Personal records</Eyebrow>
          {prs.slice(0, 6).map((p) => (
            <div key={p.n} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "9px 0", borderTop: `1px solid ${T.surface2}` }}>
              <span style={{ fontSize: 14, display: "flex", gap: 8, alignItems: "center" }}><Trophy size={15} color={T.accent} />{p.n}</span>
              <Mono style={{ fontSize: 13, color: T.muted }}>{p.bestW}kg · ~{p.best} 1RM</Mono>
            </div>
          ))}
        </Card>}
      </>}

      {tab === "activity" && <ActivityProgress openActivity={openActivity} />}
    </div>
  );
}

function ActivityProgress({ openActivity }) {
  const A = useApp();
  const today = todayStr();
  const entries = Object.entries(A.data.activity).sort((a, b) => a[0].localeCompare(b[0]));
  const stepData = entries.map(([d, a]) => ({ d: fmtDay(d), v: a.steps || 0 }));
  const kcalData = entries.map(([d, a]) => ({ d: fmtDay(d), v: a.kcal || 0 }));
  const last7 = entries.filter(([d]) => { const df = daysBetween(d, today); return df >= 0 && df < 7; });
  const totSteps = last7.reduce((x, [, a]) => x + (a.steps || 0), 0);
  const totKcal = last7.reduce((x, [, a]) => x + (a.kcal || 0), 0);
  const totMin = last7.reduce((x, [, a]) => x + (a.min || 0), 0);
  const avg = last7.length ? Math.round(totSteps / last7.length) : 0;
  const axis = { stroke: T.faint, fontSize: 11, tickLine: false };
  const ttStyle = { background: T.surface, border: `1px solid ${T.line}`, borderRadius: 10, color: T.text };
  return (
    <div>
      <div onClick={openActivity} style={{ ...primaryBtn, marginBottom: 14, padding: 13, display: "flex", gap: 8, alignItems: "center", justifyContent: "center" }}><Plus size={18} /> Log today's activity</div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 14 }}>
        <Card><Eyebrow>7-day steps</Eyebrow><Mono style={{ fontSize: 24, fontWeight: 650 }}>{totSteps.toLocaleString()}</Mono><div style={{ fontSize: 12, color: T.muted }}>avg {avg.toLocaleString()}/day</div></Card>
        <Card><Eyebrow>7-day cardio</Eyebrow><Mono style={{ fontSize: 24, fontWeight: 650 }}>{totKcal}</Mono><div style={{ fontSize: 12, color: T.muted }}>kcal · {totMin} min</div></Card>
      </div>
      {stepData.length > 0 ? (
        <Card style={{ marginBottom: 14 }}>
          <Eyebrow>Steps</Eyebrow>
          <ResponsiveContainer width="100%" height={170}>
            <AreaChart data={stepData} margin={{ left: -8, right: 6, top: 6 }}>
              <defs><linearGradient id="gs" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor={T.accent} stopOpacity={0.35} /><stop offset="100%" stopColor={T.accent} stopOpacity={0} /></linearGradient></defs>
              <CartesianGrid stroke={T.surface2} vertical={false} /><XAxis dataKey="d" {...axis} /><YAxis {...axis} width={42} />
              <Tooltip contentStyle={ttStyle} /><Area type="monotone" dataKey="v" stroke={T.accent} strokeWidth={2.5} fill="url(#gs)" dot={{ r: 3, fill: T.accent }} />
            </AreaChart>
          </ResponsiveContainer>
        </Card>
      ) : <Card style={{ marginBottom: 14 }}><div style={{ color: T.muted, fontSize: 13, textAlign: "center", padding: 16 }}>Log steps and cardio to see trends.</div></Card>}
      {kcalData.some((x) => x.v > 0) && (
        <Card>
          <Eyebrow>Cardio calories</Eyebrow>
          <ResponsiveContainer width="100%" height={170}>
            <LineChart data={kcalData} margin={{ left: -8, right: 6, top: 6 }}>
              <CartesianGrid stroke={T.surface2} vertical={false} /><XAxis dataKey="d" {...axis} /><YAxis {...axis} width={42} />
              <Tooltip contentStyle={ttStyle} /><Line type="monotone" dataKey="v" stroke={T.accent} strokeWidth={2.5} dot={{ r: 3, fill: T.accent }} />
            </LineChart>
          </ResponsiveContainer>
        </Card>
      )}
    </div>
  );
}

function LogActivitySheet({ onClose }) {
  const A = useApp();
  const today = todayStr();
  const cur = A.data.activity[today] || { steps: 0, kcal: 0, min: 0 };
  const [steps, setSteps] = useState(cur.steps || 0);
  const [kcal, setKcal] = useState(cur.kcal || 0);
  const [min, setMin] = useState(cur.min || 0);
  const save = () => { A.update("activity", (prev) => ({ ...prev, [today]: { steps: +steps || 0, kcal: +kcal || 0, min: +min || 0 } })); onClose(); };
  const chip = (label, fn) => <div onClick={fn} className="mono" style={{ padding: "8px 14px", borderRadius: 10, background: T.surface2, border: `1px solid ${T.line}`, fontSize: 13, cursor: "pointer" }}>{label}</div>;
  return (
    <div style={overlay} onClick={onClose}>
      <div style={sheet} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
          <h2 style={{ fontSize: 21, fontWeight: 650, margin: 0 }}>Log activity</h2>
          <X size={24} color={T.muted} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>
        <div style={{ fontSize: 13, color: T.muted, marginBottom: 18 }}>{fmtDay(today)}</div>
        <Eyebrow>Steps walked</Eyebrow><div style={{ marginBottom: 10 }}><NumIn value={steps} onChange={(v) => setSteps(v)} ph="9000" suffix="steps" /></div>
        <div style={{ display: "flex", gap: 8, marginBottom: 16, flexWrap: "wrap" }}>
          {chip("+1k", () => setSteps((+steps || 0) + 1000))}{chip("+2k", () => setSteps((+steps || 0) + 2000))}{chip("+5k", () => setSteps((+steps || 0) + 5000))}{chip("clear", () => setSteps(0))}
        </div>
        <Eyebrow>Cardio calories</Eyebrow><div style={{ marginBottom: 14 }}><NumIn value={kcal} onChange={(v) => setKcal(v)} ph="180" suffix="kcal" /></div>
        <Eyebrow>Cardio minutes</Eyebrow><div style={{ marginBottom: 18 }}><NumIn value={min} onChange={(v) => setMin(v)} ph="20" suffix="min" /></div>
        <div onClick={save} style={primaryBtn}>Save</div>
      </div>
    </div>
  );
}

/* ============================ SETTINGS + PROFILES ============================ */
function SettingsSheet({ onClose }) {
  const A = useApp();
  const [f, setF] = useState({ ...A.data.settings });
  const set = (patch) => setF((p) => ({ ...p, ...patch }));
  const save = () => {
    const profile = { ...f, currentWeight: +f.currentWeight, targetWeight: +f.targetWeight || +f.currentWeight, height: +f.height, age: +f.age };
    const plan = generatePlan(profile);
    A.update("settings", () => ({ ...profile, calorieGoal: plan.calorieGoal, proteinGoal: plan.proteinGoal, stepGoal: plan.stepGoal }));
    A.update("plan", () => plan);
    onClose();
  };
  const field = (label, key, props = {}) => (
    <div style={{ marginBottom: 12 }}>
      <Eyebrow>{label}</Eyebrow>
      <input value={f[key] ?? ""} onChange={(e) => set({ [key]: props.num ? (e.target.value === "" ? "" : e.target.value) : e.target.value })}
        inputMode={props.num ? "decimal" : "text"} type={props.type || "text"} placeholder={props.ph || ""} className={props.num ? "mono" : ""}
        style={{ width: "100%", boxSizing: "border-box", background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "12px 14px", color: T.text, fontSize: 16, outline: "none" }} />
    </div>
  );
  const seg = (label, key, opts) => (
    <div style={{ marginBottom: 12 }}>
      <Eyebrow>{label}</Eyebrow>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        {opts.map(([v, l]) => (
          <div key={v} onClick={() => set({ [key]: v })} style={{ flex: "1 1 30%", textAlign: "center", padding: "10px 6px", borderRadius: 12, cursor: "pointer", fontWeight: 600, fontSize: 13, background: f[key] === v ? T.accent : T.surface2, color: f[key] === v ? "#1A1206" : T.text, border: `1px solid ${f[key] === v ? T.accent : T.line}` }}>{l}</div>
        ))}
      </div>
    </div>
  );
  const exportDb = () => {
    const blob = A.exportBlob && A.exportBlob(); if (!blob) return;
    const url = URL.createObjectURL(new Blob([blob], { type: "application/octet-stream" }));
    const a = document.createElement("a"); a.href = url; a.download = "cuttracker.sqlite"; a.click(); URL.revokeObjectURL(url);
  };

  return (
    <div style={overlay} onClick={onClose}>
      <div style={sheet} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 16 }}>
          <h2 style={{ fontSize: 21, fontWeight: 650, margin: 0 }}>Settings</h2>
          <X size={24} color={T.muted} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>

        <Eyebrow>Profiles</Eyebrow>
        <div style={{ marginBottom: 8 }}>
          {A.users.map((u) => (
            <div key={u.id} onClick={() => { onClose(); A.switchUser(u.id); }} style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 12px", borderRadius: 12, marginBottom: 6, cursor: "pointer", background: u.id === A.user.id ? T.accentDim : T.surface2, border: `1px solid ${u.id === A.user.id ? T.accent : T.line}` }}>
              <User size={18} color={u.id === A.user.id ? T.accent : T.muted} />
              <span style={{ flex: 1, fontWeight: 600, fontSize: 14 }}>{u.name}</span>
              {u.id === A.user.id ? <Mono style={{ fontSize: 11, color: T.accent }}>active</Mono> : <ChevronRight size={16} color={T.faint} />}
            </div>
          ))}
          <div onClick={() => { onClose(); A.beginCreate(); }} style={{ display: "flex", alignItems: "center", gap: 8, padding: "10px 12px", borderRadius: 12, border: `1px dashed ${T.line}`, color: T.accent, cursor: "pointer", justifyContent: "center", fontWeight: 600, fontSize: 14 }}><Plus size={16} /> Add profile</div>
        </div>

        <div style={{ height: 1, background: T.line, margin: "18px 0" }} />
        <Eyebrow>Your details</Eyebrow>
        {field("Name", "name")}
        <div style={{ display: "flex", gap: 10 }}><div style={{ flex: 1 }}>{field("Age", "age", { num: true })}</div><div style={{ flex: 1 }}>{field("Height (cm)", "height", { num: true })}</div></div>
        <div style={{ display: "flex", gap: 10 }}><div style={{ flex: 1 }}>{field("Current (kg)", "currentWeight", { num: true })}</div><div style={{ flex: 1 }}>{field("Target (kg)", "targetWeight", { num: true })}</div></div>
        {field("Target date", "targetDate", { type: "date" })}
        {seg("Goal", "goalType", [["fatLoss", "Fat loss"], ["weightGain", "Muscle gain"], ["maintain", "Maintain"]])}
        {seg("Diet", "dietPref", [["veg", "Veg"], ["egg", "Egg"], ["nonveg", "Non-veg"]])}
        {seg("Activity", "activity", [["light", "Light"], ["moderate", "Moderate"], ["active", "Active"]])}

        <div onClick={save} style={{ ...primaryBtn, marginTop: 8, display: "flex", gap: 8, alignItems: "center", justifyContent: "center" }}><Sparkles size={17} /> Save &amp; recalculate plan</div>

        <div style={{ marginTop: 16, textAlign: "center" }}>
          <Mono style={{ fontSize: 11, color: T.faint }}>storage: {A.mode}</Mono>
          {A.mode === "sqlite" && <div onClick={exportDb} style={{ fontSize: 12, color: T.accent, marginTop: 8, cursor: "pointer" }}>Export database (.sqlite)</div>}
        </div>
      </div>
    </div>
  );
}

/* ============================ ROOT ============================ */
const TABS = [
  { k: "home", label: "Home", icon: Home },
  { k: "train", label: "Train", icon: Dumbbell },
  { k: "library", label: "Library", icon: BookOpen },
  { k: "progress", label: "Progress", icon: TrendingUp },
  { k: "food", label: "Diet", icon: Utensils },
];

function Loading({ msg }) {
  return (
    <div style={{ minHeight: "100vh", background: T.bg, color: T.text, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div style={{ width: 40, height: 40, borderRadius: 12, background: T.accent, display: "flex", alignItems: "center", justifyContent: "center" }}><Dumbbell size={24} color="#1A1206" /></div>
      <div className="mono" style={{ fontSize: 13, color: T.muted }}>{msg || "Loading…"}</div>
    </div>
  );
}

export default function App() {
  const [ready, setReady] = useState(false);
  const [mode, setMode] = useState("localStorage");
  const [view, setView] = useState("loading"); // loading | onboarding | picker | app
  const [users, setUsers] = useState([]);
  const [user, setUser] = useState(null);
  const [data, setData] = useState(DEFAULT_DATA);
  const [foods, setFoods] = useState([]);
  const [tab, setTab] = useState("home");
  const [trainDay, setTrainDay] = useState(null);
  const [exDetail, setExDetail] = useState(null);
  const [showSettings, setShowSettings] = useState(false);
  const [showActivity, setShowActivity] = useState(false);
  const [showPlan, setShowPlan] = useState(false);
  const uidRef = useRef(null);

  useEffect(() => {
    (async () => {
      const m = await initBackend(); setMode(m);
      const us = await Backend.listUsers(); setUsers(us);
      const active = await Backend.getMeta("activeUser");
      const activeId = active != null ? parseInt(active, 10) : null;
      if (us.length === 0) { setView("onboarding"); setReady(true); return; }
      if (activeId && us.some((u) => u.id === activeId)) { await loadUser(activeId, us); }
      else { setView("picker"); }
      setReady(true);
    })();
  }, []);

  const loadUser = async (id, usersList) => {
    const ud = await Backend.getUserData(id);
    const merged = { ...DEFAULT_DATA, ...ud };
    setData(merged);
    setFoods(await Backend.getFoods(id));
    const u = (usersList || users).find((x) => x.id === id) || { id, name: (ud.settings && ud.settings.name) || "Me" };
    setUser(u); uidRef.current = id;
    await Backend.setMeta("activeUser", String(id));
    setTab("home"); setView("app");
  };

  const update = useCallback((key, fn) => {
    setData((prev) => {
      const next = typeof fn === "function" ? fn(prev[key]) : fn;
      Backend.setUserKV(uidRef.current, key, next);
      return { ...prev, [key]: next };
    });
  }, []);

  const addFood = useCallback(async (food) => { await Backend.addFood(uidRef.current, food); setFoods(await Backend.getFoods(uidRef.current)); }, []);
  const removeFood = useCallback(async (id) => { await Backend.deleteFood(uidRef.current, id); setFoods(await Backend.getFoods(uidRef.current)); }, []);

  const onboardingComplete = async (profile, plan) => {
    const id = await Backend.addUser(profile.name);
    const settings = {
      name: profile.name, sex: profile.sex, age: +profile.age, height: +profile.height, units: profile.units || "kg",
      goalType: profile.goalType, dietPref: profile.dietPref, currentWeight: +profile.currentWeight,
      targetWeight: +profile.targetWeight, targetDate: profile.targetDate, activity: profile.activity,
      calorieGoal: plan.calorieGoal, proteinGoal: plan.proteinGoal, stepGoal: plan.stepGoal,
    };
    await Backend.setUserKV(id, "settings", settings);
    await Backend.setUserKV(id, "plan", plan);
    await Backend.setUserKV(id, "weight", [{ date: todayStr(), weight: +profile.currentWeight }]);
    const us = await Backend.listUsers(); setUsers(us);
    await loadUser(id, us);
  };

  const switchUser = (id) => loadUser(id);
  const beginCreate = () => setView("onboarding");

  if (!ready) return <><style>{CSS}</style><Loading msg="Opening your database…" /></>;
  if (view === "onboarding") return <><style>{CSS}</style><Onboarding onComplete={onboardingComplete} onCancel={users.length ? () => setView("picker") : undefined} /></>;
  if (view === "picker") return <><style>{CSS}</style><ProfilePicker users={users} onPick={switchUser} onCreate={beginCreate} /></>;
  if (!user) return <><style>{CSS}</style><Loading /></>;

  const A = { ready, mode, users, user, data, foods, update, addFood, removeFood, switchUser, beginCreate, exportBlob: () => Backend.exportBlob() };
  const go = (t, day) => { if (day) setTrainDay(day); setTab(t); };

  return (
    <AppCtx.Provider value={A}>
      <style>{CSS}</style>
      <div style={{ background: T.bg, color: T.text, minHeight: "100vh", maxWidth: 480, margin: "0 auto", fontFamily: "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif", position: "relative" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "calc(14px + env(safe-area-inset-top)) 16px 4px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{ width: 26, height: 26, borderRadius: 8, background: T.accent, display: "flex", alignItems: "center", justifyContent: "center" }}><Dumbbell size={15} color="#1A1206" /></div>
            <span style={{ fontWeight: 700, letterSpacing: -0.3 }}>Cut<span style={{ color: T.accent }}>Track</span></span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <span style={{ fontSize: 12, color: T.muted, display: "flex", alignItems: "center", gap: 5 }}><User size={14} />{user.name}</span>
            <SettingsIcon size={21} color={T.muted} onClick={() => setShowSettings(true)} style={{ cursor: "pointer" }} />
          </div>
        </div>

        <div style={{ paddingBottom: "calc(86px + env(safe-area-inset-bottom))" }}>
          {tab === "home" && <Dashboard go={go} openActivity={() => setShowActivity(true)} openPlan={() => setShowPlan(true)} />}
          {tab === "train" && <Train initialDay={trainDay} openExercise={setExDetail} />}
          {tab === "library" && <Library openExercise={setExDetail} />}
          {tab === "progress" && <Progress openActivity={() => setShowActivity(true)} />}
          {tab === "food" && <Nutrition />}
        </div>

        <div style={{ position: "fixed", bottom: 0, left: "50%", transform: "translateX(-50%)", width: "100%", maxWidth: 480, background: "rgba(12,12,13,.86)", backdropFilter: "blur(12px)", borderTop: `1px solid ${T.line}`, display: "flex", padding: "8px 4px calc(14px + env(safe-area-inset-bottom))", zIndex: 40 }}>
          {TABS.map((t) => {
            const Icon = t.icon; const active = tab === t.k;
            return (
              <div key={t.k} onClick={() => setTab(t.k)} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 3, cursor: "pointer", color: active ? T.accent : T.faint }}>
                <Icon size={21} /><span style={{ fontSize: 10, fontWeight: 600 }}>{t.label}</span>
              </div>
            );
          })}
        </div>

        {exDetail && <ExerciseDetail name={exDetail} onClose={() => setExDetail(null)} />}
        {showSettings && <SettingsSheet onClose={() => setShowSettings(false)} />}
        {showActivity && <LogActivitySheet onClose={() => setShowActivity(false)} />}
        {showPlan && <PlanSheet onClose={() => setShowPlan(false)} />}
      </div>
    </AppCtx.Provider>
  );
}

const CSS = `
  * { -webkit-tap-highlight-color: transparent; box-sizing: border-box; }
  .mono { font-family: ui-monospace,'SF Mono',Menlo,Consolas,monospace; font-variant-numeric: tabular-nums; }
  ::-webkit-scrollbar { display: none; }
  .noscroll::-webkit-scrollbar { display: none; }
  input::placeholder { color: ${T.faint}; }
  input { color-scheme: dark; }
  input:focus-visible { outline: 2px solid ${T.accent}; outline-offset: 2px; }
  @keyframes slideUp { from { transform: translateY(40px); opacity: 0 } to { transform: translateY(0); opacity: 1 } }
  @media (prefers-reduced-motion: reduce) { * { animation: none !important; transition: none !important; } }
  a { color: ${T.accent}; }
`;
