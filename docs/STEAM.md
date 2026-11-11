# Steam release checklist

The game is ready for Steam except for things only the Steamworks account holder can do. The code already handles achievements, and without Steam it runs exactly as it does now.

## 1. Steamworks app
- Pay the Steam Direct fee and create the app. Note the **App ID**.
- **Achievements:** add each one under *Stats & Achievements* with the API name from `scripts/autoload/achievements.gd` (`LIST`), for example `MILLWHEEL` or `LAST_MARGIN`. The names and descriptions are in that file too. Achievement icons are 256x256 JPGs, one locked and one unlocked.
- **Cloud saves (Steam Auto-Cloud):** no code is needed. Under *Steam Cloud → Auto-Cloud*, add these paths:
  - Windows: root `WinAppDataRoaming`, subdirectory `Godot/app_userdata/Patch and the Pop-Up Kingdom`, pattern `*`
  - macOS: root `MacAppSupport`, subdirectory `Godot/app_userdata/Patch and the Pop-Up Kingdom`, pattern `*`
  - Byte quota: 10 MB. File count: 50.

## 2. GodotSteam
- Install the **GodotSteam GDExtension** for Godot 4.7 from the Asset Library into `addons/godotsteam/`, and include the Steamworks SDK redistributables it lists.
- Call `Steam.steamInitEx(false, <APP_ID>)` once at start-up. It belongs in `Achievements._ready()`, after `_steam` is found. Until this is wired up, `Engine.has_singleton("Steam")` is false and achievements are stored only in `user://achievements.json`.
- For local testing, put `steam_appid.txt` (containing just the App ID) next to the exported executable. Don't ship it.

## 3. Builds
- CI already exports Windows (`.exe`) and macOS (`.app` in a `.zip`) on every push. See `.github/workflows/build-desktop.yml`.
- Upload the builds with SteamPipe (`steamcmd +run_app_build`), one depot per OS.
- macOS builds have to be signed and notarized for Gatekeeper. That needs an Apple Developer account. Add the certificate to the export preset's codesign options, or sign in CI with repository secrets.

## 4. Store page
Steam requires: header capsule 920x430, small capsule 462x174, main capsule 1232x706, vertical capsule 748x896, library capsule 600x900, library hero 3840x1240 and library logo, at least 5 screenshots at 1920x1080, a trailer, a short description of 300 characters or fewer, and the age rating questionnaire (the game targets 16+: horror themes and violence against paper creatures).
