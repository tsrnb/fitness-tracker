import { useState } from "react";
import { X, User, Plus, ChevronRight, Sparkles, Settings as SettingsIcon } from "lucide-react";
import { T } from "../../shared/theme";
import { Eyebrow, Mono, primaryBtn, overlay, sheet, IconBubble } from "../../shared/ui/atoms";
import { useApp } from "../../app/AppContext";
import { generatePlan } from "../plan/planGenerator";

export function SettingsSheet({ onClose }) {
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
          <div key={v} onClick={() => set({ [key]: v })} style={{ flex: "1 1 30%", textAlign: "center", padding: "10px 6px", borderRadius: T.pill, cursor: "pointer", fontWeight: 600, fontSize: 13, background: f[key] === v ? T.hero : T.surface2, color: f[key] === v ? "#fff" : T.text, border: `1px solid ${f[key] === v ? T.hero : T.line}` }}>{l}</div>
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
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 16 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <IconBubble icon={<SettingsIcon size={16} color="#fff" />} size={36} bg={T.hero} />
            <h2 style={{ fontSize: 21, fontWeight: 700, margin: 0 }}>Settings</h2>
          </div>
          <IconBubble icon={<X size={18} color={T.muted} />} size={36} bg={T.surface2} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>

        <Eyebrow>Profiles</Eyebrow>
        <div style={{ marginBottom: 8 }}>
          {A.users.map((u) => (
            <div key={u.id} onClick={() => { onClose(); A.switchUser(u.id); }} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 14px 8px 8px", borderRadius: T.pill, marginBottom: 6, cursor: "pointer", background: u.id === A.user.id ? T.accentDim : T.surface2, border: `1px solid ${u.id === A.user.id ? T.hero : T.line}` }}>
              <IconBubble icon={<User size={16} color={u.id === A.user.id ? "#fff" : T.muted} />} size={32} bg={u.id === A.user.id ? T.hero : T.surface} />
              <span style={{ flex: 1, fontWeight: 600, fontSize: 14 }}>{u.name}</span>
              {u.id === A.user.id ? <Mono style={{ fontSize: 11, color: T.hero }}>active</Mono> : <ChevronRight size={16} color={T.faint} />}
            </div>
          ))}
          <div onClick={() => { onClose(); A.beginCreate(); }} style={{ display: "flex", alignItems: "center", gap: 8, padding: "10px 12px", borderRadius: T.pill, border: `1px dashed ${T.line}`, color: T.hero, cursor: "pointer", justifyContent: "center", fontWeight: 600, fontSize: 14 }}><Plus size={16} /> Add profile</div>
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
