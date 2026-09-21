# F-Droid submission

The release candidate for the official F-Droid repository is **v1.0.1**.

## fdroiddata metadata

The file to submit to F-Droid is:

```text
metadata/io.github.andreasaichele.immichgeotagger.yml
```

A ready-to-copy version is stored in this repository at:

```text
docs/fdroiddata/metadata/io.github.andreasaichele.immichgeotagger.yml
```

## Submission steps

1. Fork `https://gitlab.com/fdroid/fdroiddata` on GitLab.
2. Create a branch such as `io.github.andreasaichele.immichgeotagger`.
3. Copy the metadata file from this repository to `metadata/io.github.andreasaichele.immichgeotagger.yml` in the fdroiddata fork.
4. Run the fdroidserver metadata/build checks if available locally.
5. Open a merge request against `fdroid/fdroiddata:master`.
6. In the merge request, mention that Andreas is the upstream author and explicitly approves inclusion in F-Droid.

## Release details

- Application ID: `io.github.andreasaichele.immichgeotagger`
- Version: `1.0.1`
- Version code: `1000001`
- Tag: `v1.0.1`
- Flutter: `3.47.5`
- License: MIT
- Google Play Services: not required
- Location provider: AOSP LocationManager via `libre_location`
- Map rendering: MapLibre/OpenFreeMap

## Upstream metadata

Localized Fastlane metadata and changelogs are included for:

- English
- German
- French
- Spanish
- Dutch

Store graphics are included upstream in the Fastlane metadata:

```text
fastlane/metadata/android/en-US/images/icon.png
fastlane/metadata/android/en-US/images/phoneScreenshots/1.jpg
fastlane/metadata/android/en-US/images/phoneScreenshots/2.jpg
```

`en-US` is F-Droid's fallback locale, so these graphics are available even when a localized text description is selected. The current screenshots show the active tracking dashboard and the location review workflow before photos are updated.
