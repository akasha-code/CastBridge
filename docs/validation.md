# Preview validation

## 0.2.0-alpha.2 â€” 12 October 2026

These results apply to the Windows 11 x64 development PC. They do not establish compatibility with every Windows system or Chromecast.

- **Desktop shutdown:** reproduced a null-reference exception when exiting from the tray. Made resource disposal idempotent. The regression test invokes the actual Exit menu item and repeats disposal; it passes.
- **Live compiled interface:** the receiver confirmed PLAYING during a three-minute session. The user confirmed the visible cursor and scrolling with both the mouse wheel and Page Down. The application recorded the wheel event; its Page Down event flag remained false, so keyboard confirmation comes from the user's observation.
- **Latency observation:** the user reported clocks reading `21.10.05.82` and `21.10.08.56`, an absolute difference of 2.74 seconds. This is a manual observation, not a guaranteed latency bound.
- **Normal disconnect:** the session report recorded no cleanup errors, removal of the temporary monitor and restoration of physical displays. The synthetic reference window returned to the primary monitor before closing.
- **Upgrade and uninstall:** installed the published alpha.1 installer in an isolated fixture, upgraded using alpha.2 and exercised the actual uninstaller routine. Windows Installed apps registration and the Start-menu shortcut were verified. Upgrade retained language, preferences and layout; uninstall removed owned runtime files, including an obsolete file from the previous manifest, and retained user data and logs.
- **Distribution:** new packages include the project's Apache-2.0 license, attribution, marks policy and third-party license notices. External Python, FFmpeg and display-driver prerequisites remain separate.

## Still pending

- Full clean installation and Chromecast streaming on a second PC; only the development PC is available.
- Publisher signing with a trusted code-signing certificate.
- Suspend/resume, network interruption and forced-closure recovery.

The repository and downloads remain private. Releases remain prereleases while these limits are being evaluated.

[MateKraft — matekraft.tech](https://matekraft.tech) · [Buy me a coffee](https://www.buymeacoffee.com/matekraft)
