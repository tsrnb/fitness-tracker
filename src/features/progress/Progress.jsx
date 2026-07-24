import { useState } from "react";
import { Trophy, TrendingUp } from "lucide-react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, AreaChart, Area } from "recharts";
import { T } from "../../shared/theme";
import { Card, Eyebrow, Mono, primaryBtn, PageHeader, PillTabs, IconBubble } from "../../shared/ui/atoms";
import { todayStr, fmtDay, epley } from "../../shared/lib/helpers";
import { useApp } from "../../app/AppContext";
import { ActivityProgress } from "./ActivityProgress";

export function Progress({ openActivity }) {
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
      <PageHeader icon={<TrendingUp size={19} color="#fff" />} title="Progress" />
      <PillTabs options={[["weight", "Weight"], ["strength", "Strength"], ["activity", "Activity"]]} value={tab} onChange={setTab} />

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
            <div key={n} onClick={() => setExSel(n)} style={{ whiteSpace: "nowrap", padding: "8px 15px", borderRadius: T.pill, fontSize: 13, fontWeight: 600, cursor: "pointer", background: exSel === n ? T.hero : T.surface, color: exSel === n ? "#fff" : T.text, border: `1px solid ${exSel === n ? T.hero : T.line}` }}>{n}</div>
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
            <div key={p.n} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10, padding: "9px 0", borderTop: `1px solid ${T.surface2}` }}>
              <span style={{ fontSize: 14, display: "flex", gap: 10, alignItems: "center", minWidth: 0 }}><IconBubble icon={<Trophy size={14} color="#fff" />} size={30} bg={T.hero} />{p.n}</span>
              <Mono style={{ fontSize: 13, color: T.muted, whiteSpace: "nowrap" }}>{p.bestW}kg · ~{p.best} 1RM</Mono>
            </div>
          ))}
        </Card>}
      </>}

      {tab === "activity" && <ActivityProgress openActivity={openActivity} />}
    </div>
  );
}
