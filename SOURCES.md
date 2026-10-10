# Research notes and sources

Research for Windows 10 22H2 / i9-11900K / Prime Z590-A / RTX 3080, October 9, 2026 (client date).

The workspace could retrieve official GitHub-hosted Microsoft, NVIDIA and Intel material. Direct requests to Microsoft Learn/Support, Intel and NVIDIA websites returned proxy 403 errors. Therefore this package does not claim an exhaustive live review of every possible tweak or current vendor support document. It does not contain benchmark results for this PC. The source-supported principles and the hardware-informed suggestions are distinguished in the guide.

## Retrieved and read

1. [Microsoft: Introduction to page files](https://github.com/MicrosoftDocs/SupportArticles-docs/blob/main/support/windows-client/performance/introduction-to-the-page-file.md). Commit limits, large-RAM systems, crash dumps and system-managed page files. Supports keeping page-file management appropriate even with 64 GB RAM.
2. [Microsoft: BCDEdit /set](https://github.com/MicrosoftDocs/windows-driver-docs/blob/staging/windows-driver-docs-pr/devtest/bcdedit--set.md). Describes useplatformclock/useplatformtick/tscsyncpolicy and flags several as debugging options. Supports avoiding timer/boot recipes as a generic gaming preset.
3. [Microsoft: Acquiring high-resolution time stamps](https://github.com/MicrosoftDocs/win32/blob/docs/desktop-src/SysInfo/acquiring-high-resolution-time-stamps.md). Explains QPC, TSC, HPET and Windows timer selection. Counter precision is distinct from game input latency.
4. [Microsoft: Network adapter performance tuning](https://github.com/MicrosoftDocs/windowsserverdocs/blob/main/WindowsServerDocs/networking/technologies/network-subsystem/net-sub-performance-tuning-nics.md). Describes interrupt moderation, CPU-load tradeoffs, offloads, RSS and TCP auto-tuning. This is **server guidance**; its general mechanism does not establish a gaming benefit on the user's NIC.
5. [Microsoft: Interrupt moderation](https://github.com/MicrosoftDocs/windows-driver-docs/blob/staging/windows-driver-docs-pr/network/interrupt-moderation.md) and [standardized INF keywords](https://github.com/MicrosoftDocs/windows-driver-docs/blob/staging/windows-driver-docs-pr/network/standardized-inf-keywords-for-network-devices.md). Explain the NDIS mechanism, defaults and standardized property. The optional experiment targets an exposed standardized keyword rather than guessing vendor registry paths.
6. [Microsoft Windows SDK: winnt.h](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/um/winnt.h). Defines the power-setting GUIDs and their semantics, including processor minimum, maximum, energy/performance preference, parking and PCIe ASPM. GUID existence does not prove a useful improvement on a particular firmware.
7. [Microsoft: SystemParametersInfoW](https://github.com/MicrosoftDocs/sdk-api/blob/docs/sdk-api-src/content/winuser/nf-winuser-systemparametersinfow.md). Documents SPI_GETMOUSE/SPI_SETMOUSE, thresholds and acceleration, plus the update/broadcast flags. Used for an immediately applied, reversible pointer preference.
8. [NVIDIA: NVAPI header](https://github.com/NVIDIA/nvapi/blob/main/nvapi.h) and [driver settings](https://github.com/NVIDIA/nvapi/blob/main/NvApiDriverSettings.h). Describe low-latency/sleep API integration and per-profile driver controls/power states. SDK availability does not validate a universal Control Panel preset or every game's integration.
9. [Intel: PresentMon](https://github.com/GameTechDev/PresentMon). Defines graphics performance/frame/latency metrics and documents the HAGS-related limitations of certain GPU execution measurements. Supports using representative repeated measurements rather than promising FPS gains.

## Official follow-up pages, not successfully retrieved here

- [Intel i9-11900K specifications](https://www.intel.com/content/www/us/en/products/sku/212325/intel-core-i911900k-processor-16m-cache-up-to-5-30-ghz/specifications.html).
- [ASUS Prime Z590-A support](https://www.asus.com/motherboards-components/motherboards/prime/prime-z590-a/helpdesk_bios?model2Name=PRIME-Z590-A). Check the current board manual, BIOS release notes, memory compatibility and driver downloads.
- [NVIDIA RTX 30-series Resizable BAR guidance](https://www.nvidia.com/en-us/geforce/news/geforce-rtx-30-series-resizable-bar-support/). Also check the **actual card manufacturer's** VBIOS instructions.
- [NVIDIA Reflex](https://www.nvidia.com/en-us/geforce/technologies/reflex/). Verify support/settings for the particular CoD release.
- [Microsoft powercfg command-line reference](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options).
- [Microsoft Windows 10 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro).

Per-user Game Mode and capture registry preference names in this Windows-19045-specific tool are implementation settings, not a documented policy API guarantee. The tool backs them up, reads them back, and asks the user to confirm the actual Windows Settings switches. It does not write blanket GameDVR/fullscreen flags or machine-wide capture policy.

## Validation limits

The artifact was authored and inspected in Linux. A checksum-verified official PowerShell release supplied the parser and the simulated tests. These checks can detect syntax and backup/restore logic problems; they cannot establish Windows 5.1 API behavior, driver acceptance, hardware stability, or real game FPS/latency. No game settings or firmware on the user's PC have been changed by this chat.
