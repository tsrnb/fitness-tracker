import { Minus, Plus, Check, ChevronRight } from "lucide-react";
import { T } from "../theme";

export const Card = ({ children, style, onClick }) => (
  <div onClick={onClick} style={{ background: T.surface, border: `1px solid ${T.line}`, borderRadius: T.rL, padding: 16, ...style }}>{children}</div>
);

/** Bold flat-color hero card (the orange/lavender tiles on the dashboard grid). */
export const HeroCard = ({ children, tone = "hero", style, onClick }) => {
  const bg = tone === "lav" ? T.lav : tone === "paper" ? T.paper : T.hero;
  const ink = tone === "lav" ? T.lavInk : tone === "paper" ? T.paperInk : "#fff";
  return (
    <div onClick={onClick} style={{ background: bg, color: ink, borderRadius: T.rXL, padding: 18, ...style }}>{children}</div>
  );
};

/** Flat light "paper" card with dark ink text, used for the bottom summary row. */
export const PaperCard = ({ children, style, onClick }) => (
  <div onClick={onClick} style={{ background: T.paper, color: T.paperInk, borderRadius: T.rXL, padding: 16, ...style }}>{children}</div>
);

/** Circular icon holder with a soft tinted background. */
export const IconBubble = ({ icon, size = 44, bg, color, style, onClick }) => (
  <div onClick={onClick} style={{ width: size, height: size, borderRadius: T.pill, background: bg || T.accentDim, color: color || T.accent, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, ...style }}>{icon}</div>
);

/** Rounded pill row used inside HeroCard checklists, e.g. "Morning walk · 6:30am". */
export const ChecklistPill = ({ label, sub, done, onClick, tone = "hero" }) => {
  const bg = tone === "lav" ? "rgba(28,30,58,0.1)" : "rgba(255,255,255,0.16)";
  const ink = tone === "lav" ? T.lavInk : "#fff";
  return (
    <div onClick={onClick} style={{ display: "flex", alignItems: "center", gap: 10, background: bg, borderRadius: T.pill, padding: "10px 14px", cursor: onClick ? "pointer" : "default" }}>
      <div style={{ width: 22, height: 22, borderRadius: T.pill, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", background: done ? ink : "transparent", border: done ? "none" : `2px solid ${ink}`, opacity: done ? 1 : 0.7 }}>
        {done && <Check size={13} color={tone === "lav" ? T.lav : T.hero} strokeWidth={3} />}
      </div>
      <div style={{ color: ink, minWidth: 0 }}>
        <div style={{ fontWeight: 700, fontSize: 14, lineHeight: 1.2 }}>{label}</div>
        {sub && <div style={{ fontSize: 11.5, opacity: 0.8, marginTop: 1 }}>{sub}</div>}
      </div>
    </div>
  );
};

/** Pill button pairing a label with a circular icon badge, e.g. the "Start ▶" CTA. */
export const ActionPill = ({ label, icon, onClick, style }) => (
  <div onClick={onClick} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10, background: "#fff", color: T.paperInk, borderRadius: T.pill, padding: "8px 8px 8px 20px", cursor: "pointer", fontWeight: 700, fontSize: 15, ...style }}>
    {label}
    <div style={{ width: 34, height: 34, borderRadius: T.pill, background: "#141416", color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>{icon || <ChevronRight size={17} />}</div>
  </div>
);
export const Mono = ({ children, style }) => <span className="mono" style={style}>{children}</span>;
export const Eyebrow = ({ children, style }) => (
  <div className="mono" style={{ fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.faint, marginBottom: 8, ...style }}>{children}</div>
);

/** Bold page header used at the top of every tab: icon bubble + title + optional subtitle. */
export const PageHeader = ({ icon, title, sub }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
    {icon && <IconBubble icon={icon} size={40} bg={T.hero} color="#fff" />}
    <div>
      <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0, letterSpacing: -0.2 }}>{title}</h1>
      {sub && <div style={{ fontSize: 13, color: T.muted, marginTop: 2 }}>{sub}</div>}
    </div>
  </div>
);

/** Rounded-full segmented control, visually matching the bottom tab bar's sliding pill highlight. */
export function PillTabs({ options, value, onChange, scroll }) {
  return (
    <div style={{ display: "flex", gap: 4, background: T.surface, border: `1px solid ${T.line}`, borderRadius: T.pill, padding: 4, marginBottom: 16, overflowX: scroll ? "auto" : "visible" }} className={scroll ? "noscroll" : undefined}>
      {options.map(([k, l]) => {
        const active = value === k;
        return (
          <div key={k} onClick={() => onChange(k)} style={{ flex: scroll ? "0 0 auto" : 1, textAlign: "center", padding: "9px 16px", borderRadius: T.pill, cursor: "pointer", fontWeight: 600, fontSize: 13, whiteSpace: "nowrap", background: active ? T.hero : "transparent", color: active ? "#fff" : T.muted, transition: "background .2s ease" }}>{l}</div>
        );
      })}
    </div>
  );
}

export function Ring({ value, goal, size = 132, label, unit, color, onPaper }) {
  const pct = Math.min(1, goal ? value / goal : 0), r = size / 2 - 10, c = 2 * Math.PI * r, done = pct >= 1;
  const stroke = done ? T.success : (color || T.accent);
  const track = onPaper ? "rgba(21,21,26,0.1)" : T.surface2;
  const ink = onPaper ? T.paperInk : T.text;
  const sub = onPaper ? T.paperMuted : T.muted;
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth="10" />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={stroke} strokeWidth="10" strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={c * (1 - pct)} style={{ transition: "stroke-dashoffset .6s ease" }} />
      </svg>
      <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
        <Mono style={{ fontSize: size > 110 ? 26 : 22, fontWeight: 600, color: done ? T.success : ink, lineHeight: 1 }}>{Math.round(value)}</Mono>
        <Mono style={{ fontSize: 11, color: sub, marginTop: 2 }}>/ {goal}{unit}</Mono>
        {label && <span style={{ fontSize: 10, color: sub, marginTop: 4 }}>{label}</span>}
      </div>
    </div>
  );
}

export function Stepper({ value, onChange, step = 1, min = 0, suffix }) {
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

export const overlay = { position: "fixed", inset: 0, background: "rgba(0,0,0,.6)", backdropFilter: "blur(4px)", zIndex: 100, display: "flex", alignItems: "flex-end", justifyContent: "center" };
export const sheet = { background: T.bg, borderTop: `1px solid ${T.line}`, borderRadius: `${T.rXL}px ${T.rXL}px 0 0`, padding: "22px 22px calc(22px + env(safe-area-inset-bottom))", width: "100%", maxWidth: 480, maxHeight: "90vh", overflowY: "auto", animation: "slideUp .25s ease" };
export const primaryBtn = { background: T.accent, color: "#fff", textAlign: "center", padding: 16, borderRadius: T.pill, fontWeight: 700, cursor: "pointer" };

export const OptBtn = ({ active, onClick, icon, label, sub }) => (
  <div onClick={onClick} style={{
    display: "flex", alignItems: "center", gap: 12, padding: 10, paddingRight: 16, borderRadius: T.pill, cursor: "pointer",
    background: active ? T.accentDim : T.surface, border: `1px solid ${active ? T.hero : T.line}`, marginBottom: 10,
  }}>
    {icon && <IconBubble icon={icon} size={38} bg={active ? T.hero : T.surface2} color={active ? "#fff" : T.muted} />}
    <div style={{ flex: 1 }}>
      <div style={{ fontWeight: 700, fontSize: 15 }}>{label}</div>
      {sub && <div style={{ fontSize: 12, color: T.muted, marginTop: 2 }}>{sub}</div>}
    </div>
    {active && <IconBubble icon={<Check size={14} color="#fff" strokeWidth={3} />} size={26} bg={T.hero} />}
  </div>
);

export const NumIn = ({ value, onChange, ph, suffix }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 8, background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "0 14px" }}>
    <input value={value} onChange={(e) => onChange(e.target.value)} inputMode="decimal" placeholder={ph} className="mono"
      style={{ flex: 1, background: "transparent", border: "none", outline: "none", color: T.text, fontSize: 18, padding: "13px 0" }} />
    {suffix && <Mono style={{ color: T.muted, fontSize: 14 }}>{suffix}</Mono>}
  </div>
);
