# My Latest Artifacts

Cross-platform dashboard for viewing the newest build artifact from each project.

## First build: 0.1.0

- Flutter application shell for Android, iOS, Windows x64, and Linux x64.
- Stores the project entries entered in the app locally.
- Includes the app information screen and the supplied collaboration logo.
- Writes diagnostic logs locally, with a 1 MB size cap and no intentional collection of credentials.
- The first build is a UI and installation prototype. Provider API connections, automatic latest-artifact discovery, and artifact downloading are not implemented yet.

## Build outputs

GitHub Actions prepares platform-specific packages and collects them in `My_Latest_Artifacts_v0.1.0.zip`.

- Android: release APK.
- Windows x64: ZIP containing the executable and required Flutter runtime files.
- Linux x64: portable application bundle in a tar.gz archive.
- iOS: unsigned app bundle ZIP. A signed IPA requires Apple signing credentials and a distribution profile; this unsigned package cannot be installed directly on a physical iPhone.

## Local development

Install the Flutter stable SDK, then run:

```sh
flutter pub get
flutter run
```

The app icon source is `my latest artifacts icon.jpg`; the About screen uses `js_logo.png`.
