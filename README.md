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

## Android release build
The GitHub Actions workflow runs Flutter static analysis, automated tests, and a release APK build on every push to `main`. The APK is uploaded as the `easy-simple-notes-release-apk` workflow artifact and is available for 14 days.

## Data and privacy
Notes are stored locally on the device using SharedPreferences. There is currently no cloud sync, account system, analytics SDK, or advertising SDK. Clearing app data or uninstalling the app can remove locally stored notes. Use Settings → Backup & Restore to export a JSON backup before changing devices or reinstalling the app. Restore replaces the current notes and Bin after confirmation.

## Package
- Flutter project: `pamsho_notes`
- Android application ID: `com.pamsho.pamsho_notes`
- App display name: `Easy Simple Notes`
