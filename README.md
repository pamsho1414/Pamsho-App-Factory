# Pamsho Notes

A lightweight Flutter notes app. The first version supports creating, editing, searching, and deleting notes. Notes are stored locally on the device using SharedPreferences.

## Build an Android APK

1. Open the **Actions** tab in this repository.
2. Select **Build Android APK**.
3. Choose **Run workflow** (or push a commit to `main`).
4. When the run succeeds, open the run and download the `pamsho-notes-release-apk` artifact.

The workflow generates the Android platform folder in the cloud runner, builds a release APK, and uploads it as a workflow artifact.

## Current scope

- Local-only note storage (no account or cloud sync yet).
- Create, edit, search, and swipe-to-delete notes.
- No ads are included in this starter version.
