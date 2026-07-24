import { useState } from "react";
import { ChevronDown, BookOpen } from "lucide-react";
import { T } from "../../shared/theme";
import { Card, Mono, PageHeader } from "../../shared/ui/atoms";
import { MuscleMap } from "../../shared/lib/muscleMap";
import { LIB, GROUPS } from "./exerciseLibrary";

export function Library({ openExercise }) {
  const [q, setQ] = useState("");
  const [openG, setOpenG] = useState({ Chest: true });
  const names = Object.keys(LIB);
  const ql = q.toLowerCase();
  return (
    <div style={{ padding: "8px 16px 16px" }}>
      <PageHeader icon={<BookOpen size={18} color="#fff" />} title="Exercise library" />
      <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search exercises"
        style={{ width: "100%", boxSizing: "border-box", background: T.surface, border: `1px solid ${T.line}`, borderRadius: T.pill, padding: "13px 18px", color: T.text, fontSize: 15, marginBottom: 16, outline: "none" }} />
      {GROUPS.map((g) => {
        const list = names.filter((n) => LIB[n].g === g && (!q || n.toLowerCase().includes(ql)));
        if (!list.length) return null;
        const isOpen = q ? true : openG[g];
        return (
          <div key={g} style={{ marginBottom: 12 }}>
            <div onClick={() => setOpenG((s) => ({ ...s, [g]: !s[g] }))} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "10px 4px", cursor: "pointer" }}>
              <div style={{ fontWeight: 700, fontSize: 16 }}>{g} <Mono style={{ fontSize: 12, color: T.faint }}>· {list.length}</Mono></div>
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
