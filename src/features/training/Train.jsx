import { useState, useEffect } from "react";
import { ChevronDown, Check, ArrowUp, Play, Save, Clock, X, Dumbbell } from "lucide-react";
import { T } from "../../shared/theme";
import { Card, Mono, Stepper, primaryBtn, PageHeader, PillTabs, PaperCard, IconBubble, Ring } from "../../shared/ui/atoms";
import { todayStr, epley, topReps, lowReps } from "../../shared/lib/helpers";
import { MuscleMap } from "../../shared/lib/muscleMap";
import { useApp } from "../../app/AppContext";
import { LIB } from "../exercises/exerciseLibrary";
import { PROGRAM, DAY_ORDER, WEEKDAY } from "./program";

export function Train({ initialDay, openExercise }) {
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
  const loggedCount = items.filter((it) => savedToday(it.name)).length;

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
      <PageHeader icon={<Dumbbell size={19} color="#fff" />} title="Train" sub={PROGRAM[day].focus} />

      <PillTabs options={DAY_ORDER.map((d) => [d, d])} value={day} onChange={setDay} scroll />

      <PaperCard style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12, marginBottom: 14 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <IconBubble icon={<Dumbbell size={20} color="#fff" />} size={48} bg={T.hero} color="#fff" />
          <div>
            <div style={{ fontWeight: 700, fontSize: 16 }}>{day} day</div>
            <div style={{ fontSize: 12.5, color: T.paperMuted, marginTop: 2 }}>{loggedCount} of {items.length} exercises logged today</div>
          </div>
        </div>
        <Ring value={loggedCount} goal={items.length} size={54} unit="" onPaper color={T.hero} />
      </PaperCard>

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
