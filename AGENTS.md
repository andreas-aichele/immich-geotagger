# AGENTS.md

## Dependency maintenance

Dependencies must be reviewed regularly and kept up to date in a controlled manner.

- Check Flutter/Dart packages for newer stable releases as part of ongoing maintenance and before preparing releases.
- Apply compatible patch and minor updates when they are low-risk and covered by the existing test suite.
- Treat security-relevant dependency updates as high priority and update them promptly unless there is a documented compatibility blocker.
- Review changelogs and migration notes before applying major-version updates or updates with breaking changes.
- Perform major dependency upgrades separately from unrelated feature work whenever practical.
- After dependency changes, run at least:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
- Do not merge dependency updates when analysis or tests fail because of the update.
- If an update cannot be applied, document the reason, affected package/version, and any known security implications.
- Keep the minimum supported Dart and Flutter versions in `pubspec.yaml` aligned with the actual requirements of the selected dependencies.
- Prefer current, maintained packages over outdated alternatives when introducing new dependencies.
