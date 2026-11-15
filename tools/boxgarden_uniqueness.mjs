// Route rhythm and size tokens for the box-garden map generators; a mirror of tools/audit_map_uniqueness.py.
// Moved out of handcraft_ch01_boxgarden.mjs unchanged; it imports these names back.

export const median = (arr) => { const s = [...arr].sort((a, b) => a - b); const m = Math.floor(s.length / 2); return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };

export function mainRouteOrdered(design) {
  return design.filter((p) => p.route_role === "main").sort((a, b) => a.route_order - b.route_order);
}

export function rhythmTokens(route) {
  if (route.length < 2) return [];
  const centers = route.map((p) => [p.x + p.w / 2, p.y + p.h / 2]);
  const dists = centers.slice(1).map((c, i) => Math.hypot(c[0] - centers[i][0], c[1] - centers[i][1]));
  const nz = dists.filter((d) => d > 1e-6);
  const dScale = nz.length ? median(nz) : 1;
  const wScale = median(route.map((p) => p.w).filter((w) => w > 0)) || 1;
  const toks = [];
  for (let i = 0; i + 1 < centers.length; i++) {
    const dx = centers[i + 1][0] - centers[i][0], dy = centers[i + 1][1] - centers[i][1];
    const a = ((Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) % 8) + 8) % 8;
    const d = Math.min(12, Math.max(0, Math.round((dists[i] / dScale) * 4)));
    const w = Math.round((route[i + 1].w / wScale) * 4);
    toks.push(`a${a}:d${d}:w${w}`);
  }
  return toks;
}

export function sizeTokens(route) {
  if (!route.length) return [];
  const scale = median(route.map((p) => Math.sqrt(Math.max(1, p.w * p.h))));
  return route.map((p) => `w${Math.round((p.w / scale) * 4)}:h${Math.round((p.h / scale) * 4)}`);
}

export function duplicateWindows(values, size) {
  const seen = new Map(); const dups = [];
  for (let i = 0; i + size <= values.length; i++) {
    const key = values.slice(i, i + size).join("|");
    if (seen.has(key)) dups.push({ first: seen.get(key), pos: i });
    else seen.set(key, i);
  }
  return dups;
}

export function repeatRatio(values, size) {
  const total = Math.max(1, values.length - size + 1);
  return duplicateWindows(values, size).length / total;
}
