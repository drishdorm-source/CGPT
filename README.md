# Windows 10 competitive gaming tuning

Built for Windows 10 22H2 build 19045, Intel i9-11900K, ASUS Prime Z590-A, RTX 3080, 64 GB DDR4-3200 and a 240 Hz monitor, with Call of Duty and Rocket League in mind.

**[Download the ZIP package](https://github.com/drishdorm-source/CGPT/raw/refs/heads/main/Competitive-Tuning-Win10.zip)**

The package contains the self-contained batch file, quick-start instructions, a hardware/game settings guide, research sources and validation notes.

## Use

1. Extract the ZIP.
2. Right-click `Competitive-Tuning-Win10.bat` and choose **Run as administrator**, using your usual Windows account.
3. Choose **1** for the hardware/settings audit.
4. Choose **15** for the Call of Duty high-FPS Windows preset.
5. Follow [GUIDE.md](GUIDE.md) for NVIDIA, BIOS, display and game settings.
6. Choose **13** to undo settings changed by the batch file. Restart Windows afterward.

The CoD preset creates a separate High Performance-based AC power plan, requests a 5% CPU minimum / 100% maximum and performance EPP when available, enables Game Mode and turns off Xbox game recording preferences. Manual Xbox clips may also become unavailable. Other menu options provide optional CPU/core-parking and network experiments, hardware auditing, diagnostics and GPU telemetry.

Backups and reports are stored in `%LOCALAPPDATA%\PC-Competitive-Tuning`. The undo option covers the tool's recorded changes; BIOS, NVIDIA profiles and manually changed Windows/game settings have their own rollback.

## Validation and research

The final payload passed a PowerShell syntax parser and 39 simulated assertions covering backup, repeat application, exact restoration, owned power-plan cleanup and incomplete-undo recovery. It has **not been run on a Windows gaming PC**, and no FPS or input-latency gain has been measured.

Read [SOURCES.md](SOURCES.md) for the official documentation retrieved and research limitations, and [VALIDATION.txt](VALIDATION.txt) for the checks performed. Some direct vendor websites were blocked during research; the package does not claim an exhaustive current review of every possible tweak.

ZIP and batch contents are the same versions validated before this repository upload.
