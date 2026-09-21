from pathlib import Path


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


# Android configuration is version controlled; only iOS is generated.
configure_ios()
print("Available platform permissions and background services configured.")
