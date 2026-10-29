# Exporting desktop builds (Windows .exe and macOS .app)

The project already includes two export presets in `export_presets.cfg`:

| Preset | Output | Notes |
| --- | --- | --- |
| **Windows Desktop** | `build/windows/PatchPopUpKingdom.exe` | 64-bit, game data embedded in the .exe (one file to share), custom icon and version info |
| **macOS** | `build/macos/PatchPopUpKingdom.zip` (contains `Patch and the Pop-Up Kingdom.app`) | Universal (Intel + Apple Silicon), ad-hoc signed |

Both presets were exported successfully with Godot 4.7.2. The steps below assume you're working on your Windows PC.

## 1. Install the export templates (one time)

Export templates are the prebuilt game engines that Godot wraps around your project. They must match your editor version exactly (4.7.2).

1. Open the project in Godot 4.7.2.
2. Go to **Editor > Manage Export Templates...**
3. Click **Download and Install**. It's about 1 GB and covers every platform.
4. When it finishes, the dialog shows *Current Version: 4.7.2.stable* as **Installed**.

**Offline alternative:** download `Godot_v4.7.2-stable_export_templates.tpz` from the [Godot 4.7.2 release page](https://github.com/godotengine/godot/releases/tag/4.7.2-stable). Then, in the same dialog, choose **Install from File** and pick the `.tpz`.

Templates are installed per computer (under `%APPDATA%\Godot\export_templates\4.7.2.stable`), not per project.

## 2. Export the Windows build

1. Open **Project > Export...**
2. Select the **Windows Desktop** preset on the left. There should be no red error text at the bottom; if there is, it's almost always missing templates (step 1).
3. Click **Export Project...**
4. Keep the file name `PatchPopUpKingdom.exe`, inside a `build/windows` folder.
5. **Untick "Export With Debug"** for a release build, then click **Save**.
6. Double-click the .exe to play. The single file is the whole game.

Because the .exe isn't code-signed yet, Windows SmartScreen may say "Windows protected your PC". Click **More info > Run anyway**. Testers will see the same message until the build is signed (see "Later: Steam" below).

## 3. Export the macOS build (from your Windows PC)

1. In **Project > Export...**, select the **macOS** preset.
2. Click **Export Project...**, save as `build/macos/PatchPopUpKingdom.zip`, untick **Export With Debug**, and click **Save**.

   Exporting to `.zip` is what lets you build a Mac app on Windows. Godot packs the `.app` bundle into the zip with the right permissions, which a plain Windows folder can't hold.
3. Copy the zip to a Mac and double-click it to extract `Patch and the Pop-Up Kingdom.app`.

**First launch on a Mac.** The app is ad-hoc signed but not notarized by Apple, so Gatekeeper blocks a normal double-click the first time:

- **Right-click (or Control-click) the app > Open > Open.** After that it opens normally.
- On macOS 15 (Sequoia) and later, if there's no Open button: double-click the app once, then go to **System Settings > Privacy & Security**, scroll down, click **Open Anyway** next to the app, and confirm.
- If macOS says the app "is damaged and can't be opened" (this happens to some downloaded files), open Terminal and run:
  `xattr -cr "/path/to/Patch and the Pop-Up Kingdom.app"`

### What the macOS preset sets, and why

| Option | Value | Why |
| --- | --- | --- |
| Binary Format > Architecture | `universal` | One app runs natively on Intel and Apple Silicon Macs. |
| Codesign > Codesign | Built-in (rcodesign) | Ad-hoc signs the app on any OS. Apple Silicon refuses to run completely unsigned code. |
| Export > Distribution Type | Testing | No Apple Developer account is needed yet. |
| Notarization | Disabled | Needs an Apple Developer account (see below). |
| Texture formats | S3TC/BPTC + ETC2/ASTC | ETC2/ASTC is required for Apple Silicon. The project setting *Rendering > Textures > VRAM Compression > Import ETC2 ASTC* is on for this reason. |
| Bundle identifier | `com.aharris.patchpopupkingdom` | Must be unique and stay the same forever once you ship. Change it now if you prefer another. |

## 4. Automatic builds on GitHub

`.github/workflows/build-desktop.yml` runs on every push to `main`, on every pull request, and on demand (**Actions > Build desktop > Run workflow**). It:

1. Downloads Godot 4.7.2 and the export templates (cached after the first run).
2. Imports the project and runs the headless smoke test (`tools/godot/smoke_test.gd`). A failing test stops the build.
3. Exports both presets and uploads them as downloadable artifacts: **PatchPopUpKingdom-windows** and **PatchPopUpKingdom-macos**.

To get a build: open the repository on GitHub, go to **Actions**, open the latest run, and download the artifacts at the bottom of the page.

## Exporting from the command line

From the project folder, with Godot on your PATH:

```
godot --headless --export-release "Windows Desktop" build/windows/PatchPopUpKingdom.exe
godot --headless --export-release "macOS" build/macos/PatchPopUpKingdom.zip
```

The `build/` folders must exist first. On Windows, use the console executable, `Godot_v4.7.2-stable_win64_console.exe`, so you can see the output.

## Later: shipping on Steam

These steps don't change the project structure. They're about signing and packaging:

- **Windows code signing** removes the SmartScreen warning. Buy a code-signing certificate, then enable **Codesign** in the Windows preset (it uses Microsoft's `signtool`).
- **macOS notarization** removes the Gatekeeper warning.
  1. Get an Apple Developer account (99 USD/year).
  2. Create a *Developer ID Application* certificate and an App Store Connect API key.
  3. In the macOS preset, set **Distribution Type** to *Distribution*, enter the certificate under **Codesign**, and set **Notarization** to *rcodesign* with the API key. Godot can do this from Windows; no Mac is required.
- **Steam integration** (achievements, cloud saves, overlay) is usually added with the GodotSteam extension. Saves already live in a game-specific folder (`PatchPopUpKingdom`), so Steam Cloud can sync that folder directly.
- **Steam depots:** upload the Windows `.exe` and the extracted macOS `.app` as separate depots with SteamPipe.
