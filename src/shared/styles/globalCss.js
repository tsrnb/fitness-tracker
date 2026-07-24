import { T } from "../theme";
import { FONT_FACE_CSS } from "./fontFaces";

export const CSS = `
  ${FONT_FACE_CSS}
  * { -webkit-tap-highlight-color: transparent; box-sizing: border-box; }
  .mono { font-family: ui-monospace,'SF Mono',Menlo,Consolas,monospace; font-variant-numeric: tabular-nums; }
  ::-webkit-scrollbar { display: none; }
  .noscroll::-webkit-scrollbar { display: none; }
  input::placeholder { color: ${T.faint}; }
  input { color-scheme: dark; }
  input:focus-visible { outline: 2px solid ${T.accent}; outline-offset: 2px; }
  @keyframes slideUp { from { transform: translateY(40px); opacity: 0 } to { transform: translateY(0); opacity: 1 } }
  @media (prefers-reduced-motion: reduce) { * { animation: none !important; transition: none !important; } }
  a { color: ${T.accent}; }
`;
