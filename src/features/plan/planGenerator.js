import { todayStr, daysBetween, clamp, round10 } from "../../shared/lib/helpers";

/* ---- Sample "bachelor-simple" meal day per preference (portions scale to the calorie target) ---- */
const MEAL_DAYS = {
  veg: [
    { time: "Breakfast", name: "Oats + whey + banana", kcal: 435, protein: 38 },
    { time: "Lunch", name: "Rice + dal + paneer bhurji", kcal: 620, protein: 33 },
    { time: "Snack", name: "Greek yogurt + peanut butter", kcal: 310, protein: 28 },
    { time: "Dinner", name: "Roti + rajma + salad", kcal: 500, protein: 22 },
    { time: "Before bed", name: "Milk + whey", kcal: 270, protein: 32 },
  ],
  egg: [
    { time: "Breakfast", name: "3-egg omelette + 2 toast", kcal: 400, protein: 26 },
    { time: "Lunch", name: "Rice + dal + paneer", kcal: 600, protein: 34 },
    { time: "Snack", name: "Greek yogurt + banana", kcal: 260, protein: 22 },
    { time: "Dinner", name: "Roti + soya curry", kcal: 480, protein: 30 },
    { time: "Before bed", name: "Milk + whey", kcal: 270, protein: 32 },
  ],
  nonveg: [
    { time: "Breakfast", name: "3 eggs + 2 toast", kcal: 380, protein: 26 },
    { time: "Lunch", name: "Rice + chicken curry + salad", kcal: 620, protein: 45 },
    { time: "Snack", name: "Greek yogurt + peanut butter", kcal: 310, protein: 28 },
    { time: "Dinner", name: "Roti + fish/chicken + veg", kcal: 500, protein: 38 },
    { time: "Before bed", name: "Milk + whey", kcal: 270, protein: 32 },
  ],
};

/* ============================ COACH: PLAN GENERATOR ============================ */
export function generatePlan(p) {
  const kg = +p.currentWeight, tgt = +p.targetWeight, cm = +p.height, age = +p.age;
  const male = p.sex !== "female";
  const bmr = 10 * kg + 6.25 * cm - 5 * age + (male ? 5 : -161);
  const af = p.activity === "active" ? 1.725 : p.activity === "moderate" ? 1.55 : 1.375;
  const tdee = bmr * af;
  const days = Math.max(14, daysBetween(todayStr(), p.targetDate || todayStr()) || 84);

  let calorieGoal, weeklyRate, feasible = true, suggestedDate = null, headline;
  if (p.goalType === "fatLoss") {
    const kgToLose = Math.max(0, kg - tgt);
    const reqDeficit = (kgToLose * 7700) / days;
    const safeMax = Math.min(0.25 * tdee, 850);
    const deficit = clamp(reqDeficit || 400, 250, safeMax);
    calorieGoal = round10(Math.max(tdee - deficit, 1.2 * bmr));
    weeklyRate = +(((tdee - calorieGoal) * 7) / 7700).toFixed(2);
    feasible = reqDeficit <= safeMax + 1;
    if (!feasible) { const need = Math.ceil((kgToLose * 7700) / safeMax); suggestedDate = new Date(Date.now() + need * 86400000).toISOString().slice(0, 10); }
    headline = `Lose ~${weeklyRate}kg/week in a ${Math.round(tdee - calorieGoal)} kcal daily deficit.`;
  } else if (p.goalType === "weightGain") {
    const kgToGain = Math.max(0, tgt - kg);
    const reqSurplus = (kgToGain * 7700) / days;
    const surplus = clamp(reqSurplus || 300, 150, 500);
    calorieGoal = round10(tdee + surplus);
    weeklyRate = +((surplus * 7) / 7700).toFixed(2);
    feasible = reqSurplus <= 500 + 1;
    if (!feasible) { const need = Math.ceil((kgToGain * 7700) / 500); suggestedDate = new Date(Date.now() + need * 86400000).toISOString().slice(0, 10); }
    headline = `Gain ~${weeklyRate}kg/week in a ${Math.round(calorieGoal - tdee)} kcal daily surplus (lean bulk).`;
  } else {
    calorieGoal = round10(tdee); weeklyRate = 0;
    headline = `Maintain around ${calorieGoal} kcal/day.`;
  }

  const proteinPerKg = p.goalType === "fatLoss" ? 2.0 : 1.8;
  const proteinGoal = Math.max(130, Math.round(proteinPerKg * kg));
  const stepGoal = p.goalType === "fatLoss" ? 10000 : 8000;

  const cardioNote = p.goalType === "fatLoss"
    ? "2–3 easy 15–20 min incline walks after lifting, plus daily steps. Don't overdo cardio — muscle retention is the priority."
    : "Keep cardio light (steps + warm-ups). Extra cardio just eats into your surplus.";
  const splitNote = p.goalType === "weightGain"
    ? "5-day PPLUL, lower reps on the first lift (6–8), push progressive overload every week."
    : "5-day PPLUL, keep the main lifts heavy (6–8) to hold strength, higher reps on isolation.";

  const meals = MEAL_DAYS[p.dietPref] || MEAL_DAYS.veg;
  return {
    tdee: Math.round(tdee), bmr: Math.round(bmr), calorieGoal, proteinGoal, stepGoal,
    weeklyRate, feasible, suggestedDate, headline, cardioNote, splitNote, meals,
  };
}
