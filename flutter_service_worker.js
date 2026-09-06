'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "edc13cfb1c377ec7c439d66d1486c329",
"version.json": "4aca11a9b2ba9208d10a2ff2b5e820b3",
"index.html": "b7b932465923ef67405ae0cb74c1dcf4",
"/": "b7b932465923ef67405ae0cb74c1dcf4",
"main.dart.js": "1a69e2bd6d254dde43fe3e7656ab6167",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "f1e1da22cdbb9a1090588f3d50b0fe07",
"assets/AssetManifest.json": "458925bfc7dad78aabfe1ef6f283eeaa",
"assets/NOTICES": "c27235a5982a780fd74797f371bdd1af",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/AssetManifest.bin.json": "0018b59894895218dc6705aa4e763e45",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "188df09aba5ccab256ce8a6b1945b1e5",
"assets/fonts/MaterialIcons-Regular.otf": "2eb96450f0358f5c5f45592599f1c6a7",
"assets/assets/exercises/front-raise.mp4": "b024394c59abc2e34fb5ee18cd1fa60c",
"assets/assets/exercises/leg-extension.mp4": "6f82d6ae1a8f86ed076d7ac197124929",
"assets/assets/exercises/rope-tricep-pushdown.mp4": "997eac5653fa30b64f45d561217eea2c",
"assets/assets/exercises/upright-row.mp4": "84b8e5e89ab5790371360750a9b25e2e",
"assets/assets/exercises/dumbbell-shoulder-press.mp4": "7847393a68f81a393b27e05d0e40cf9d",
"assets/assets/exercises/leg-press.mp4": "feae5ecba2453527e1b1e44dbbed16c5",
"assets/assets/exercises/machine-shoulder-press.mp4": "cab01b2f52bde64e64d6cf256991fcf9",
"assets/assets/exercises/rear-delt-fly.mp4": "7ab53db0ec4482181206e502a3392b31",
"assets/assets/exercises/hack-squat.mp4": "b177d8ae1237311fc292b35fdda05313",
"assets/assets/exercises/seated-leg-curl.mp4": "59f7d5406b791ad540a0f15e631bf086",
"assets/assets/exercises/machine-lateral-raise.mp4": "56d9df17d259ea36c2a592b385b02071",
"assets/assets/exercises/hip-thrust.mp4": "84de370ee4a6d0fb9bc62ea3a53d4b6b",
"assets/assets/exercises/goblet-squat.mp4": "87e77a935eed9c1a1926e8ae1655643c",
"assets/assets/exercises/front-squat.mp4": "a6b360d6e0c4122568b40281896f4b1f",
"assets/assets/exercises/bulgarian-split-squat.mp4": "3a26987b5c1819cc4dcb6f2d331b8063",
"assets/assets/exercises/lying-leg-curl.mp4": "04c90579672c1d91544eecde804e63cb",
"assets/assets/exercises/walking-step-up.mp4": "4f516004c5cb6238f3c3246b17bc8922",
"assets/assets/exercises/arnold-press.mp4": "f6b314a9e5601f1caa14e3f7246fb7e1",
"assets/assets/exercises/overhead-press.mp4": "d6488eb5ef8685d184eb7f7156635f0b",
"assets/assets/exercises/cable-lateral-raise.mp4": "15d8b4cec8ae99d1d0e7fb8d08e53d8a",
"assets/assets/exercises/machine-hip-abduction.mp4": "0c0b45da3709ae94d635172d8e790475",
"assets/assets/exercises/dumbbell-lateral-raise.mp4": "8528e5ed7aedcdd0b98c2e94e92e09d4",
"assets/assets/exercises/barbell-squat.mp4": "045456830df32f26de4ffb0e87db34a8",
"assets/assets/exercises/pec-deck-fly.mp4": "9c85ffab26ed4fc08c1f56926b559d41",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
