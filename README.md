<p align="center">
  <img src="docs/assets/logo.svg" alt="Immich GeoTagger" width="720">
</p>

<p align="center">
  <strong>GPS for cameras without</strong>
</p>

<p align="center">
  <a href="https://github.com/andreas-aichele/immich-geotagger/releases/latest"><strong>⬇ Download latest release</strong></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/andreas-aichele/immich-geotagger/issues">Report an issue</a>
</p>

<p align="center">
  <sub>Open source · Built for self-hosted Immich · Location history stays on your phone</sub>
</p>

---

**Give photos and videos from cameras without GPS the location they were actually taken at.**

Immich GeoTagger is a small companion app for **Immich**. It was created for people who take photos with a DSLR, mirrorless camera, or any other camera without reliable GPS and still want their photos and videos to appear at the correct places on the Immich map.

Instead of manually assigning locations to photos and videos afterwards, you simply take your phone with you. GeoTagger records where you were and later matches that information with the capture time of your photos and videos. You can choose between a battery-friendly **Balanced** mode for all-day tracking and a more detailed **Precise** mode for dedicated photo trips.

## Get Immich GeoTagger

Ready to try it? Download the latest version from **GitHub Releases**.

### [⬇ Download Immich GeoTagger](https://github.com/andreas-aichele/immich-geotagger/releases/latest)

**Android:** download the APK and install it on your phone. The first-start guide walks you through location access and connecting your Immich server.

> **Note for iPhone users:** iOS builds currently require manual signing and are not yet available as a normal App Store installation.

## Why does this app exist?

Many dedicated cameras create excellent photos but do not save a GPS location. After importing those photos into Immich, the timeline is complete, but the map is not.

Immich GeoTagger fills that gap.

The idea is simple:

**Your camera records the photo. Your phone records where you are. GeoTagger brings both together.**

You do not need to connect your camera to your phone, install anything on the camera, or change the way you import photos.

## How it works

The workflow is intentionally simple — GeoTagger stays out of the way of your normal photography and Immich import process.

1. **Start tracking before taking photos.**  
   GeoTagger records your location in the background while your phone stays in your pocket.

2. **Take photos and videos as usual.**  
   Use your DSLR or mirrorless camera exactly as you normally would.

3. **Import the photos and videos into Immich.**  
   Your normal photo workflow does not change.

> **Important:** Before taking photos, make sure your **camera and phone use the same time and the same time zone**. GeoTagger matches media to your recorded route using the capture timestamp. Even a small clock difference can assign a photo to the wrong place.

4. **Let GeoTagger match the media.**  
   The app compares the capture time of photos and videos without a location with your recorded location history.

5. **Review the proposed matches.**  
   Before anything is changed, GeoTagger shows a preview with Immich thumbnails, capture times, the proposed locations on an interactive **OpenStreetMap** map, and a reliability indicator for each match. You can inspect individual markers, deselect photos, or keep the full selection.

6. **Apply only what you approve.**  
   Only the selected media items receive their calculated position and can then appear correctly on the Immich map.

### What if media was captured between two recorded locations?

Your phone does not need to record GPS every second.

For example, if GeoTagger knows where you were at **10:00** and again at **10:10**, a photo or video captured at **10:05** can be placed between those two positions.

GeoTagger only does this when it has enough information for a safe match. It does not guess a position outside the recorded route, and you can configure how large the gap between location measurements may be.

## Your existing locations are safe

GeoTagger is designed to complement the location data already in your photo library.

**Photos and videos that already have a GPS location are left untouched.**

Only photos and videos without location information are considered for matching.

## Privacy and Google-free tracking

Your location history is stored **on your phone**. You can choose how long GeoTagger should keep it before deleting old points automatically.

On Android, GeoTagger uses the standard **AOSP LocationManager** through the open-source `libre_location` stack. It does **not require Google Play Services** for location tracking and is designed to work on de-Googled Android systems as well. Location previews use **OpenStreetMap** tiles through the open-source `flutter_map` package.

GeoTagger does not require its own cloud service. When a media item is matched, only the calculated location is sent to **your own Immich server**.

## What you need

- an Android phone or iPhone
- your own Immich installation
- an Immich API key
- a camera whose **clock and time zone match your phone**

During the first start, GeoTagger guides you through the required location permission and Immich connection.

## Languages

The app currently supports:

**English · Deutsch · Français · Español · Nederlands**

GeoTagger automatically uses the language configured on your device. Unsupported languages fall back to English.

## F-Droid

The Android codebase is prepared for F-Droid: the application uses a stable package ID, includes localized Fastlane/F-Droid metadata, and does not depend on Google Play Services for location tracking. Submission to the official F-Droid repository is still pending.

## Current status

Immich GeoTagger is a young open-source project and is still being actively developed.

The core workflow is already implemented: recording a location timeline, safely matching photos and videos by capture time, previewing proposed location updates with thumbnails, selecting which media items should be changed, preserving existing GPS data, and applying confirmed locations to Immich.

If you find a problem or have an idea for an improvement, feel free to open an issue.

## Development

For local setup and the shared GitHub/local workflow, see [Platform setup](docs/PLATFORM_SETUP.md).

## License

Immich GeoTagger is open source and available under the **MIT License**.
