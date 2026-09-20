from pathlib import Path


def configure_android() -> None:
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not manifest.exists():
        return

    manifest_text = manifest.read_text()
    permissions = """<uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    """
    if "android.permission.ACCESS_BACKGROUND_LOCATION" not in manifest_text:
        manifest_text = manifest_text.replace(
            "<application",
            permissions + "<application",
            1,
        )
        manifest.write_text(manifest_text)

    manifest_text = manifest.read_text()
    manifest_text = manifest_text.replace(
        'android:label="immich_geotagger"',
        'android:label="Immich GeoTagger"',
    )
    manifest_text = manifest_text.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@drawable/ic_launcher_geotagger"',
    )
    manifest_text = manifest_text.replace(
        'android:roundIcon="@mipmap/ic_launcher_round"',
        'android:roundIcon="@drawable/ic_launcher_geotagger"',
    )
    manifest.write_text(manifest_text)

    drawable = Path("android/app/src/main/res/drawable")
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "ic_launcher_geotagger.xml").write_text("""<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#5757D9"
        android:pathData="M18,0h72a18,18 0,0 1,18 18v72a18,18 0,0 1,-18 18h-72a18,18 0,0 1,-18 -18v-72a18,18 0,0 1,18 -18z" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M54,19c-13.3,0 -24,10.7 -24,24 0,18 24,46 24,46s24,-28 24,-46c0,-13.3 -10.7,-24 -24,-24z" />
    <path
        android:fillColor="#5757D9"
        android:pathData="M54,33a10,10 0,1 0,0 20a10,10 0,1 0,0 -20z" />
    <path
        android:fillColor="#CFCFFD"
        android:pathData="M27,73l14,-14 11,10 8,-7 21,20H27z" />
</vector>
""")


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


configure_android()
configure_ios()
print("Available platform permissions configured.")
