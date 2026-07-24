import { X, Play } from "lucide-react";
import { T } from "../../shared/theme";
import { Eyebrow, Mono, overlay, sheet, primaryBtn, IconBubble } from "../../shared/ui/atoms";
import { MuscleMap } from "../../shared/lib/muscleMap";
import { LIB, yt } from "./exerciseLibrary";
import { PROGRAM, DAY_ORDER } from "../training/program";

export function ExerciseDetail({ name, onClose }) {
  const lib = LIB[name];
  if (!lib) return null;
  let prescribed = null;
  for (const d of DAY_ORDER) { const it = PROGRAM[d].items.find((x) => x.name === name); if (it) { prescribed = it; break; } }
  return (
    <div style={overlay} onClick={onClose}>
      <div style={sheet} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <h2 style={{ fontSize: 21, fontWeight: 700, margin: 0, maxWidth: "80%" }}>{name}</h2>
          <IconBubble icon={<X size={18} color={T.muted} />} size={36} bg={T.surface2} onClick={onClose} style={{ cursor: "pointer" }} />
        </div>
        <div style={{ display: "flex", gap: 16, margin: "14px 0", alignItems: "center" }}>
          <IconBubble icon={<MuscleMap view={lib.view} primary={lib.primary} secondary={lib.secondary} size={92} />} size={112} bg={T.surface2} style={{ border: `1px solid ${T.line}` }} />
          <div>
            <Eyebrow>Targets</Eyebrow>
            <div style={{ fontWeight: 600, fontSize: 15, marginBottom: 10 }}>{lib.target}</div>
            {prescribed && <><Eyebrow>Prescribed</Eyebrow><Mono style={{ fontSize: 18, fontWeight: 600, color: T.hero }}>{prescribed.sets} × {prescribed.reps}</Mono></>}
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
          <Play size={18} fill="#fff" /> Watch tutorial
        </a>
      </div>
    </div>
  );
}
