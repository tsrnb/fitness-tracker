// Rebuilds CutTracker.html whenever files under src/, public/, index.html, or
// vite.config.js change. Debounces bursts of changes into a single rebuild.
import { spawn } from "node:child_process";
import { watch } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const watched = ["src", "public", "index.html", "vite.config.js"].map((f) => path.join(root, f));

let building = false;
let pending = false;
let timer = null;

function build() {
  if (building) {
    pending = true;
    return;
  }
  building = true;
  console.log("\n[watch] building...");
  const child = spawn("node", [path.join(root, "scripts", "build-singlefile.mjs")], {
    cwd: root,
    stdio: "inherit",
  });
  child.on("exit", (code) => {
    building = false;
    console.log(code === 0 ? "[watch] build done, watching for changes..." : `[watch] build failed (exit ${code})`);
    if (pending) {
      pending = false;
      build();
    }
  });
}

function scheduleBuild() {
  clearTimeout(timer);
  timer = setTimeout(build, 150);
}

for (const target of watched) {
  try {
    watch(target, { recursive: true }, scheduleBuild);
  } catch {
    // target may not exist (e.g. no public/ dir); ignore
  }
}

console.log(`[watch] watching ${watched.map((w) => path.relative(root, w)).join(", ")}`);
build();
