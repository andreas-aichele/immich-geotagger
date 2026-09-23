# Branding

Immich GeoTagger uses the **Lens Pin** mark as its canonical visual identity.

## Canonical assets

- `docs/assets/icon.svg` — canonical standalone Lens Pin artwork.
- `docs/assets/logo.svg` — horizontal project logo using the same artwork.
- `android/app/src/main/res/drawable/ic_launcher_geotagger.xml` — Android vector adaptation.

Do not replace the Lens Pin with a generic Material location icon in branded surfaces. Functional location/map actions may continue to use standard Material icons.

## Sizes

| Surface | Size |
| --- | ---: |
| In-app header / onboarding brand mark | 44 dp |
| Android launcher vector viewport | 108 × 108 dp |
| Android splash mark | launcher drawable at intrinsic 108 dp |
| README logo icon tile | 180 × 180 units inside the 900 × 220 wordmark |

## Brand palette

| Role | Color |
| --- | --- |
| Blue | `#1E83F7` |
| Teal | `#13B8A6` |
| Coral | `#FF5269` |
| Yellow | `#FFBE2E` |
| Navy / lens | `#25284A` |
| App background | `#FAFBFD` |
| Text | `#2B2E46` |
| Muted text | `#6C7085` |

Blue is the primary action color. Teal is used for positive/location-related states, coral for attention/low-confidence accents, and yellow for camera/time accents. The four main colors should appear together only in the Lens Pin mark; normal UI surfaces stay restrained and use the corresponding soft tints.


## Store artwork

Store screenshots and the previous Fastlane PNG were removed from the branding branch because they showed the old icon/UI. They should be regenerated from a build of this branch after the branding is approved, so the store never contains a visually different Lens Pin.
