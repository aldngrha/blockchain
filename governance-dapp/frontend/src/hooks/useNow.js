import { useSyncExternalStore } from "react";

// A ticking time source so time-derived UI (has the timelock eta passed?)
// does not call Date.now() during render. The snapshot is cached between
// ticks (useSyncExternalStore requires a stable snapshot; a raw Date.now()
// there would loop).
const TICK_MS = 10000;
let cachedNow = Date.now();

function subscribe(onStoreChange) {
  const id = window.setInterval(() => {
    cachedNow = Date.now();
    onStoreChange();
  }, TICK_MS);
  return () => window.clearInterval(id);
}

export function useNow() {
  return useSyncExternalStore(subscribe, () => cachedNow, () => 0);
}
