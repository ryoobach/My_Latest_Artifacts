# My Latest Artifacts

Cross-platform dashboard for viewing the newest build artifact from each project.

## Build 0.2.5

- Restores the original project dashboard as the app's initial screen. No login page appears at startup.
- The floating action button is labeled **새 프로젝트** and opens a checkbox list of popular development platforms: GitHub, GitLab, Bitbucket, Azure DevOps, Jenkins, SourceForge, Gitea, and Codeberg.
- Selected platforms are saved and listed on the dashboard. Tapping a listed platform opens the existing login UI with that platform's name.
- Keeps the About dialog date and the original app/collaborator artwork layout.
- Publishes versioned direct-download files for Android, Windows, Linux, iOS simulator, and a combined ZIP using the v0.2.5 filenames.

## Authentication status

- The selected platform's login page reuses the previously designed ID/password row and Google, Facebook, KakaoTalk, and Naver sign-in buttons.
- This is a login UI placeholder only. Password login and social login are not connected to provider OAuth or a backend; the buttons report that authentication setup is required.
- Real sign-in requires OAuth application registration, client identifiers/secrets, redirect URI configuration, and platform-specific callback setup.
- Connecting each development platform still requires its own authorization and API integration.

## Important implementation status

The selected development-platform list is saved. Per-platform login is currently UI-only; provider authentication, automatic project discovery, latest-artifact retrieval, date sorting, and confirmed-download flow are not connected yet. Do not treat the platform selection screen as proof that artifact retrieval is already working.

## Build outputs

GitHub Releases provide direct downloads for each platform and the combined ZIP.

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
