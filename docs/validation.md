# Preview validation

## 0.2.0-alpha.5 — 12 October 2026

- **Receiver power loss:** after PLAYING, the user unplugged the Chromecast. The disconnected socket was detected despite stale media status; after 30 seconds unavailable the stream stopped. The report recorded no cleanup errors, removal of the virtual monitor, physical-display restoration and reference-window recovery. The user confirmed disappearance and window recovery. Reconnecting the receiver allowed subsequent live sessions.
- **Suspend handler:** injected the same Suspend event consumed by the desktop into a live session. The handler requested stop; transmission ended, the reference window recovered and physical displays were restored without errors. This is a handler test, not a full Windows sleep/resume test.
- **Actual standby and automatic reconnection:** this PC reports Modern Standby S0 with disconnected networking. Initial suspend tests restored displays but did not reconnect. Registering Windows session lock/unlock notifications resolved the tested sequence: the user confirmed the countdown and automatic transmission to the previous receiver. The final live report recorded one reconnection attempt, receiver PLAYING again, two completed display cleanups and reference-window recovery. The interrupted first transport subprocess exited abnormally in that test; the desktop recovered independently. Python fault-handler diagnostics are now enabled for session subprocesses to investigate any recurrence.
- **Reconnect prompt:** the successful live sequence initially used five seconds. The user requested ten seconds and a larger popup. The revised ten-second popup, lock gating, Cancel button and closing-X cancellation passed owned-window message tests in all three languages. The popup has Connect now and Cancel actions; cancellation disarms reconnection.
- **Forced desktop termination:** a live test terminated its own desktop process without executing the desktop's normal cleanup. Windows removed the temporary monitor, and an independent synthetic window remained accessible on one of the three physical screens. Physical positions, dimensions, rotation and refresh values matched the baseline. No FFmpeg process remained. This result is specific to this PC and does not validate every crash or driver failure.
- **Encoder termination:** a real synthetic FFmpeg process was killed; stream cleanup released its servers, threads and buffered content.
- **Configuration helper:** isolated checks passed for fresh creation, unchanged matching content, exact backup of the previous file and atomic replacement. Installer actions and translations were checked in all three languages. The existing valid system-wide configuration was not replaced merely to exercise the helper.

The installer now applies missing driver configuration after an explanatory confirmation and Windows elevation, preserving the original XML as a uniquely named backup. It refuses to change configuration while CastBridge or the driver is active. Transport failure with successful display recovery is reported separately from a cleanup failure, and reconnect remains available after successful recovery.

## 0.2.0-alpha.2 — 12 October 2026

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
- Additional sleep/hibernate and interruption scenarios across devices, including diagnosis of the abnormal capture subprocess exit observed during one standby test. Receiver power loss, forced desktop termination and standby reconnection were tested on this PC as described above.

The repository and downloads remain private. Releases remain prereleases while these limits are being evaluated.

[MateKraft — matekraft.tech](https://matekraft.tech) · [Buy me a coffee](https://www.buymeacoffee.com/matekraft)
