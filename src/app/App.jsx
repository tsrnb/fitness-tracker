import { useState, useEffect, useCallback, useRef } from "react";
import { Home, Dumbbell, BookOpen, TrendingUp, Utensils, Settings as SettingsIcon } from "lucide-react";
import { T } from "../shared/theme";
import { CSS } from "../shared/styles/globalCss";
import { FONT_STACK } from "../shared/styles/fontFaces";
import { Backend, initBackend } from "../shared/lib/storage";
import { todayStr } from "../shared/lib/helpers";
import { DEFAULT_DATA, AppCtx } from "./AppContext";
import { Onboarding } from "../features/onboarding/Onboarding";
import { ProfilePicker } from "../features/profile/ProfilePicker";
import { Dashboard } from "../features/dashboard/Dashboard";
import { Train } from "../features/training/Train";
import { Library } from "../features/exercises/Library";
import { ExerciseDetail } from "../features/exercises/ExerciseDetail";
import { Progress } from "../features/progress/Progress";
import { Nutrition } from "../features/nutrition/Nutrition";
import { PlanSheet } from "../features/plan/PlanSheet";
import { LogActivitySheet } from "../features/activity/LogActivitySheet";
import { SettingsSheet } from "../features/settings/SettingsSheet";

const TABS = [
  { k: "home", label: "Home", icon: Home },
  { k: "train", label: "Train", icon: Dumbbell },
  { k: "library", label: "Library", icon: BookOpen },
  { k: "progress", label: "Progress", icon: TrendingUp },
  { k: "food", label: "Diet", icon: Utensils },
];

function Loading({ msg }) {
  return (
    <div style={{ minHeight: "100vh", background: T.bg, color: T.text, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div style={{ width: 44, height: 44, borderRadius: T.rM, background: T.hero, display: "flex", alignItems: "center", justifyContent: "center" }}><Dumbbell size={24} color="#fff" /></div>
      <div className="mono" style={{ fontSize: 13, color: T.muted }}>{msg || "Loading…"}</div>
    </div>
  );
}

export default function App() {
  const [ready, setReady] = useState(false);
  const [mode, setMode] = useState("localStorage");
  const [view, setView] = useState("loading"); // loading | onboarding | picker | app
  const [users, setUsers] = useState([]);
  const [user, setUser] = useState(null);
  const [data, setData] = useState(DEFAULT_DATA);
  const [foods, setFoods] = useState([]);
  const [tab, setTab] = useState("home");
  const [trainDay, setTrainDay] = useState(null);
  const [exDetail, setExDetail] = useState(null);
  const [showSettings, setShowSettings] = useState(false);
  const [showActivity, setShowActivity] = useState(false);
  const [showPlan, setShowPlan] = useState(false);
  const uidRef = useRef(null);

  useEffect(() => {
    (async () => {
      const m = await initBackend(); setMode(m);
      const us = await Backend.listUsers(); setUsers(us);
      const active = await Backend.getMeta("activeUser");
      const activeId = active != null ? parseInt(active, 10) : null;
      if (us.length === 0) { setView("onboarding"); setReady(true); return; }
      if (activeId && us.some((u) => u.id === activeId)) { await loadUser(activeId, us); }
      else { setView("picker"); }
      setReady(true);
    })();
  }, []);

  const loadUser = async (id, usersList) => {
    const ud = await Backend.getUserData(id);
    const merged = { ...DEFAULT_DATA, ...ud };
    setData(merged);
    setFoods(await Backend.getFoods(id));
    const u = (usersList || users).find((x) => x.id === id) || { id, name: (ud.settings && ud.settings.name) || "Me" };
    setUser(u); uidRef.current = id;
    await Backend.setMeta("activeUser", String(id));
    setTab("home"); setView("app");
  };

  const update = useCallback((key, fn) => {
    setData((prev) => {
      const next = typeof fn === "function" ? fn(prev[key]) : fn;
      Backend.setUserKV(uidRef.current, key, next);
      return { ...prev, [key]: next };
    });
  }, []);

  const addFood = useCallback(async (food) => { await Backend.addFood(uidRef.current, food); setFoods(await Backend.getFoods(uidRef.current)); }, []);
  const removeFood = useCallback(async (id) => { await Backend.deleteFood(uidRef.current, id); setFoods(await Backend.getFoods(uidRef.current)); }, []);

  const onboardingComplete = async (profile, plan) => {
    const id = await Backend.addUser(profile.name);
    const settings = {
      name: profile.name, sex: profile.sex, age: +profile.age, height: +profile.height, units: profile.units || "kg",
      goalType: profile.goalType, dietPref: profile.dietPref, currentWeight: +profile.currentWeight,
      targetWeight: +profile.targetWeight, targetDate: profile.targetDate, activity: profile.activity,
      calorieGoal: plan.calorieGoal, proteinGoal: plan.proteinGoal, stepGoal: plan.stepGoal,
    };
    await Backend.setUserKV(id, "settings", settings);
    await Backend.setUserKV(id, "plan", plan);
    await Backend.setUserKV(id, "weight", [{ date: todayStr(), weight: +profile.currentWeight }]);
    const us = await Backend.listUsers(); setUsers(us);
    await loadUser(id, us);
  };

  const switchUser = (id) => loadUser(id);
  const beginCreate = () => setView("onboarding");

  if (!ready) return <><style>{CSS}</style><Loading msg="Opening your database…" /></>;
  if (view === "onboarding") return <><style>{CSS}</style><Onboarding onComplete={onboardingComplete} onCancel={users.length ? () => setView("picker") : undefined} /></>;
  if (view === "picker") return <><style>{CSS}</style><ProfilePicker users={users} onPick={switchUser} onCreate={beginCreate} /></>;
  if (!user) return <><style>{CSS}</style><Loading /></>;

  const A = { ready, mode, users, user, data, foods, update, addFood, removeFood, switchUser, beginCreate, exportBlob: () => Backend.exportBlob() };
  const go = (t, day) => { if (day) setTrainDay(day); setTab(t); };

  return (
    <AppCtx.Provider value={A}>
      <style>{CSS}</style>
      <div style={{ background: T.bg, color: T.text, minHeight: "100vh", maxWidth: 480, margin: "0 auto", fontFamily: FONT_STACK, position: "relative" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "calc(16px + env(safe-area-inset-top)) 16px 4px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ width: 42, height: 42, borderRadius: T.pill, background: T.hero, display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, fontSize: 17, color: "#fff", flexShrink: 0 }}>
              {(user.name || "?").trim().charAt(0).toUpperCase()}
            </div>
            <div>
              <div style={{ fontSize: 12.5, color: T.muted }}>Hello there! 👋</div>
              <div style={{ fontWeight: 700, fontSize: 18, letterSpacing: -0.2, marginTop: 1 }}>{user.name}</div>
            </div>
          </div>
          <div onClick={() => setShowSettings(true)} style={{ width: 42, height: 42, borderRadius: T.pill, background: T.surface, border: `1px solid ${T.line}`, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", flexShrink: 0 }}>
            <SettingsIcon size={19} color={T.muted} />
          </div>
        </div>

        <div style={{ paddingBottom: "calc(90px + env(safe-area-inset-bottom))" }}>
          {tab === "home" && <Dashboard go={go} openActivity={() => setShowActivity(true)} openPlan={() => setShowPlan(true)} />}
          {tab === "train" && <Train initialDay={trainDay} openExercise={setExDetail} />}
          {tab === "library" && <Library openExercise={setExDetail} />}
          {tab === "progress" && <Progress openActivity={() => setShowActivity(true)} />}
          {tab === "food" && <Nutrition />}
        </div>

        <div style={{ position: "fixed", bottom: 14, left: "50%", transform: "translateX(-50%)", width: "calc(100% - 28px)", maxWidth: 452, background: "rgba(22,22,24,.92)", backdropFilter: "blur(14px)", border: `1px solid ${T.line}`, borderRadius: T.pill, display: "flex", padding: 6, zIndex: 40, boxShadow: "0 8px 24px rgba(0,0,0,.35)" }}>
          {TABS.map((t) => {
            const Icon = t.icon; const active = tab === t.k;
            return (
              <div key={t.k} onClick={() => setTab(t.k)} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 2, cursor: "pointer", color: active ? "#fff" : T.faint, background: active ? T.hero : "transparent", borderRadius: T.pill, padding: "8px 4px", transition: "background .2s ease" }}>
                <Icon size={19} /><span style={{ fontSize: 9.5, fontWeight: 600 }}>{t.label}</span>
              </div>
            );
          })}
        </div>

        {exDetail && <ExerciseDetail name={exDetail} onClose={() => setExDetail(null)} />}
        {showSettings && <SettingsSheet onClose={() => setShowSettings(false)} />}
        {showActivity && <LogActivitySheet onClose={() => setShowActivity(false)} />}
        {showPlan && <PlanSheet onClose={() => setShowPlan(false)} />}
      </div>
    </AppCtx.Provider>
  );
}
