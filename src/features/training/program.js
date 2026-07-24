/* ---- 5-day PPLUL program (loads/rep guidance adapt via goal, exercise list stays practical) ---- */
export const PROGRAM = {
  Push: { focus: "Chest · Shoulders · Triceps", items: [
    { name: "Barbell Bench Press", sets: 4, reps: "6-8" },
    { name: "Incline Dumbbell Press", sets: 3, reps: "8-10" },
    { name: "Pec Deck Fly", sets: 3, reps: "10-12" },
    { name: "Dumbbell Lateral Raise", sets: 4, reps: "12-15" },
    { name: "Rope Tricep Pushdown", sets: 3, reps: "10-12" },
    { name: "Overhead Cable Tricep Extension", sets: 3, reps: "10-12" },
  ]},
  Pull: { focus: "Back · Rear Delts · Biceps", items: [
    { name: "Wide Grip Lat Pulldown", sets: 4, reps: "8-10" },
    { name: "Chest Supported Row", sets: 4, reps: "8-10" },
    { name: "Seated Cable Row", sets: 3, reps: "10-12" },
    { name: "Face Pull", sets: 3, reps: "12-15" },
    { name: "Rear Delt Fly", sets: 3, reps: "12-15" },
    { name: "Barbell Curl", sets: 3, reps: "8-10" },
    { name: "Hammer Curl", sets: 3, reps: "10-12" },
  ]},
  Legs: { focus: "Quads · Hamstrings · Calves", items: [
    { name: "Barbell Squat", sets: 4, reps: "6-8" },
    { name: "Leg Press", sets: 4, reps: "10-12" },
    { name: "Leg Extension", sets: 3, reps: "12-15" },
    { name: "Lying Leg Curl", sets: 4, reps: "10-12" },
    { name: "Standing Calf Raise", sets: 4, reps: "15-20" },
    { name: "Seated Calf Raise", sets: 3, reps: "15-20" },
  ]},
  Upper: { focus: "Chest · Back · Shoulders · Arms", items: [
    { name: "Incline Barbell Press", sets: 3, reps: "8-10" },
    { name: "Lat Pulldown", sets: 3, reps: "8-10" },
    { name: "Seated Cable Row", sets: 3, reps: "10-12" },
    { name: "Machine Shoulder Press", sets: 3, reps: "8-10" },
    { name: "Dumbbell Lateral Raise", sets: 3, reps: "12-15" },
    { name: "EZ Bar Curl", sets: 3, reps: "10-12" },
    { name: "Rope Tricep Pushdown", sets: 3, reps: "10-12" },
  ]},
  Lower: { focus: "Quads · Glutes · Hamstrings", items: [
    { name: "Hack Squat", sets: 4, reps: "8-10" },
    { name: "Leg Press", sets: 3, reps: "10-12" },
    { name: "Lying Leg Curl", sets: 4, reps: "10-12" },
    { name: "Hip Thrust", sets: 3, reps: "8-10" },
    { name: "Leg Extension", sets: 3, reps: "12-15" },
    { name: "Seated Calf Raise", sets: 4, reps: "15-20" },
  ]},
};
export const DAY_ORDER = ["Push", "Pull", "Legs", "Upper", "Lower"];
export const WEEKDAY = { 1: "Push", 2: "Pull", 3: "Legs", 4: "Upper", 5: "Lower" };
