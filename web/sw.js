const CACHE_NAME = 'bm-barber-v1.2.4';
const ASSETS_TO_CACHE = [
  './',
  'index.html',
  'manifest.json',
  'favicon.png',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'logobarber.jpg',
  'flutter.js',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
];
// main.dart.js will be cached automatically by Cache First if we catch it,
// but Flutter often adds versioning. We'll handle it dynamically.

// Install Event - Pre-cache core assets
self.addEventListener('install', (event) => {
  console.log('[SW] Installing version: ', CACHE_NAME);
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Pre-caching core assets');
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
  self.skipWaiting();
});

// Activate Event - Clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch Event - Intelligent Cache/Network Strategies
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // 1. CRITICAL: NEVER CACHE version.json or index.html or main.dart.js with Cache-First
  // Use Network First for these to ensure updates are detected and logic is fresh.
  const isCoreLogic = 
    url.pathname.endsWith('version.json') || 
    url.pathname.endsWith('index.html') || 
    url.pathname.endsWith('main.dart.js') ||
    url.pathname === '/' ||
    url.pathname === './';

  if (isCoreLogic) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response && response.status === 200) {
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, responseClone);
            });
          }
          return response;
        })
        .catch(() => {
          return caches.match(event.request);
        })
    );
    return;
  }

  // Strategy: Network First for API and dynamic data
  if (url.pathname.includes('/api/') || url.search.includes('api')) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
          return response;
        })
        .catch(() => {
          return caches.match(event.request);
        })
    );
    return;
  }

  // Strategy: Cache First for truly static assets (Images, Fonts, WASM)
  const isStaticAsset = 
    url.pathname.endsWith('.png') || 
    url.pathname.endsWith('.jpg') || 
    url.pathname.endsWith('.woff2') || 
    url.pathname.endsWith('.wasm') ||
    url.pathname.includes('/icons/');

  if (isStaticAsset) {
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        if (cachedResponse) return cachedResponse;
        
        return fetch(event.request).then((networkResponse) => {
          if (!networkResponse || networkResponse.status !== 200) {
            return networkResponse;
          }
          const responseToCache = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
          return networkResponse;
        });
      })
    );
    return;
  }

  // Standard Strategy for everything else: Stale-While-Revalidate
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      const fetchPromise = fetch(event.request).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseToCache = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return networkResponse;
      });
      return cachedResponse || fetchPromise;
    })
  );
});

// Push Notifications
self.addEventListener('push', (event) => {
  let data = { title: 'BM BARBER', body: 'Nueva notificación.' };
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data = { title: 'BM BARBER', body: event.data.text() };
    }
  }

  const options = {
    body: data.body,
    icon: '/icons/icon-192.png',
    badge: '/favicon.png',
    vibrate: [100, 50, 100],
    data: {
      url: data.url || '/'
    }
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Notification Click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow(event.notification.data.url)
  );
});

// Handle messages to skip waiting (force new version)
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
