import sg400 from "../assets/fonts/SpaceGrotesk-400.woff2";
import sg500 from "../assets/fonts/SpaceGrotesk-500.woff2";
import sg700 from "../assets/fonts/SpaceGrotesk-700.woff2";

export const FONT_STACK = "'Space Grotesk',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif";

export const FONT_FACE_CSS = `
  @font-face { font-family:'Space Grotesk'; font-style:normal; font-weight:400; font-display:swap; src:url(${sg400}) format('woff2'); }
  @font-face { font-family:'Space Grotesk'; font-style:normal; font-weight:500; font-display:swap; src:url(${sg500}) format('woff2'); }
  @font-face { font-family:'Space Grotesk'; font-style:normal; font-weight:700; font-display:swap; src:url(${sg700}) format('woff2'); }
`;
