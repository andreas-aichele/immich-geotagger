from pathlib import Path


ANDROID_PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    "android.permission.WAKE_LOCK",
    "android.permission.RECEIVE_BOOT_COMPLETED",
]


def configure_android() -> None:
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not manifest.exists():
        return

    text = manifest.read_text()

    missing = [
        permission
        for permission in ANDROID_PERMISSIONS
        if permission not in text
    ]
    if missing:
        permission_xml = "".join(
            f'<uses-permission android:name="{permission}" />\n    '
            for permission in missing
        )
        text = text.replace("<application", permission_xml + "<application", 1)

    text = text.replace(
        'android:label="immich_geotagger"',
        'android:label="Immich GeoTagger"',
    )
    text = text.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@drawable/ic_launcher_geotagger"',
    )
    text = text.replace(
        'android:roundIcon="@mipmap/ic_launcher_round"',
        'android:roundIcon="@drawable/ic_launcher_geotagger"',
    )

    if "upendra.bajpai.background_locator_neo.IsolateHolderService" not in text:
        components = """
        <service
            android:name="upendra.bajpai.background_locator_neo.IsolateHolderService"
            android:permission="android.permission.FOREGROUND_SERVICE"
            android:exported="true"
            android:foregroundServiceType="location" />

        <receiver
            android:name="upendra.bajpai.background_locator_neo.BootBroadcastReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>

"""
        text = text.replace("</application>", components + "    </application>", 1)

    manifest.write_text(text)

    drawable = Path("android/app/src/main/res/drawable")
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "ic_launcher_geotagger.xml").write_text("""<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#1E83F7"
        android:pathData="M18,0h72a18,18 0,0 1,18 18v72a18,18 0,0 1,-18 18h-72a18,18 0,0 1,-18 -18v-72a18,18 0,0 1,18 -18z" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M54,19c-13.3,0 -24,10.7 -24,24 0,18 24,46 24,46s24,-28 24,-46c0,-13.3 -10.7,-24 -24,-24z" />
    <path
        android:fillColor="#1E83F7"
        android:pathData="M54,33a10,10 0,1 0,0 20a10,10 0,1 0,0 -20z" />
    <path
        android:fillColor="#D7EAFE"
        android:pathData="M27,73l14,-14 11,10 8,-7 21,20H27z" />
</vector>
""")


def configure_ios() -> None:
    plist = Path("ios/Runner/Info.plist")
    if plist.exists():
        text = plist.read_text()
        ios_keys = """\t<key>NSLocationWhenInUseUsageDescription</key>
\t<string>Immich GeoTagger records your location to geotag photos from an external camera.</string>
\t<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
\t<string>Immich GeoTagger records location in the background while a photo trip is active.</string>
\t<key>UIBackgroundModes</key>
\t<array>
\t\t<string>location</string>
\t</array>
"""
        if "NSLocationAlwaysAndWhenInUseUsageDescription" not in text:
            text = text.replace("</dict>", ios_keys + "</dict>", 1)

        text = text.replace(
            "<string>immich_geotagger</string>",
            "<string>Immich GeoTagger</string>",
        )
        plist.write_text(text)

    app_delegate = Path("ios/Runner/AppDelegate.swift")
    if not app_delegate.exists():
        return

    text = app_delegate.read_text()
    if "import background_locator_neo" not in text:
        text = text.replace(
            "import Flutter",
            "import Flutter\nimport background_locator_neo",
            1,
        )

    callback = """    BackgroundLocatorPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

"""
    if "BackgroundLocatorPlugin.setPluginRegistrantCallback" not in text:
        marker = "    return super.application(application, didFinishLaunchingWithOptions: launchOptions)"
        text = text.replace(marker, callback + marker, 1)

    app_delegate.write_text(text)


configure_android()
configure_ios()
print("Available platform permissions and background services configured.")
