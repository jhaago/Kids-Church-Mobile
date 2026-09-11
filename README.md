# Kids Church Mobile

Shared Flutter client for Android and iOS. It uses the versioned JSON API in [`jhaago/kids-church-app`](https://github.com/jhaago/kids-church-app) and never accesses Google Sheets directly.

## Current vertical slice

- Runtime-configurable Apps Script `/exec` URL with health check
- Volunteer login using the existing Kids Church accounts
- auth token stored in platform secure storage
- active service selection by stable `SessionID`
- privacy-limited child attendance list and search
- child details fetched only when opened
- immediate attendance feedback with an encrypted durable retry queue
- queue isolation by authenticated volunteer, service and date
- refresh/reconnect reconciliation with server truth
- visible pending/sync/failure state

The existing Apps Script web application remains operational and is the source of all server-side permission, session and Sheet rules.

## Build

Install the current stable Flutter SDK, then run:

```sh
./tool/bootstrap_platforms.sh
flutter run
```

The platform runner folders are generated from Flutter's standard templates. GitHub Actions performs the same generation, runs formatting, analysis and tests, and uploads a debug Android APK. The iOS compile can be run manually from the workflow and does not perform code signing.

Alternatively, preconfigure a test API URL at build time:

```sh
flutter run --dart-define=KC_API_URL=https://script.google.com/macros/s/DEPLOYMENT_ID/exec
```

Do not commit a production password, session token, signing key or Apple/Google credential. The API URL itself is not a secret.

## Test sequence

Use a copied spreadsheet and a test Apps Script deployment first:

1. Enter the test `/exec` URL and verify connection.
2. Sign in with a test volunteer account.
3. Select an active service and mark attendance.
4. Double-tap a child and confirm only the final state is stored.
5. Disable networking, mark several children, and confirm they show as pending.
6. Reconnect and verify the queue clears and the Sheet matches the screen.
7. Close or change the service while a device is stale and verify writes are blocked.
8. Use two devices on the same service and refresh both to verify reconciliation.

