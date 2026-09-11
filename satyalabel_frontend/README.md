# SatyaLabel — Flutter Frontend

Mobile client for the SatyaLabel backend (Legal Metrology (Packaged Commodities)
Rules, 2011 label compliance scanner). Flutter 3.32 / Dart 3.8, Android + iOS.

## Features

- **Citizen Mode** — anonymous camera scanning with an explainable verdict
  (COMPLIANT / NON-COMPLIANT / NEEDS VERIFICATION), violations with their rule
  citations, per-field extraction with confidence, and PDF evidence-report
  download/share.
- **Inspector Mode** — JWT login (`/api/v1/auth/login`); raid **batch scanning**
  under a `session_id`; per-session verdict statistics and history
  (`GET /api/v1/scans/?session_id=...`); badge-carrying PDF reports.
- **Offline queue** — captures taken while the backend is unreachable are stored
  on disk and auto-synced via the synchronous scan endpoint when connectivity
  returns (connectivity change listener + 30 s health poll).
- **Scan history** — locally remembered scan ids, re-fetched on demand with
  per-item loading/error states.
- Configurable backend URL (Android emulator defaults to `http://10.0.2.2:8000`).

## Project layout

```
lib/
├── core/
│   ├── api_client.dart      # typed HTTP client for every backend endpoint
│   └── session_store.dart   # SharedPreferences-backed auth/config/history
├── models/                  # DTOs mirroring backend Pydantic schemas
├── services/
│   ├── offline_queue.dart   # disk-backed offline scan queue + sync
│   └── location_service.dart# best-effort GPS for scan evidence
├── state/app_state.dart     # ChangeNotifier: auth, connectivity, queue orchestration
└── ui/
    ├── home_screen.dart
    ├── auth/login_screen.dart
    ├── scan/camera_screen.dart        # capture → submit / queue
    ├── scan/scan_result_screen.dart   # verdict, citations, PDF
    ├── batch/batch_sessions_screen.dart # inspector raid sessions
    ├── history/history_screen.dart
    └── widgets.dart / theme.dart
```

## Running

```bash
flutter pub get
flutter run          # device/emulator connected; backend must be reachable
```

Backend URL: change it in-app via the toolbar settings icon. Use
`http://10.0.2.2:8000` for the Android emulator, or your machine's LAN IP for
a physical device. Restart the app after changing it.

Start the backend first (from `../satyalabel_backend`):

```bash
docker compose up -d
```

## Tests

```bash
flutter test        # 29 tests: models, API client (mocked HTTP), offline queue, widgets
flutter analyze     # clean
```

## Notes

- Camera images above ~9 MB are re-encoded (reduced-width PNG) to stay under
  the backend's 10 MB limit.
- Inspector/admin accounts are provisioned server-side (bootstrap admin env);
  the app offers citizen self-registration only.
- Android dev builds allow cleartext HTTP to talk to a local backend; remove
  `usesCleartextTraffic` for production TLS deployments.
