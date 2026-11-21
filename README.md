# My Latest Artifacts

Cross-platform dashboard for viewing the newest build artifact from each project.

## Build 0.2.0

- Added a checkbox selection dialog for GitHub, GitLab, Bitbucket, Azure DevOps, and Jenkins.
- Saves the selected platforms and restores them on the next launch.
- Removed the empty-state "첫 프로젝트 추가" button; the persistent action is "+ 프로젝트 추가".
- Shows the supplied app icon before the home-screen title and in the About dialog.
- Includes the collaboration logo and exact credit "Ryoo jaesang & 최피디".
- Generates a Windows `.ico` resource from the supplied app icon before building.
- Keeps diagnostic logging with a 1 MB rotation cap.

## Important implementation status

This build is an intermediate UI and settings build. The selected platform list is saved, but provider authentication, automatic project discovery, latest-artifact retrieval, date sorting, and confirmed-download flow are not connected yet. These require separate provider API and authentication implementations. Do not treat the platform selection screen as proof that artifact retrieval is already working.

## Build outputs

GitHub Actions prepares platform-specific packages and collects them in `My_Latest_Artifacts_v0.2.0.zip`.

- Android: release APK.
- Windows x64: ZIP containing the executable and required Flutter runtime files.
- Linux x64: portable application bundle in a tar.gz archive.
- iOS: unsigned simulator app bundle ZIP. It is not an installable iPhone IPA.

## Local development

Install the Flutter stable SDK, then run:

```sh
flutter pub get
flutter run
```
