// Parses lines like "2 Rotis, 240, 6" -> {name, kcal, protein}. Also tolerates "Name, 240" (protein 0).
export function parseMealLines(raw) {
  const lines = raw.split("\n").map((l) => l.trim()).filter(Boolean);
  const items = [];
  for (const line of lines) {
    const parts = line.split(",").map((p) => p.trim()).filter((p) => p !== "");
    if (parts.length < 2) continue;
    const protein = parts.length >= 3 ? parseFloat(parts[parts.length - 1]) : 0;
    const kcalIdx = parts.length >= 3 ? parts.length - 2 : parts.length - 1;
    const kcal = parseFloat(parts[kcalIdx]);
    const name = parts.slice(0, kcalIdx).join(", ").trim();
    if (!name || !(kcal >= 0)) continue;
    items.push({ name, kcal: Math.round(kcal), protein: Math.round(protein || 0) });
  }
  return items;
}
