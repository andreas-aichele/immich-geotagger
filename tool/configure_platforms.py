from pathlib import Path


def replace_once(path: str, needle: str, replacement: str) -> None:
    file = Path(path)
    text = file.read_text()
    if needle not in text:
        raise RuntimeError(f"Could not find expected text in {path}: {needle!r}")
    file.write_text(text.replace(needle, replacement, 1))


manifest = Path("android/app/src/main/AndroidManifest.xml")
manifest_text = manifest.read_text()
permissions = """<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

    """
if "android.permission.ACCESS_BACKGROUND_LOCATION" not in manifest_text:
    manifest_text = manifest_text.replace("<application", permissions + "<application", 1)
    manifest.write_text(manifest_text)

plist = Path("ios/Runner/Info.plist")
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
    plist.write_text(plist_text)

print("Platform permissions configured.")
