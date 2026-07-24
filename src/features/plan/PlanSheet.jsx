import { X, Sparkles } from "lucide-react";
import { T } from "../../shared/theme";
import { Card, Mono, Eyebrow, overlay, sheet, IconBubble } from "../../shared/ui/atoms";
import { fmtDay } from "../../shared/lib/helpers";
import { useApp } from "../../app/AppContext";
import { DAY_ORDER } from "../training/program";

export function PlanSheet({ onClose }) {
  const A = useApp();
  const st = A.data.settings || {};
  const plan = A.data.plan;
  if (!plan) { return <div style={overlay} onClick={onClose}><div style={sheet} onClick={(e) => e.stopPropagation()}><p style={{ color: T.muted }}>No plan yet.</p></div></div>; }
  const mealKcal = plan.meals.reduce((a, b) => a + b.kcal, 0);
  const mealProt = plan.meals.reduce((a, b) => a + b.protein, 0);
  return (
    <div style={overlay} onClick={onClose}>
      <div style={sheet} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 4 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <IconBubble icon={<Sparkles size={16} color="#fff" />} size={36} bg={T.hero} />
            <h2 style={{ fontSize: 21, fontWeight: 700, margin: 0 }}>Your plan</h2>
          </div>
          <IconBubble icon={<X size={18} color={T.muted} />} size={36} bg={T.surface2} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>
        <p style={{ color: T.muted, fontSize: 13, marginTop: 10, marginBottom: 16 }}>{plan.headline}</p>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10, marginBottom: 14 }}>
          <Card style={{ padding: 12 }}><Eyebrow>Cals</Eyebrow><Mono style={{ fontSize: 20, fontWeight: 650 }}>{plan.calorieGoal}</Mono></Card>
          <Card style={{ padding: 12 }}><Eyebrow>Protein</Eyebrow><Mono style={{ fontSize: 20, fontWeight: 650 }}>{plan.proteinGoal}g</Mono></Card>
          <Card style={{ padding: 12 }}><Eyebrow>Steps</Eyebrow><Mono style={{ fontSize: 20, fontWeight: 650 }}>{(plan.stepGoal / 1000)}k</Mono></Card>
        </div>

        <Card style={{ marginBottom: 14 }}>
          <Eyebrow>Training — 5-day PPLUL</Eyebrow>
          <div style={{ fontSize: 14, lineHeight: 1.5, marginBottom: 8 }}>{plan.splitNote}</div>
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            {DAY_ORDER.map((d) => <span key={d} className="mono" style={{ fontSize: 12, padding: "6px 12px", background: T.surface2, borderRadius: T.pill, border: `1px solid ${T.line}` }}>{d}</span>)}
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
