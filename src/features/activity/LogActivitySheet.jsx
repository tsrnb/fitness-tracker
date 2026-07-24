import { useState } from "react";
import { X, Activity } from "lucide-react";
import { T } from "../../shared/theme";
import { Eyebrow, NumIn, primaryBtn, overlay, sheet, IconBubble } from "../../shared/ui/atoms";
import { todayStr, fmtDay } from "../../shared/lib/helpers";
import { useApp } from "../../app/AppContext";

export function LogActivitySheet({ onClose }) {
  const A = useApp();
  const today = todayStr();
  const cur = A.data.activity[today] || { steps: 0, kcal: 0, min: 0 };
  const [steps, setSteps] = useState(cur.steps || 0);
  const [kcal, setKcal] = useState(cur.kcal || 0);
  const [min, setMin] = useState(cur.min || 0);
  const save = () => { A.update("activity", (prev) => ({ ...prev, [today]: { steps: +steps || 0, kcal: +kcal || 0, min: +min || 0 } })); onClose(); };
  const chip = (label, fn) => <div onClick={fn} className="mono" style={{ padding: "9px 16px", borderRadius: T.pill, background: T.surface2, border: `1px solid ${T.line}`, fontSize: 13, cursor: "pointer" }}>{label}</div>;
  return (
    <div style={overlay} onClick={onClose}>
      <div style={sheet} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 4 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <IconBubble icon={<Activity size={16} color="#fff" />} size={36} bg={T.hero} />
            <h2 style={{ fontSize: 21, fontWeight: 700, margin: 0 }}>Log activity</h2>
          </div>
          <IconBubble icon={<X size={18} color={T.muted} />} size={36} bg={T.surface2} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>
        <div style={{ fontSize: 13, color: T.muted, marginTop: 10, marginBottom: 18 }}>{fmtDay(today)}</div>
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
