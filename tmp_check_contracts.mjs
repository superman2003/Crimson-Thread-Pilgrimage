// Compatibility entry point for historical documentation.
// The inline chapter assertions were superseded by the maintained campaign validators.
import { spawnSync } from "node:child_process";

const windows = process.platform === "win32";
const result = windows
  ? spawnSync(process.env.ComSpec || "cmd.exe", ["/d", "/s", "/c", "npm run test:campaign"], { stdio: "inherit" })
  : spawnSync("npm", ["run", "test:campaign"], { stdio: "inherit" });

process.exitCode = result.status ?? 1;
