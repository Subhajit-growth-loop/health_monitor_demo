# Health Monitor

An **offline-first** health tracking app built with **Flutter + Riverpod** in a
**Clean Architecture**, implementing the design in
`Health_Monitor_App_Architecture.docx`.

The local database is the single source of truth for the UI — every screen
reads from it and never blocks on the network. Synchronization to the backend
runs as an independent, resilient background process.

## Architecture

The five layers from the design doc map onto the code like this:

| Doc layer            | Where it lives                                                                 |
|----------------------|-------------------------------------------------------------------------------|
| 1. Acquisition       | `data/datasources/platform/` — the **Unified Access Layer** (`HealthPlatformDataSource`) |
| 2. Normalization     | Platform source maps raw samples → `HealthRecordModel` + de-duplication        |
| 3. Local Persistence | `data/datasources/local/` — SQLite (`HealthLocalDataSource`), the source of truth |
| 4. Presentation      | `presentation/` — Riverpod providers, dashboard & detail screens, charts       |
| 5. Synchronization   | `data/repositories/` + `presentation/providers/sync_controller.dart`           |

```
lib/
├── core/                         # theme, connectivity, db bootstrap, formatters
└── features/health/
    ├── domain/                   # entities, repository contract (no Flutter/SQL here)
    ├── data/                     # datasources, models, repository implementation
    └── presentation/            # providers (Riverpod), screens, widgets
```

Dependencies point inward: `presentation → domain ← data`. The presentation
layer only knows the `HealthRepository` interface.

## How the design doc is implemented

- **Offline-first** — UI reads only from local SQLite; works with no network.
- **Pending-sync queue** — new records are written with `sync_status = pending`;
  the DB is a durable outbound queue.
- **Idempotent sync** — stable ids (`type + timestamp + source`) mean re-uploading
  never duplicates (`INSERT OR IGNORE` locally, id-keyed store on the backend).
- **Incremental sync** — only pending records are uploaded.
- **De-duplication** — overlapping samples from multiple sources collapse at the
  normalization layer (type + timestamp window).
- **Resilient sync** — batched uploads with backoff, triggered by connectivity
  change, foreground, and a periodic interval (no single point of failure).
- **Graceful permissions** — per-data-type grant state; the app degrades per
  metric rather than failing wholesale.
- **Backfill** — first read is capped/recent-first to show data immediately.

## Platform source: real vs simulated

Two implementations sit behind the same `HealthPlatformDataSource` interface:

- **`RealHealthPlatformDataSource`** — reads real data via the `health` package
  (Apple HealthKit on iOS, Google Health Connect on Android). Used automatically
  on physical iOS/Android devices.
- **`SimulatedHealthPlatformDataSource`** — generates realistic multi-source
  samples. Used on desktop/web, and on simulators/emulators (no HealthKit /
  Health Connect data there).

Selection happens in `platformDataSourceProvider`. To force the simulator on a
real device (e.g. for a demo), set `kForceSimulatedHealth = true` in
`lib/features/health/presentation/providers/health_providers.dart`.

## Backend (dummy HTTP endpoint)

`HttpHealthRemoteDataSource` performs **real network round-trips** against a
placeholder API (`jsonplaceholder.typicode.com`) so the offline→online sync is
genuine. It POSTs pending records as JSON (idempotent by stable id) and treats
any 2xx as a durable write acknowledgement.

To point it at your real backend later, change `baseUrl` / paths / auth in
`http_health_remote_datasource.dart` (and uncomment the `fromJson` mapping in
`fetchUpdatesSince`) — the repository, sync controller and UI stay untouched.
An `InMemoryHealthRemoteDataSource` is also kept for offline/local use.

## Testing on a real device

### iOS (physical iPhone — HealthKit)
1. Native config is already wired: HealthKit entitlement
   (`ios/Runner/Runner.entitlements`), usage strings in `Info.plist`, iOS
   deployment target 14.0.
2. Open `ios/Runner.xcworkspace` in Xcode once → select the **Runner** target →
   **Signing & Capabilities** → make sure your **Team** is selected and the
   **HealthKit** capability is present (add it if missing). This registers
   HealthKit on your App ID.
3. `flutter run -d <your-iphone>`
4. On first launch, grant the requested health categories in the system dialog.
   Data appears from the iPhone + any paired Apple Watch.
   > HealthKit returns nothing on the iOS **simulator** — use a real iPhone with
   > some Health data (walk around, or add samples in the Health app).

### Android (physical device — Health Connect)
1. Native config is already wired: `minSdk 26`, Health Connect read permissions,
   permission-rationale intent filters, and `MainActivity : FlutterFragmentActivity`.
2. Install **Health Connect** from the Play Store if it isn't built in (Android
   13 and below). The app detects its absence and opens the Play Store listing.
3. `flutter run -d <your-android>`
4. Grant the requested data types in the Health Connect permission screen. Make
   sure Health Connect actually has data (connect a wearable or a fitness app).

## Running

```bash
flutter pub get
flutter run          # iOS simulator, Android emulator, or a device
flutter test         # end-to-end pipeline tests (run on the FFI SQLite backend)
flutter analyze
```

There is **no login** — a splash screen initializes data, then routes straight
to the dashboard.

## Tech

Riverpod · sqflite · fl_chart · connectivity_plus · flutter_screenutil (responsive) · intl
