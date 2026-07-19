const C = "cuttracker-v3";
self.addEventListener("install", e => { self.skipWaiting(); });
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    caches.open(C).then(cache => cache.match(e.request).then(hit => {
      const net = fetch(e.request).then(res => { if (res && res.status === 200) cache.put(e.request, res.clone()); return res; }).catch(() => hit);
      return hit || net;
    }))
  );
});
