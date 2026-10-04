# AGENTS.md

## Release versioning

Use Semantic Versioning (`MAJOR.MINOR.PATCH`) for all future releases. Choose the bump from all changes since the previous release, not from the size of the diff or the amount of implementation work.

- **MAJOR**: incompatible changes to supported interfaces, stored data, or existing user workflows that require migration or break compatibility.
- **MINOR**: backward-compatible new features or substantial new capabilities in existing workflows, including new user-facing actions, settings, exports, and update notifications.
- **PATCH**: backward-compatible bug fixes, maintenance, refactoring, or purely cosmetic UI adjustments that add no new functionality.
- For mixed releases, use the highest required bump. Reset PATCH to zero for a MINOR bump, and reset MINOR and PATCH to zero for a MAJOR bump.
- Before preparing a release, review the complete changelog, explicitly state the chosen bump and its reason in the release preparation PR, and keep `pubspec.yaml`, the release tag, and release notes consistent. Continue increasing the Android build/version code independently.
- Keep already published versions and tags unchanged. Apply this policy starting with the next release: new functionality after v1.0.9 should normally be released as v1.1.0, while a fixes-only release would be v1.0.10.

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
