# My Latest Artifacts

Cross-platform dashboard for viewing the newest build artifact from each project.

## Build 0.2.2

- Retains the platform-selection UI and saved settings from v0.2.1.
- Updates platform package names to the agreed format: `My_Latest_Artifacts_Androidv0.2.2.apk`, `My_Latest_Artifacts_Windowsv0.2.2.zip`, `My_Latest_Artifacts_Linuxv0.2.2.tar.gz`, and `My_Latest_Artifacts_iOSv0.2.2.zip`.
- Provides a combined archive named `My_Latest_Artifacts_v0.2.2.zip`.

## Important implementation status

This build is an intermediate UI and settings build. The selected platform list is saved, but provider authentication, automatic project discovery, latest-artifact retrieval, date sorting, and confirmed-download flow are not connected yet. These require separate provider API and authentication implementations. Do not treat the platform selection screen as proof that artifact retrieval is already working.

## Build outputs

GitHub Actions prepares platform-specific packages and collects them in `My_Latest_Artifacts_v0.2.2.zip`.

- Android: release APK.
- Windows x64: ZIP containing the executable and required Flutter runtime files.
- Linux x64: portable application bundle in a tar.gz archive.
- iOS: unsigned simulator app bundle ZIP. It is not an installable iPhone IPA.

## Windows security note

The Windows executable is currently not Authenticode-signed. Windows or browser reputation checks may still show warnings for an unsigned or newly published executable. Rebuilding alone cannot guarantee that SmartScreen or Chrome Safe Browsing warnings disappear. Keep Windows and browser security protections enabled; a trusted code-signing certificate and signed release are needed to establish publisher reputation.

## Local development

Install the Flutter stable SDK, then run:

```sh
flutter pub get
flutter run
```
