import { useState, useMemo } from "react";
import { Flame, Minus, Plus, Droplet, Save, X, Utensils } from "lucide-react";
import { T } from "../../shared/theme";
import { Card, Ring, Eyebrow, Mono, NumIn, primaryBtn, overlay, sheet, PageHeader, IconBubble } from "../../shared/ui/atoms";
import { todayStr } from "../../shared/lib/helpers";
import { useApp } from "../../app/AppContext";
import { foodsForPref } from "./foodDb";
import { parseMealLines } from "./parseMealLines";

export function Nutrition() {
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
      <PageHeader icon={<Utensils size={18} color="#fff" />} title="Diet book" />

      <Card style={{ display: "flex", justifyContent: "space-around", alignItems: "center", marginBottom: 14 }}>
        <div style={{ textAlign: "center" }}><Ring value={kcal} goal={adjustedGoal} size={108} unit="" color={T.hero} /><div style={{ fontSize: 11, color: T.muted, marginTop: 6 }}>{remaining > 0 ? `${remaining} kcal left` : "calories"}</div></div>
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
          <IconBubble icon={<Flame size={14} color="#fff" />} size={28} bg={deficit >= 0 ? T.success : T.danger} />
        </div>
        <Mono style={{ fontSize: 26, fontWeight: 650, color: deficit >= 0 ? T.success : T.danger }}>{Math.abs(deficit)}<span style={{ fontSize: 13, color: T.muted, fontWeight: 500 }}> kcal</span></Mono>
        <div style={{ fontSize: 12, color: T.muted, marginTop: 4 }}>vs. maintenance (~{Math.round(tdee)} kcal){burned > 0 ? `, net of ${burned} kcal burned` : ""}</div>
      </Card>

      <Card style={{ marginBottom: 14, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <IconBubble icon={<Droplet size={16} color="#fff" />} size={34} bg={water * 0.25 >= 3 ? T.success : T.hero} />
          <Eyebrow style={{ marginBottom: 0 }}>Water</Eyebrow>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <IconBubble icon={<Minus size={16} />} size={30} bg={T.surface2} color={T.muted} onClick={() => setWater(water - 1)} style={{ cursor: "pointer" }} />
          <div style={{ display: "flex", alignItems: "baseline", gap: 4 }}><Mono style={{ fontSize: 18 }}>{(water * 0.25).toFixed(2)}</Mono><Mono style={{ fontSize: 12, color: T.muted }}>/ 3.5L</Mono></div>
          <IconBubble icon={<Plus size={16} color="#fff" />} size={30} bg={T.hero} onClick={() => setWater(water + 1)} style={{ cursor: "pointer" }} />
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
            <div onClick={() => confirmPending(false)} style={{ textAlign: "center", padding: 14, borderRadius: T.pill, border: `1px solid ${T.line}`, color: T.text, cursor: "pointer", fontWeight: 600 }}>Just add for today</div>
          </div>
        </div>
      )}
    </div>
  );
}
