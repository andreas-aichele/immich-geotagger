from pathlib import Path


def configure_ios() -> None:
    plist = Path("ios/Runner/Info.plist")
    if not plist.exists():
        return

    text = plist.read_text()

    ios_keys = """\t<key>NSLocationWhenInUseUsageDescription</key>
\t<string>Immich GeoTagger records your location to geotag photos from an external camera.</string>
\t<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
\t<string>Immich GeoTagger records location in the background while a photo trip is active.</string>
\t<key>NSMotionUsageDescription</key>
\t<string>Immich GeoTagger uses motion information to make background location tracking more efficient.</string>
\t<key>UIBackgroundModes</key>
\t<array>
\t\t<string>location</string>
\t\t<string>fetch</string>
\t</array>
\t<key>BGTaskSchedulerPermittedIdentifiers</key>
\t<array>
\t\t<string>io.rezivure.libre_location.heartbeat</string>
\t</array>
"""

    if "NSLocationAlwaysAndWhenInUseUsageDescription" not in text:
        text = text.replace("</dict>", ios_keys + "</dict>", 1)

    text = text.replace(
        "<string>immich_geotagger</string>",
        "<string>Immich GeoTagger</string>",
    )
    plist.write_text(text)


# Android configuration is version controlled; iOS runner is generated in CI.
configure_ios()
print("Platform permissions and background tracking settings configured.")
