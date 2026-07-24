import { Footprints, Flame, Moon, Sparkles, Dumbbell, Plus } from "lucide-react";
import { T } from "../../shared/theme";
import { Card, Mono, Eyebrow, Ring, HeroCard, PaperCard, IconBubble, ChecklistPill, ActionPill } from "../../shared/ui/atoms";
import { todayStr, fmtFull, daysBetween } from "../../shared/lib/helpers";
import { useApp } from "../../app/AppContext";
import { PROGRAM, WEEKDAY } from "../training/program";

export function Dashboard({ go, openActivity, openPlan }) {
  const A = useApp();
  const st = A.data.settings || {};
  const today = todayStr();
  const dow = new Date().getDay();
  const todayDay = WEEKDAY[dow] || null;
  const exercises = todayDay ? PROGRAM[todayDay].items || [] : [];
  const loggedToday = (name) => { const h = A.data.history[name] || []; return h.length && h[h.length - 1].date === today; };

  const meals = A.data.diet[today] || [];
  const kcalToday = meals.reduce((a, b) => a + (b.kcal || 0), 0);
  const protToday = meals.reduce((a, b) => a + (b.protein || 0), 0);
  const calGoal = st.calorieGoal || 2000;
  const protGoal = st.proteinGoal || 150;
  const burnedToday = (A.data.activity[today] || {}).kcal || 0;
  const adjustedCalGoal = calGoal + burnedToday;

  const lastWeight = A.data.weight.length ? A.data.weight[A.data.weight.length - 1].weight : null;
  const cur = st.currentWeight ?? lastWeight;
  const tgt = st.targetWeight;
  const daysLeft = st.targetDate ? Math.max(0, daysBetween(today, st.targetDate)) : null;

  const act = A.data.activity[today] || { steps: 0, kcal: 0, min: 0 };
  const stepGoal = st.stepGoal || 10000;
  const last7 = Object.keys(A.data.sessions).filter((d) => { const df = daysBetween(d, today); return df >= 0 && df < 7; }).length;

  return (
    <div style={{ padding: "10px 16px 16px" }}>
      <Mono style={{ fontSize: 11.5, color: T.faint, letterSpacing: 1, textTransform: "uppercase", display: "block", marginBottom: 12 }}>{fmtFull()}</Mono>

      {/* hero grid: workout plan + featured action */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 12, alignItems: "stretch" }}>
        <HeroCard tone="hero" onClick={() => go("train", todayDay)} style={{ cursor: "pointer", display: "flex", flexDirection: "column", gap: 10 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <div style={{ fontWeight: 700, fontSize: 19, lineHeight: 1.15 }}>{todayDay || "Rest"}<br />Day</div>
            <IconBubble icon={<Dumbbell size={16} color="#fff" />} size={34} bg="rgba(255,255,255,0.2)" color="#fff" />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {todayDay ? exercises.slice(0, 2).map((ex) => (
              <ChecklistPill key={ex.name} label={ex.name} sub={`${ex.sets} × ${ex.reps}`} done={loggedToday(ex.name)} />
            )) : <ChecklistPill label="Walk & recover" sub="Active rest" done={!!A.data.activity[today]} />}
          </div>
        </HeroCard>

        <HeroCard tone="lav" onClick={() => go("food")} style={{ cursor: "pointer", display: "flex", flexDirection: "column", justifyContent: "space-between", gap: 10 }}>
          <div>
            <div style={{ fontSize: 11.5, opacity: 0.75, fontWeight: 700, textTransform: "uppercase", letterSpacing: 0.5 }}>Nutrition</div>
            <div style={{ fontWeight: 700, fontSize: 20, lineHeight: 1.18, marginTop: 6 }}>Hit Your Daily Protein Goal</div>
          </div>
          <ActionPill label="Log food" icon={<Plus size={17} />} />
        </HeroCard>
      </div>

      {/* calories + protein */}
      <Card style={{ marginBottom: 12, display: "flex", justifyContent: "space-around", alignItems: "center" }}>
        <div style={{ textAlign: "center" }}><Ring value={kcalToday} goal={adjustedCalGoal} size={100} unit="" color={T.hero} /><div style={{ fontSize: 11, color: T.muted, marginTop: 6 }}>calories</div></div>
        <div style={{ textAlign: "center" }}><Ring value={protToday} goal={protGoal} size={100} unit="g" color={T.blue} /><div style={{ fontSize: 11, color: T.muted, marginTop: 6 }}>protein</div></div>
      </Card>

      {/* bottom summary: this week's sessions, paper card w/ ring like the reference */}
      <PaperCard onClick={() => go("train")} style={{ cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12, marginBottom: 12 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <IconBubble icon={<Dumbbell size={20} color="#fff" />} size={48} bg={T.hero} color="#fff" />
          <div>
            <div style={{ fontWeight: 700, fontSize: 16 }}>{todayDay || "Recovery"}</div>
            <div style={{ fontSize: 12.5, color: T.paperMuted, marginTop: 2 }}>{last7} of 5 sessions this week</div>
          </div>
        </div>
        <Ring value={last7} goal={5} size={58} unit="" onPaper color={T.hero} />
      </PaperCard>

      {/* weight + plan */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 12 }}>
        <Card onClick={() => go("progress")} style={{ cursor: "pointer" }}>
          <Eyebrow>Body weight</Eyebrow>
          {cur != null ? <>
            <div><Mono style={{ fontSize: 26, fontWeight: 650 }}>{cur}</Mono><Mono style={{ color: T.muted, fontSize: 13 }}> {st.units || "kg"}</Mono></div>
            {tgt != null && <div style={{ fontSize: 12, color: T.muted, marginTop: 4 }}>{Math.abs(cur - tgt).toFixed(1)} to {tgt}{daysLeft != null ? ` · ${daysLeft}d left` : ""}</div>}
          </> : <div style={{ color: T.muted, fontSize: 13, marginTop: 8 }}>Log a weigh-in</div>}
        </Card>
        <Card onClick={openPlan} style={{ cursor: "pointer" }}>
          <Eyebrow>Your plan</Eyebrow>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 2 }}>
            <Sparkles size={18} color={T.hero} />
            <div style={{ fontWeight: 600, fontSize: 14, textTransform: "capitalize" }}>{(st.goalType || "").replace("fatLoss", "Fat loss").replace("weightGain", "Muscle gain") || "Coach"}</div>
          </div>
          <div style={{ fontSize: 12, color: T.muted, marginTop: 6 }}>Tap for diet & training</div>
        </Card>
      </div>

      {/* activity */}
      <Card onClick={openActivity} style={{ cursor: "pointer", marginBottom: 12 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
          <Eyebrow>Today's activity</Eyebrow>
          <div style={{ display: "flex", alignItems: "center", gap: 4, color: T.hero, fontSize: 12, fontWeight: 600 }}><Plus size={14} /> log</div>
        </div>
        <div style={{ display: "flex", gap: 16 }}>
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}><Footprints size={16} color={T.hero} /><Mono style={{ fontSize: 22, fontWeight: 650 }}>{(act.steps || 0).toLocaleString()}</Mono></div>
            <div style={{ height: 5, background: T.surface2, borderRadius: 3, marginTop: 7, overflow: "hidden" }}><div style={{ width: `${Math.min(100, (act.steps || 0) / stepGoal * 100)}%`, height: "100%", background: (act.steps || 0) >= stepGoal ? T.success : T.hero }} /></div>
            <div style={{ fontSize: 11, color: T.muted, marginTop: 5 }}>steps · goal {stepGoal.toLocaleString()}</div>
          </div>
          <div style={{ width: 1, background: T.line }} />
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}><Flame size={16} color={T.hero} /><Mono style={{ fontSize: 22, fontWeight: 650 }}>{act.kcal || 0}</Mono><Mono style={{ fontSize: 12, color: T.muted }}>kcal</Mono></div>
            <div style={{ fontSize: 11, color: T.muted, marginTop: 14 }}>cardio · {act.min || 0} min</div>
          </div>
        </div>
      </Card>

      <div style={{ textAlign: "center", color: T.faint, fontSize: 12, marginTop: 8, lineHeight: 1.6 }}>
        <Moon size={13} style={{ verticalAlign: "middle" }} /> Hit {protGoal}g protein, keep lifts heavy, sleep 7+ hrs.
      </div>
    </div>
  );
}
