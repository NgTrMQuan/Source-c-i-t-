/* Service worker: trang & dữ liệu lấy mạng trước (luôn mới nhất), mất mạng thì dùng bản đã lưu.
   Không bao giờ chạm vào link tải của Autodesk (khác tên miền). */
const V = 'ak-v1';
const CORE = ['./', 'index.html', 'cai-dat.html', 'loi.html', 'data.json', 'errors.json', 'link-status.json', 'favicon.svg', 'icon-192.png', 'manifest.webmanifest'];
self.addEventListener('install', e => { e.waitUntil(caches.open(V).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== 'GET') return;
  const fonts = /fonts\.(googleapis|gstatic)\.com$/.test(u.hostname);
  if (u.origin !== location.origin && !fonts) return;                 // Autodesk, GitHub API… đi thẳng
  if (fonts || /\/icons\/|\.png$|\.svg$|\.ico$/.test(u.pathname)) {      // ảnh, font: dùng bản lưu trước
    e.respondWith(caches.match(r).then(m => m || fetch(r).then(res => { if (res.ok || res.type === 'opaque') { const c = res.clone(); caches.open(V).then(x => x.put(r, c)); } return res; })));
    return;
  }
  e.respondWith(fetch(r).then(res => { if (res.ok) { const c = res.clone(); caches.open(V).then(x => x.put(r, c)); } return res; })
    .catch(() => caches.match(r, {ignoreSearch: true}).then(m => m || caches.match('index.html'))));
});
