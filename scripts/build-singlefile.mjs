// Builds dist/index.html (already inlined JS/CSS via vite-plugin-singlefile)
// then folds in the remaining public/ assets (sql-wasm, icons, manifest) so the
// result is one fully self-contained HTML file: CutTracker.html.
import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const pub = (f) => path.join(root, "public", f);
const dist = (f) => path.join(root, "dist", f);

execSync("npx vite build", { cwd: root, stdio: "inherit" });

let html = readFileSync(dist("index.html"), "utf8");

const b64 = (f) => readFileSync(f).toString("base64");
const sqlWasmJs = readFileSync(pub("sql-wasm.js"), "utf8");
const sqlWasmB64 = b64(pub("sql-wasm.wasm"));
const appleTouchB64 = b64(pub("apple-touch.png"));
const icon192B64 = b64(pub("icon-192.png"));
const icon512B64 = b64(pub("icon-512.png"));

const manifest = JSON.parse(readFileSync(pub("manifest.webmanifest"), "utf8"));
manifest.icons = [
  { src: `data:image/png;base64,${icon192B64}`, sizes: "192x192", type: "image/png" },
  { src: `data:image/png;base64,${icon512B64}`, sizes: "512x512", type: "image/png", purpose: "any maskable" },
];
const manifestDataUri = `data:application/manifest+json;base64,${Buffer.from(JSON.stringify(manifest)).toString("base64")}`;

html = html
  .replace(
    '<script src="/sql-wasm.js"></script>\n<script>window.__SQL_WASM__="/sql-wasm.wasm";</script>',
    `<script>${sqlWasmJs}</script>\n<script>window.__SQL_WASM__="data:application/wasm;base64,${sqlWasmB64}";</script>`
  )
  .replace('<link rel="apple-touch-icon" href="/apple-touch.png" />', `<link rel="apple-touch-icon" href="data:image/png;base64,${appleTouchB64}" />`)
  .replace('<link rel="manifest" href="/manifest.webmanifest" />', `<link rel="manifest" href="${manifestDataUri}" />`)
  .replace(
    '<script>if("serviceWorker" in navigator){window.addEventListener("load",()=>navigator.serviceWorker.register("/sw.js").catch(()=>{}))}</script>\n',
    ""
  );

if (html.includes('src="/') || html.includes('href="/')) {
  throw new Error("build-singlefile: unresolved absolute asset reference left in output");
}

writeFileSync(path.join(root, "CutTracker.html"), html);
console.log(`Wrote ${path.join(root, "CutTracker.html")} (${(html.length / 1024).toFixed(0)} KB)`);
