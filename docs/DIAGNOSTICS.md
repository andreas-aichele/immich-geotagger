# Application diagnostics (Android)

Logging is active at INFO by default. In Settings → About the app, tap the
build number seven times (no more than three seconds between taps) to reveal
Developer options. The unlocked state survives restarts. Hiding the options
restores enabled INFO logging.

Options: enable/disable logging, ERROR/WARN/INFO/DEBUG/TRACE, total log storage
of 5/10/20 MiB (10 by default), share a ZIP, save a ZIP, and delete logs.
Changing to a smaller budget immediately removes oversized retained files.
Deletion also removes temporary ZIP exports. Logging continues afterwards.

The Android plugin is registered in both the UI engine and libre_location's
headless engine. A single native worker writes five files, each limited to
one fifth of the configured total (5 × 2 MiB by default). A synchronized store
and OS file lock cover writing, rotation, configuration, deletion and snapshot
export. Each write closes and syncs the file. Logs live in private no-backup
storage, survive app restarts, and disappear on uninstall or clearing app data.
The ZIP contains app.log, up to four rotated files, and diagnostics.json.
All sources share these files and have app/flutter/tracking/immich/sync/android
labels. No external logging service is used.

INFO includes startup, tracking start/stop, synchronization counts and native
memory pressure. WARN includes API failures and available previous process exit
reason codes on Android 11+. DEBUG includes GPS accuracy, API latency/status
and unmatched-photo reasons. TRACE adds GPS coordinates and timestamps.
Flutter framework and uncaught asynchronous errors, handled tracking/sync
failures, and native Java/Kotlin uncaught exceptions record their type and
stack frames. Exception messages, causes, API bodies, asset IDs and EXIF are
excluded. Native redaction also strips URLs and common credential fields.
Export metadata includes app/build/Android versions, logging settings, battery
mode and location permission. It excludes connection credentials and device IDs.

TRACE requires confirmation. A persisted flag marks potentially sensitive logs
until deletion, even after switching back to INFO; exporting then shows a
coordinate warning. Review a ZIP before sending it to someone else. Files are
shared only after the user explicitly selects an export action.

## Limitations

An abrupt kill, native signal crash, ANR or loss of power can prevent a final
entry. The next start records available Android exit information (reason,
status, importance, timestamp), not raw ANR/native crash traces. The existing
platform error handlers are preserved. Plugin-internal GPS provider decisions
are not captured by this logger; the app records callbacks, permissions,
capture failures and tracking operations at its own integration boundary.
Diagnostic logging is Android-only for now. Other platforms keep working with
no-op logging and do not show the diagnostic controls. The log viewer is deferred.

## Validation

`flutter analyze` and `flutter test` cover Dart integration and the bridge.
`flutter build apk --debug` checks Android registration and compilation.
`cd android && ./gradlew :diagnostic_logger:testDebugUnitTest` checks rotation,
byte limits, concurrent writes, snapshot ZIP contents, shrinking and deletion.
These checks also run in Flutter CI. Device checks should cover UI and headless
tracking, killing/reopening the app, seven-tap unlock persistence, TRACE
confirmation, sharing/saving, and deletion while tracking.
