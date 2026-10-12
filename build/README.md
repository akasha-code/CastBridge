# CastBridge builds

[Downloads](../docs/downloads.md) · [Project](../README.md)

Build configuration and release-maintenance tools live here. Installers and ZIP payloads are attached to **GitHub Releases**, not committed to Git history. The repository and downloads remain private during validation.

## Build on Windows

Use Windows 11 x64, the .NET Framework C# compiler included on the supported system, and GCC x64 for the native display helper. Close CastBridge before building: the application executable or helper may be in use.

From the repository root:

```powershell
.\build\Build.ps1 -CheckOnly
.\build\Build.ps1
```

The entry point runs the existing icon, native-helper and desktop/installer build scripts. Outputs retain the project's existing locations:

- `CastBridge.exe`: local desktop executable.
- `artifacts/CastBridge-Setup.exe`: standalone installer.
- `artifacts/CastBridge-Windows-x64-*.zip`: application payload.

Generated executables, payloads and environments are ignored by Git. Do not upload local preferences, monitor layouts, logs or environments.

## Validate and publish a preview

Run the native checks and Python tests, inspect the payload, and record any missing hardware or second-PC validation in the release notes. Keep preview builds marked as prereleases. A build is not proof of digital signature or hardware validation.

```powershell
.\scripts\Test-Desktop.ps1
.\scripts\Test-DesktopLifecycle.ps1
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Upload the installer and its SHA-256 checksum to a release for the tested commit. Do not replace an older release's files with a different build. Keep earlier versions available for troubleshooting.

`scripts/Test-InstallerLifecycle.ps1 -PreviousInstaller <path>` exercises a previous release, upgrade and uninstall in a fresh guarded directory under `artifacts`. It refuses to replace an existing Windows registration. It verifies application-file ownership, Windows registration and retained user data. These developer tests do not replace a second-PC validation.

## Refresh the download page

After publishing a release, run:

```powershell
.\build\Update-Downloads.ps1
```

This reads published releases using the authenticated GitHub CLI. It verifies that the repository is still private and regenerates the English, Spanish and Norwegian download pages, plus `build/releases.json`. Review and commit those files. It does not publish a website, change repository visibility or store credentials.

The latest preview and latest stable release are selected separately from their publication dates. A prerelease is not presented as stable, and drafts are excluded.

## License files in release payloads

New payloads include LICENSE, NOTICE, TRADEMARKS.md, THIRD_PARTY_NOTICES.md and third_party/licenses/. Keep upstream texts intact and review obligations before bundling external tools. Existing release assets are not replaced silently.
