from pathlib import Path


def configure_ios() -> None:
    plist = Path("ios/Runner/Info.plist")
    if not plist.exists():
        return

    plist_text = plist.read_text()
    ios_keys = """	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Immich GeoTagger records your location to geotag photos from an external camera.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>Immich GeoTagger records location in the background while a photo trip is active.</string>
	<key>UIBackgroundModes</key>
	<array>
		<string>location</string>
	</array>
"""
    if "NSLocationAlwaysAndWhenInUseUsageDescription" not in plist_text:
        plist_text = plist_text.replace("</dict>", ios_keys + "</dict>", 1)

    plist_text = plist_text.replace(
        "<string>immich_geotagger</string>",
        "<string>Immich GeoTagger</string>",
    )
    plist.write_text(plist_text)


# Android configuration is version controlled; only iOS is generated.
configure_ios()
print("Available platform permissions configured.")
