/* ---- Foods for quick-add, filtered by diet preference (kcal, protein per portion) ---- */
const FOOD_DB = {
  base: [
    { name: "Oats 50g + whey", kcal: 330, protein: 37 },
    { name: "Greek yogurt 200g", kcal: 120, protein: 20 },
    { name: "Whey scoop", kcal: 120, protein: 24 },
    { name: "Milk 250ml", kcal: 150, protein: 8 },
    { name: "Peanut butter 2 tbsp", kcal: 190, protein: 8 },
    { name: "Banana", kcal: 105, protein: 1 },
    { name: "Rice 1 cup", kcal: 200, protein: 4 },
    { name: "Roti (1)", kcal: 120, protein: 3 },
    { name: "Dal 1 cup", kcal: 180, protein: 12 },
  ],
  veg: [
    { name: "Paneer 100g", kcal: 265, protein: 18 },
    { name: "Tofu 100g", kcal: 120, protein: 12 },
    { name: "Soya chunks 50g dry", kcal: 175, protein: 26 },
    { name: "Rajma 1 cup", kcal: 210, protein: 13 },
    { name: "Chickpeas 1 cup", kcal: 210, protein: 12 },
  ],
  egg: [
    { name: "Whole eggs (2)", kcal: 156, protein: 12 },
    { name: "Egg whites (3)", kcal: 51, protein: 11 },
    { name: "Paneer 100g", kcal: 265, protein: 18 },
    { name: "Soya chunks 50g dry", kcal: 175, protein: 26 },
  ],
  nonveg: [
    { name: "Chicken breast 100g", kcal: 165, protein: 31 },
    { name: "Fish 100g", kcal: 180, protein: 22 },
    { name: "Tuna can (100g)", kcal: 110, protein: 25 },
    { name: "Whole eggs (2)", kcal: 156, protein: 12 },
    { name: "Egg whites (3)", kcal: 51, protein: 11 },
  ],
};

export const foodsForPref = (pref) => [...FOOD_DB.base, ...(FOOD_DB[pref] || FOOD_DB.veg)];
