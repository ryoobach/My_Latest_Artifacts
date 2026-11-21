# My Latest Artifacts

Cross-platform dashboard for viewing the newest build artifact from each project.

## Build 0.2.4

- Adds the initial login screen with ID and password fields side by side with the login button.
- Displays Google, Facebook, KakaoTalk, and Naver sign-in choices below the login row. These are UI placeholders only: selecting one reports that OAuth setup is required; no provider authentication is active yet.
- Adds the current date in YYYY-MM-DD format between the app identity row and the existing user/collaborator row in the About dialog.
- Updates the About dialog to show the original app icon, app name, and version on the first row.
- Shows the existing user/collaborator artwork `js_logo.png` beside `Ryoo jaesang & 최피디` on the second row. No additional "공동제작" caption is displayed.
- Uses the exact agreed filenames for GitHub Actions artifacts and GitHub Release assets:
  - `My_Latest_Artifacts_Androidv0.2.4.apk`
  - `My_Latest_Artifacts_Windowsv0.2.4.zip`
  - `My_Latest_Artifacts_Linuxv0.2.4.tar.gz`
  - `My_Latest_Artifacts_iOSv0.2.4.zip`
  - Combined: `My_Latest_Artifacts_v0.2.4.zip`
- Publishes the five files as direct GitHub Release assets, avoiding an extra Actions-artifact ZIP wrapper for end-user downloads.
- The combined ZIP contains the four platform files directly at its root.

## Authentication roadmap

- The login screen presents Google, Facebook, KakaoTalk, and Naver choices in that order.
- The current build contains the login UI only. Password login and social login are not connected to an authentication server or provider OAuth flow.
- Real sign-in requires OAuth application registration, client identifiers/secrets, redirect URI configuration, and platform-specific callback setup.
- Connecting GitHub, GitLab, Bitbucket, Azure DevOps, and Jenkins still requires each provider's own authorization and API integration. App sign-in does not grant access to those development-platform accounts.

## Important implementation status

This remains an intermediate UI and settings build. The selected development-platform list is saved, and platform credential values are stored securely on the device, but provider authentication, automatic project discovery, latest-artifact retrieval, date sorting, and confirmed-download flow are not connected yet. Do not treat the platform selection screen as proof that artifact retrieval is already working.

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
