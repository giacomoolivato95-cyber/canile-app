// ============================================================
// 🔥 SERVICE WORKER PER LA PWA
// ============================================================
// Questo file gestisce la cache per il funzionamento offline
// e forza l'aggiornamento dell'app quando viene pubblicata
// una nuova versione.

// ============================================================
// 1. INSTALLAZIONE
// ============================================================
// Quando il service worker viene installato, apre la cache
// e salva i file essenziali per il funzionamento offline.

const CACHE_NAME = 'canile-app-v1';
const OFFLINE_URL = '/index.html';

// File da mettere in cache per il funzionamento offline
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  // I file generati da Flutter verranno aggiunti automaticamente
];

self.addEventListener('install', (event) => {
  console.log('📦 Service Worker: installazione...');

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('📦 Service Worker: caching degli assets...');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('✅ Service Worker: installazione completata!');
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('❌ Service Worker: errore durante l\'installazione:', error);
      })
  );
});

// ============================================================
// 2. ATTIVAZIONE
// ============================================================
// Quando il service worker viene attivato, elimina le cache
// vecchie e forza l'aggiornamento della pagina.

self.addEventListener('activate', (event) => {
  console.log('🔥 Service Worker: attivazione...');

  event.waitUntil(
    // 🔥 ELIMINA LE CACHE VECCHIE
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((cacheName) => cacheName !== CACHE_NAME)
          .map((cacheName) => {
            console.log(`🗑️ Service Worker: eliminata cache vecchia: ${cacheName}`);
            return caches.delete(cacheName);
          })
      );
    })
    .then(() => {
      console.log('✅ Service Worker: attivazione completata!');
      // 🔥 FORZA L'AGGIORNAMENTO DELLA PAGINA
      return self.clients.claim();
    })
    .then(() => {
      // 🔥 NOTIFICA TUTTE LE PAGINE APERTE CHE DEVONO AGGIORNARSI
      self.clients.matchAll().then((clients) => {
        clients.forEach((client) => {
          client.postMessage({
            type: 'UPDATE_AVAILABLE',
            message: 'Nuova versione disponibile! Ricarica la pagina.'
          });
        });
      });
    })
  );
});

// ============================================================
// 3. INTERCETTAZIONE DELLE RICHIESTE
// ============================================================
// Quando l'app fa una richiesta (es. una pagina o un file),
// il service worker intercetta la richiesta e risponde con
// la cache (se disponibile) o con la rete.

self.addEventListener('fetch', (event) => {
  // Ignora le richieste verso Supabase e altri domini esterni
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) {
    // Non intercettare le richieste verso domini esterni
    event.respondWith(fetch(event.request));
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then((cachedResponse) => {
        // Se il file è in cache, restituiscilo
        if (cachedResponse) {
          // 🔥 AGGIORNA LA CACHE IN BACKGROUND (stale-while-revalidate)
          fetch(event.request)
            .then((networkResponse) => {
              caches.open(CACHE_NAME)
                .then((cache) => {
                  cache.put(event.request, networkResponse);
                });
            })
            .catch(() => {});
          return cachedResponse;
        }

        // Se il file non è in cache, scaricalo dalla rete
        return fetch(event.request)
          .then((networkResponse) => {
            // Salva la risposta nella cache per la prossima volta
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(event.request, networkResponse.clone());
              });
            return networkResponse;
          })
          .catch(() => {
            // Se la rete non è disponibile e il file non è in cache,
            // restituisci la pagina offline
            if (event.request.mode === 'navigate') {
              return caches.match(OFFLINE_URL);
            }
            return new Response('Offline', {
              status: 503,
              statusText: 'Service Unavailable'
            });
          });
      })
  );
});

// ============================================================
// 4. GESTIONE DEI MESSAGGI DALLA PAGINA
// ============================================================
// Riceve messaggi dalla pagina principale per gestire
// comandi come "salta la cache" o "forza l'aggiornamento".

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('⏩ Service Worker: salta l\'attesa e aggiorna');
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'FORCE_UPDATE') {
    console.log('🔄 Service Worker: forzato aggiornamento cache');
    caches.delete(CACHE_NAME)
      .then(() => {
        console.log('🗑️ Cache eliminata, ricarico...');
        self.skipWaiting();
      });
  }
});

// ============================================================
// 5. GESTIONE DEGLI ERRORI
// ============================================================
console.log('✅ Service Worker caricato correttamente!');
