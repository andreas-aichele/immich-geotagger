from pathlib import Path


def patch_kotlin_dsl() -> bool:
    path = Path("android/app/build.gradle.kts")
    if not path.exists():
        return False

    text = path.read_text()
    if 'keystoreProperties' in text:
        return True

    header = '''import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

'''
    text = header + text

    android_marker = "android {"
    signing_block = '''android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
'''
    text = text.replace(android_marker, signing_block, 1)

    debug_line = 'signingConfig = signingConfigs.getByName("debug")'
    release_line = '''signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }'''
    if debug_line not in text:
        raise RuntimeError("Could not find Flutter template signingConfig")
    text = text.replace(debug_line, release_line, 1)
    path.write_text(text)
    return True


def patch_groovy() -> bool:
    path = Path("android/app/build.gradle")
    if not path.exists():
        return False

    text = path.read_text()
    if "keystoreProperties" in text:
        return True

    header = '''def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

'''
    text = header + text
    text = text.replace(
        "android {",
        """android {
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
""",
        1,
    )
    text = text.replace(
        "signingConfig signingConfigs.debug",
        "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug",
        1,
    )
    path.write_text(text)
    return True


if not (patch_kotlin_dsl() or patch_groovy()):
    raise RuntimeError("No Android Gradle app build file found")

print("Android signing configuration patched.")
