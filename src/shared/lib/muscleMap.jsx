import { T } from "../theme";

const FRONT = [
  { t: "circle", cx: 100, cy: 30, r: 15 }, { t: "rect", x: 93, y: 43, w: 14, h: 10, rx: 4 },
  { t: "rect", x: 72, y: 60, w: 56, h: 86, rx: 14 }, { t: "rect", x: 72, y: 144, w: 56, h: 22, rx: 8 },
  { t: "poly", pts: "84,55 116,55 124,72 76,72", region: "traps" },
  { t: "circle", cx: 62, cy: 70, r: 12, region: "frontDelts" }, { t: "circle", cx: 138, cy: 70, r: 12, region: "frontDelts" },
  { t: "circle", cx: 52, cy: 74, r: 9, region: "sideDelts" }, { t: "circle", cx: 148, cy: 74, r: 9, region: "sideDelts" },
  { t: "rect", x: 74, y: 64, w: 23, h: 28, rx: 10, region: "chest" }, { t: "rect", x: 103, y: 64, w: 23, h: 28, rx: 10, region: "chest" },
  { t: "rect", x: 86, y: 96, w: 28, h: 46, rx: 6, region: "abs" },
  { t: "rect", x: 48, y: 78, w: 15, h: 32, rx: 7, region: "biceps" }, { t: "rect", x: 137, y: 78, w: 15, h: 32, rx: 7, region: "biceps" },
  { t: "rect", x: 45, y: 112, w: 14, h: 40, rx: 7, region: "forearms" }, { t: "rect", x: 141, y: 112, w: 14, h: 40, rx: 7, region: "forearms" },
  { t: "rect", x: 75, y: 166, w: 23, h: 66, rx: 11, region: "quads" }, { t: "rect", x: 102, y: 166, w: 23, h: 66, rx: 11, region: "quads" },
  { t: "rect", x: 78, y: 234, w: 18, h: 60, rx: 8, region: "calves" }, { t: "rect", x: 104, y: 234, w: 18, h: 60, rx: 8, region: "calves" },
];
const BACK = [
  { t: "circle", cx: 100, cy: 30, r: 15 }, { t: "rect", x: 93, y: 43, w: 14, h: 10, rx: 4 },
  { t: "rect", x: 72, y: 60, w: 56, h: 86, rx: 14 }, { t: "rect", x: 72, y: 144, w: 56, h: 22, rx: 8 },
  { t: "poly", pts: "86,56 114,56 126,84 74,84", region: "traps" },
  { t: "circle", cx: 62, cy: 70, r: 12, region: "rearDelts" }, { t: "circle", cx: 138, cy: 70, r: 12, region: "rearDelts" },
  { t: "circle", cx: 52, cy: 74, r: 9, region: "sideDelts" }, { t: "circle", cx: 148, cy: 74, r: 9, region: "sideDelts" },
  { t: "rect", x: 84, y: 84, w: 32, h: 22, rx: 6, region: "upperBack" },
  { t: "poly", pts: "74,90 99,90 93,140 78,132", region: "lats" }, { t: "poly", pts: "126,90 101,90 107,140 122,132", region: "lats" },
  { t: "rect", x: 90, y: 126, w: 20, h: 20, rx: 6, region: "lowerBack" },
  { t: "rect", x: 48, y: 78, w: 15, h: 32, rx: 7, region: "triceps" }, { t: "rect", x: 137, y: 78, w: 15, h: 32, rx: 7, region: "triceps" },
  { t: "rect", x: 45, y: 112, w: 14, h: 40, rx: 7, region: "forearms" }, { t: "rect", x: 141, y: 112, w: 14, h: 40, rx: 7, region: "forearms" },
  { t: "rect", x: 76, y: 146, w: 23, h: 32, rx: 11, region: "glutes" }, { t: "rect", x: 101, y: 146, w: 23, h: 32, rx: 11, region: "glutes" },
  { t: "rect", x: 75, y: 178, w: 23, h: 56, rx: 11, region: "hamstrings" }, { t: "rect", x: 102, y: 178, w: 23, h: 56, rx: 11, region: "hamstrings" },
  { t: "rect", x: 78, y: 236, w: 18, h: 58, rx: 8, region: "calves" }, { t: "rect", x: 104, y: 236, w: 18, h: 58, rx: 8, region: "calves" },
];

export function MuscleMap({ view = "front", primary = [], secondary = [], size = 120 }) {
  const shapes = view === "back" ? BACK : FRONT;
  const col = (r) => (!r ? T.muscleBase : primary.includes(r) ? T.accent : secondary.includes(r) ? T.accentSoft : T.muscleBase);
  return (
    <svg viewBox="0 0 200 305" width={size} height={size * 1.45} style={{ overflow: "visible" }}>
      {shapes.map((s, i) => {
        const fill = col(s.region), stroke = T.bg;
        if (s.t === "circle") return <circle key={i} cx={s.cx} cy={s.cy} r={s.r} fill={fill} stroke={stroke} strokeWidth="0.6" />;
        if (s.t === "poly") return <polygon key={i} points={s.pts} fill={fill} stroke={stroke} strokeWidth="0.6" />;
        return <rect key={i} x={s.x} y={s.y} width={s.w} height={s.h} rx={s.rx} fill={fill} stroke={stroke} strokeWidth="0.6" />;
      })}
    </svg>
  );
}
