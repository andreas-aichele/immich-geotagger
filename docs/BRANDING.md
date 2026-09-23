# Branding

Immich GeoTagger uses the **Lens Pin** mark as its canonical visual identity.

## Canonical assets

- `assets/branding/app_icon.png` — canonical full-bleed app icon with background to the edges.
- `assets/branding/brand_mark.png` — canonical transparent in-app mark.
- `android/app/src/main/res/drawable-nodpi/app_icon.png` — Android launcher artwork.
- `android/app/src/main/res/drawable-nodpi/brand_mark.png` — Android splash mark.
- `fastlane/metadata/android/en-US/images/icon.png` — store / F-Droid icon.
- `docs/assets/app_icon.png` — README/project artwork.

Do not maintain a separate hand-drawn SVG version. All branded surfaces must use one of the two approved PNG masters.

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

Store screenshots should be regenerated from a build of this branch after the branding is approved, so the store screenshots match the final UI and icon.