import { useState } from "react";
import { ChevronLeft, Sparkles, Flame, TrendingUp, Target, Salad, Egg, Drumstick } from "lucide-react";
import { T } from "../../shared/theme";
import { Card, Mono, Eyebrow, OptBtn, NumIn, primaryBtn, IconBubble } from "../../shared/ui/atoms";
import { fmtDay } from "../../shared/lib/helpers";
import { generatePlan } from "../plan/planGenerator";

export function Onboarding({ onComplete, onCancel }) {
  const [step, setStep] = useState(0);
  const [f, setF] = useState({
    name: "", sex: "male", age: "", height: "", currentWeight: "", targetWeight: "",
    targetDate: new Date(Date.now() + 84 * 86400000).toISOString().slice(0, 10),
    activity: "moderate", goalType: "fatLoss", dietPref: "veg", units: "kg",
  });
  const set = (patch) => setF((p) => ({ ...p, ...patch }));
  const steps = ["name", "sex", "stats", "goal", "target", "activity", "diet", "summary"];
  const cur = steps[step];
  const canNext = () => {
    if (cur === "name") return f.name.trim().length > 0;
    if (cur === "stats") return +f.age > 0 && +f.height > 0 && +f.currentWeight > 0;
    if (cur === "target") return f.goalType === "maintain" ? true : +f.targetWeight > 0 && !!f.targetDate;
    return true;
  };
  const next = () => {
    if (cur === "target" && f.goalType === "maintain" && !f.targetWeight) set({ targetWeight: f.currentWeight });
    if (step < steps.length - 1) setStep(step + 1); else finish();
  };
  const back = () => (step === 0 ? onCancel && onCancel() : setStep(step - 1));
  const finish = () => {
    const profile = { ...f, targetWeight: f.targetWeight || f.currentWeight };
    onComplete(profile, generatePlan(profile));
  };
  const plan = cur === "summary" ? generatePlan({ ...f, targetWeight: f.targetWeight || f.currentWeight }) : null;

  return (
    <div style={{ minHeight: "100vh", background: T.bg, color: T.text, maxWidth: 480, margin: "0 auto", padding: "calc(20px + env(safe-area-inset-top)) 18px calc(40px + env(safe-area-inset-bottom))", boxSizing: "border-box" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 6 }}>
        <IconBubble icon={<ChevronLeft size={20} color={T.muted} />} size={36} bg={T.surface} onClick={back} style={{ cursor: "pointer", border: `1px solid ${T.line}` }} />
        <div style={{ flex: 1, height: 6, background: T.surface2, borderRadius: T.pill, overflow: "hidden" }}>
          <div style={{ width: `${((step + 1) / steps.length) * 100}%`, height: "100%", background: T.hero, borderRadius: T.pill, transition: "width .3s" }} />
        </div>
      </div>

      <div style={{ paddingTop: 26 }}>
        {cur === "name" && <>
          <IconBubble icon={<Sparkles size={20} color="#fff" />} size={42} bg={T.hero} />
          <h1 style={{ fontSize: 26, fontWeight: 700, margin: "14px 0 6px" }}>Let's build your plan</h1>
          <p style={{ color: T.muted, fontSize: 14, marginTop: 0, marginBottom: 22 }}>I'll act as your trainer and nutritionist. First — what should I call you?</p>
          <input value={f.name} onChange={(e) => set({ name: e.target.value })} placeholder="Your name"
            style={{ width: "100%", boxSizing: "border-box", background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "14px", color: T.text, fontSize: 17, outline: "none" }} />
        </>}

        {cur === "sex" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 4 }}>Biological sex</h1>
          <p style={{ color: T.muted, fontSize: 13, marginTop: 0, marginBottom: 20 }}>Used only to estimate your calorie needs accurately.</p>
          <OptBtn active={f.sex === "male"} onClick={() => set({ sex: "male" })} label="Male" />
          <OptBtn active={f.sex === "female"} onClick={() => set({ sex: "female" })} label="Female" />
        </>}

        {cur === "stats" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Your stats</h1>
          <Eyebrow>Age</Eyebrow><div style={{ marginBottom: 14 }}><NumIn value={f.age} onChange={(v) => set({ age: v })} ph="28" suffix="yrs" /></div>
          <Eyebrow>Height</Eyebrow><div style={{ marginBottom: 14 }}><NumIn value={f.height} onChange={(v) => set({ height: v })} ph="175" suffix="cm" /></div>
          <Eyebrow>Current weight</Eyebrow><NumIn value={f.currentWeight} onChange={(v) => set({ currentWeight: v })} ph="78" suffix="kg" />
        </>}

        {cur === "goal" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Your goal</h1>
          <OptBtn active={f.goalType === "fatLoss"} onClick={() => set({ goalType: "fatLoss" })} icon={<Flame size={22} />} label="Lose fat" sub="Cut while keeping muscle" />
          <OptBtn active={f.goalType === "weightGain"} onClick={() => set({ goalType: "weightGain" })} icon={<TrendingUp size={22} />} label="Build muscle" sub="Lean weight gain" />
          <OptBtn active={f.goalType === "maintain"} onClick={() => set({ goalType: "maintain" })} icon={<Target size={22} />} label="Maintain" sub="Recomp & hold" />
        </>}

        {cur === "target" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 4 }}>{f.goalType === "maintain" ? "Timeline" : "Target"}</h1>
          <p style={{ color: T.muted, fontSize: 13, marginTop: 0, marginBottom: 20 }}>By when do you want to see the result? I'll check if it's realistic.</p>
          {f.goalType !== "maintain" && <>
            <Eyebrow>Target weight</Eyebrow>
            <div style={{ marginBottom: 14 }}><NumIn value={f.targetWeight} onChange={(v) => set({ targetWeight: v })} ph={f.goalType === "fatLoss" ? "72" : "84"} suffix="kg" /></div>
          </>}
          <Eyebrow>Target date</Eyebrow>
          <input type="date" value={f.targetDate} onChange={(e) => set({ targetDate: e.target.value })}
            className="mono" style={{ width: "100%", boxSizing: "border-box", background: T.surface2, border: `1px solid ${T.line}`, borderRadius: 12, padding: "13px 14px", color: T.text, fontSize: 16, outline: "none" }} />
        </>}

        {cur === "activity" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Daily activity</h1>
          <OptBtn active={f.activity === "light"} onClick={() => set({ activity: "light" })} label="Light" sub="Desk job, little walking" />
          <OptBtn active={f.activity === "moderate"} onClick={() => set({ activity: "moderate" })} label="Moderate" sub="On your feet / regular walks" />
          <OptBtn active={f.activity === "active"} onClick={() => set({ activity: "active" })} label="Active" sub="Physical job / lots of steps" />
        </>}

        {cur === "diet" && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 20 }}>Diet preference</h1>
          <OptBtn active={f.dietPref === "veg"} onClick={() => set({ dietPref: "veg" })} icon={<Salad size={22} />} label="Vegetarian" />
          <OptBtn active={f.dietPref === "egg"} onClick={() => set({ dietPref: "egg" })} icon={<Egg size={22} />} label="Eggetarian" sub="Veg + eggs" />
          <OptBtn active={f.dietPref === "nonveg"} onClick={() => set({ dietPref: "nonveg" })} icon={<Drumstick size={22} />} label="Non-vegetarian" />
        </>}

        {cur === "summary" && plan && <>
          <h1 style={{ fontSize: 24, fontWeight: 650, marginBottom: 4 }}>Your plan, {f.name}</h1>
          <p style={{ color: T.muted, fontSize: 13, marginTop: 0, marginBottom: 16 }}>{plan.headline}</p>
          {!plan.feasible && <Card style={{ background: T.accentDim, borderColor: T.accent, marginBottom: 12 }}>
            <div style={{ fontSize: 13, color: T.text, lineHeight: 1.5 }}>
              That timeline is aggressive for muscle-safe progress. A healthier target date is <Mono style={{ color: T.accent }}>{plan.suggestedDate ? fmtDay(plan.suggestedDate) : "later"}</Mono>. You can still proceed — I'll cap the pace safely.
            </div>
          </Card>}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 12 }}>
            <Card><Eyebrow>Calories</Eyebrow><Mono style={{ fontSize: 24, fontWeight: 650 }}>{plan.calorieGoal}</Mono><div style={{ fontSize: 11, color: T.muted }}>kcal/day · TDEE {plan.tdee}</div></Card>
            <Card><Eyebrow>Protein</Eyebrow><Mono style={{ fontSize: 24, fontWeight: 650 }}>{plan.proteinGoal}g</Mono><div style={{ fontSize: 11, color: T.muted }}>per day</div></Card>
          </div>
          <Card style={{ marginBottom: 12 }}>
            <Eyebrow>Training</Eyebrow>
            <div style={{ fontSize: 14, lineHeight: 1.5 }}>{plan.splitNote}</div>
            <div style={{ fontSize: 13, color: T.muted, marginTop: 8 }}>{plan.cardioNote}</div>
          </Card>
          <div style={{ fontSize: 12, color: T.faint, textAlign: "center" }}>You can fine-tune anything later in Settings.</div>
        </>}
      </div>

      <div onClick={() => canNext() && next()} style={{ ...primaryBtn, marginTop: 26, opacity: canNext() ? 1 : 0.45 }}>
        {cur === "summary" ? "Create my plan" : "Continue"}
      </div>
    </div>
  );
}
