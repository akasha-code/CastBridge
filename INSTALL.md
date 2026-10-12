# Install CastBridge

[English](README.md) · [Español](README.es.md) · [Norsk](README.no.md)

A production by [MateKraft](https://matekraft.tech).

## Open the installer

Download `CastBridge-Setup.exe` from the latest preview release. Choose English, Spanish or Norwegian Bokmål. Prerequisite checks and guidance are translated. **Install remains disabled until every check passes**, and checks are repeated before installation.

Windows 11 x64 and its .NET Framework runtime are required to open the executable. This preview is not digitally signed yet. Do not disable Windows protections to accept a file you have not verified.

## Prepare external tools

1. **Python:** install Python 3.12 x64 from the official Python Windows downloads, including the `py` launcher. Reopen the installer afterwards.
2. **FFmpeg:** use a Windows build with `gdigrab`, `libx264` and HLS output. Add its `bin` directory to PATH and reopen the installer. CastBridge does not change PATH.
3. **Driver:** download and extract signed Virtual Display Driver **25.7.23** from its official release. In an administrator **Command Prompt**, run `pnputil /add-driver "FULL_PATH\MttVDD.inf"`. Do not add `/install` or create another persistent ROOT device. Keep signature verification enabled. CastBridge creates its own temporary device when connecting.
4. **Configuration:** use **Save configuration template** in the installer. Copy that XML to `C:\VirtualDisplayDriver\vdd_settings.xml` with administrator permission. Review and back up any existing configuration instead of overwriting settings used by another application. The template configures one 1280 × 720 monitor at 60 Hz with a software cursor.
5. **Network:** allow HTTPS access to `pypi.org` and `files.pythonhosted.org` for dependency downloads. The installer does not modify proxy, firewall or certificate settings.
6. **Sessions:** disconnect and exit CastBridge before installation or an update. Review any persistent virtual display using the same driver; the application rejects concurrent sessions.

The installer checks the driver's expected version in Driver Store and valid CAT/DLL signatures. An XML file alone is not proof that the driver is installed.

## Installation

Choose a new folder or an existing CastBridge installation. The default is `%LOCALAPPDATA%\Programs\CastBridge`. Files are copied only after the prerequisites pass. The installer creates a local Python environment, downloads the pinned dependencies and runs `pip check` before reporting success.

A complete installation creates a **MateKraft / CastBridge** Start-menu shortcut and an entry in Windows **Installed apps**. The installer language becomes the initial application language and can be changed later. The application does not register itself to start with Windows.

Administrator permission is requested when activating the temporary display. The PC and receiver must be reachable on the local network; receiver connectivity is checked when connecting.

## Interrupted installation

A failed download can leave a partial environment. The installer reports failure and retains the log. Correct the issue and retry in the same owned installation folder. Success is not announced until dependency checks pass.

## Uninstall

Disconnect, wait for cleanup and exit. Uninstall through Windows **Installed apps**. Application files and the owned Python environment are removed. Preferences and diagnostic logs remain in the installation folder. Python, FFmpeg and the driver remain installed separately.

Do not reuse another PC's `oemXX.inf` package number. Driver removal is a separate administrator operation.

## Validation

Hardware streaming was tested on the development PC. A full installation and streaming session on another PC remain pending. The compiled interface replaces the PowerShell interface; transport and cleanup need regression validation. Suspend/resume, network interruption and forced closure remain experimental boundaries.
