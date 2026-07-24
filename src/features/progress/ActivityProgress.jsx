import { Plus, Footprints, Flame } from "lucide-react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, AreaChart, Area } from "recharts";
import { T } from "../../shared/theme";
import { Card, Eyebrow, Mono, primaryBtn, PaperCard, IconBubble } from "../../shared/ui/atoms";
import { todayStr, fmtDay, daysBetween } from "../../shared/lib/helpers";
import { useApp } from "../../app/AppContext";

export function ActivityProgress({ openActivity }) {
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
        <PaperCard style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <IconBubble icon={<Footprints size={18} color="#fff" />} size={40} bg={T.hero} color="#fff" />
          <div><Mono style={{ fontSize: 20, fontWeight: 700 }}>{totSteps.toLocaleString()}</Mono><div style={{ fontSize: 11.5, color: T.paperMuted }}>avg {avg.toLocaleString()}/day</div></div>
        </PaperCard>
        <PaperCard style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <IconBubble icon={<Flame size={18} color="#fff" />} size={40} bg={T.hero} color="#fff" />
          <div><Mono style={{ fontSize: 20, fontWeight: 700 }}>{totKcal}</Mono><div style={{ fontSize: 11.5, color: T.paperMuted }}>kcal · {totMin} min</div></div>
        </PaperCard>
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
