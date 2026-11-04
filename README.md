# Easy Simple Notes

A clean, lightweight Android notes app built with Flutter.

## Features
- Create and edit notes with automatic saving.
- Search note titles and content.
- Long-press a note to edit or move it to the Bin.
- Restore notes from the Bin or permanently delete them after confirmation.
- Light and dark themes with six accent colours.
- Export and restore full JSON backups, including pinned notes, categories, colours, and the Bin.
- Local, offline-first storage; no account is required.
- A banner advertising slot powered by Google Mobile Ads.

## Android release build
The GitHub Actions workflow runs Flutter static analysis, automated tests, and a release APK build on every push to `main`. The APK is uploaded as the `easy-simple-notes-release-apk` workflow artifact and is available for 14 days.

## Data and privacy
Notes are stored locally on the device using SharedPreferences. There is currently no cloud sync or account system. The app includes Google Mobile Ads for banner advertising; the app's privacy policy and store disclosures must explain the applicable advertising data collection and processing. Clearing app data or uninstalling the app can remove locally stored notes. Use Settings → Backup & Restore to export a JSON backup before changing devices or reinstalling the app. Restore replaces the current notes and Bin after confirmation.

## Package
- Flutter project: `pamsho_notes`
- Android application ID: `com.pamsho.pamsho_notes`
- App display name: `Easy Simple Notes`
