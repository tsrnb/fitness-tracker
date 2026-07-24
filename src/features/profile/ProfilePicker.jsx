import { Dumbbell, User, Plus, ChevronRight } from "lucide-react";
import { T } from "../../shared/theme";

export function ProfilePicker({ users, onPick, onCreate }) {
  return (
    <div style={{ minHeight: "100vh", background: T.bg, color: T.text, maxWidth: 480, margin: "0 auto", padding: "calc(40px + env(safe-area-inset-top)) 18px calc(40px + env(safe-area-inset-bottom))", boxSizing: "border-box" }}>
      <div style={{ width: 44, height: 44, borderRadius: T.pill, background: T.hero, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 18 }}>
        <Dumbbell size={22} color="#fff" />
      </div>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>Who's training?</h1>
      <p style={{ color: T.muted, fontSize: 14, marginTop: 0, marginBottom: 24 }}>Pick a profile on this device, or add a new one.</p>
      {users.map((u) => (
        <div key={u.id} onClick={() => onPick(u.id)} style={{ display: "flex", alignItems: "center", gap: 14, padding: 16, borderRadius: T.rL, background: T.surface, border: `1px solid ${T.line}`, marginBottom: 12, cursor: "pointer" }}>
          <div style={{ width: 44, height: 44, borderRadius: T.pill, background: T.accentDim, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <User size={22} color={T.hero} />
          </div>
          <div style={{ flex: 1, fontWeight: 600, fontSize: 16 }}>{u.name}</div>
          <ChevronRight size={20} color={T.faint} />
        </div>
      ))}
      <div onClick={onCreate} style={{ display: "flex", alignItems: "center", gap: 10, padding: 16, borderRadius: T.rL, border: `1px dashed ${T.line}`, color: T.hero, cursor: "pointer", justifyContent: "center", fontWeight: 600 }}>
        <Plus size={18} /> Add profile
      </div>
    </div>
  );
}
