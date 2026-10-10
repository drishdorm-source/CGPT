# Competitive tuning for your PC

Target: Windows 10 22H2, build 19045; Intel i9-11900K; ASUS Prime Z590-A; RTX 3080; 64 GB DDR4-3200; 240 Hz display; Call of Duty and Rocket League.

The batch file has a **Call of Duty high-FPS preset, option 15**. It applies the Windows portion of the setup. BIOS, NVIDIA Control Panel, monitor, and game settings need the steps below. There is no reliable way to predict an FPS increase from the hardware list alone: resolution, CoD version, driver, cooling, RAM layout, and the current settings all matter. Recommendations below are hardware-informed assessments, not benchmarks of your PC.

## Run the batch file

1. Save `Competitive-Tuning-Win10.bat`, right-click it, and select **Run as administrator** using your usual Windows account. Enter means **No** at confirmation prompts. Running under another administrator's account changes that account's user settings.
2. Run **option 1** first. The audit checks the Windows patch revision, GPU/driver/VRAM, board/BIOS, configured RAM speed, storage, startup names, power plans, network settings, and existing timer overrides.
3. For CoD, try **option 15**, then follow the CoD and NVIDIA tables below. Restart the game and verify Game Mode and background recording in Windows Settings. Per-user gaming registry preferences can be overridden by policy or changed by Windows, so registry read-back is not proof of their effect in a game.
4. Benchmark against your original configuration. **Option 14** switches back to the original power plan for comparison. It leaves Game Mode/capture changes in place; use **option 13** for a full tool rollback when comparing the entire preset.
5. Use **option 13** to restore the exact original settings recorded by the tool and remove only its own power plans. Restart Windows after undoing NIC/capture changes.

Backups and reports live in `%LOCALAPPDATA%\PC-Competitive-Tuning`. Keep `backup.json` until you finish testing. Repeat runs retain the first original values instead of replacing them with already-tuned values. A failed/partial undo preserves the backup and reports the unresolved items. An original power plan that you deleted separately must be recovered before that part can be restored.

The tool uses built-in Windows PowerShell 5.1. It installs nothing, downloads nothing, and runs no game executable. Corporate PowerShell restrictions can prevent it from running. Its undo covers its own settings; changes made manually in BIOS, NVIDIA Control Panel, Windows Settings, or game menus have to be reversed there.

## What the options do

| Option | Action | Value for your PC |
|---|---|---|
| 1 | Read-only hardware/configuration audit; saves a local report | High diagnostic value; identifies whether 3200 MT/s is actually configured |
| 2 | Separate Balanced-based AC plan: CPU minimum 5%, maximum 100%, EPP 0 when exposed | Experiment in faster performance preference; stock Balanced may perform equally well |
| 3 | Separate AC plan: CPU minimum 100%, EPP 0, minimum unparked cores 100% where supported | Aggressive experiment; extra heat/power can hurt an already-hot 11900K |
| 4 | Game Mode preference on, with original value backed up | Reasonable starting point; game-dependent benefit |
| 5 | Xbox game capture preferences off, with backups; manual Xbox clips may also become unavailable | Useful if background capture was consuming resources; separate from OBS/NVIDIA capture |
| 6 | Windows pointer acceleration off through the Windows API, with exact original thresholds saved | Input consistency for applications using Windows pointer input; raw-input games usually unaffected |
| 7 | Disable the selected adapter's standard interrupt-moderation property; exact value backed up | Optional local packet-latency experiment; CPU interrupt load rises; restart required |
| 8 | Separate AC plan with USB selective suspend and PCIe link power saving off if available | Troubleshoot device wake/dropout issues; no established universal FPS benefit |
| 9 | Open graphics settings for manual HAGS comparison | Driver/game-dependent, restart between tests |
| 10 | Open refresh rate, startup, captures, mouse or virtual-memory settings | Correct obvious misconfiguration without disabling unrelated services |
| 11 | DISM ScanHealth, SFC verify-only, storage analysis | Troubleshooting only; output findings matter more than command completion |
| 12 | 60 one-second samples of NVIDIA temperatures, utilization, clocks and power | Helps investigate GPU bottlenecks/throttling; does not measure FPS or end-to-end latency |
| 13 | Undo recorded changes | Restores saved values, including removing values that originally did not exist |
| 14 | Original power plan active again | Quick power-profile comparison |
| 15 | CoD preset: separate High Performance-based AC plan with CPU min 5%, max 100%, EPP 0 where supported; Game Mode on; Xbox recording off, including background clips | Convenient Windows starting point; manual Xbox clips may also be unavailable; apply game settings below for substantial GPU-work reductions |

Power experiments modify their own cloned plans and AC settings. They preserve your existing plans and do not set BIOS voltage, remove CPU power limits, or guarantee a particular CPU frequency. EPP 0 expresses a performance preference; exposed settings and their effect depend on firmware/driver support. Hidden options are accessed by GUID without changing their global visibility. Unavailable or unverified optional settings are reported.

## Highest-priority hardware checks

| Check | Specific advice | Expected value |
|---|---|---|
| Actual display refresh | Windows Advanced display and the monitor OSD should both show 240 Hz; use a cable/port combination that supports the display's resolution at 240 Hz | Very high if it was running at 60/120/144 Hz; no FPS increase by itself |
| RAM configured speed | Check the audit and CPU-Z/HWiNFO. DDR4-3200 means 3200 MT/s; CPU-Z normally shows a DRAM clock near 1600 MHz | Potentially meaningful for CPU-limited CoD if RAM is currently at a slower default |
| Dual channel/slots | On the Prime Z590-A, use the manual's A2/B2 layout for two DIMMs; use the supported four-slot layout for four. Identify whether your 64 GB is 2x32 or 4x16 | Important if presently single channel or poorly configured |
| Gear mode | Test stable **3200 MT/s Gear 1**, a 1:1 memory-controller-to-DRAM clock ratio, if offered. Gear 2 can add memory latency. XMP does not prove Gear 1 is active | Relevant to CPU-limited high-refresh gaming; verify stability with the actual DIMMs |
| CPU cooling | Log CPU package temperature, effective clocks, and thermal/power-limit flags during CoD, using HWiNFO. Check the cooler and fan curve if throttling occurs | High when boost is being lost to heat; the 11900K can consume substantial power |
| GPU cooling | Check RTX 3080 clocks, core/hotspot and memory temperatures where sensors expose them; address thermal throttling | High if throttling is present; GPU core temperature alone does not reveal every limit |
| Game drive | Use an SSD, retain room for updates/shader caches, and leave Windows Optimize Drives scheduling enabled | Reduces loading/streaming stalls; usually small effect on steady-state FPS |
| GPU installation | Verify the top CPU-connected graphics slot, link width under load, and supported PCIe link generation | Important if the card is accidentally running through a restricted slot/link |

For XMP on ASUS: look under **Ai Tweaker → Ai Overclock Tuner**. Compare the board's XMP profiles using the memory kit's specified speed/timings/voltage; labels and Gear settings vary by BIOS revision. Start from the kit's rated 3200 settings. Four DIMMs or mixed kits can need more conservative settings. Run a memory stability test after changes; a game that crashes intermittently is not a successful optimization.

Keep Intel Speed Shift, Turbo Boost, and Hyper-Threading at supported defaults initially. Use Intel-standard CPU power limits as the baseline; ASUS MultiCore Enhancement/unlimited power is a cooling-dependent experiment, not a prerequisite for high FPS. Do not use a universal all-core voltage, undervolt, ring frequency, RAM timing set, or automatic BIOS flash for this hardware.

### Resizable BAR on the Z590-A / RTX 3080

Check **NVIDIA Control Panel → Help → System Information → Resizable BAR** first. If enabled, you have nothing to change.

If disabled, consult the ASUS BIOS support page and your exact RTX 3080 manufacturer's support page. Typical prerequisites are compatible motherboard BIOS and GPU VBIOS, UEFI boot with CSM disabled, Above 4G Decoding enabled, and Re-Size BAR enabled/Auto. Check whether the existing Windows installation uses UEFI/GPT before touching CSM. Older RTX 3080 cards may need their manufacturer's specific VBIOS updater.

ReBAR is supported by this platform combination when all prerequisites are met, but its performance depends on the game and NVIDIA's driver profile. Preserve the supported driver behavior instead of forcing ReBAR into every game with Profile Inspector. Benchmark CoD after enabling it; it is not a guaranteed gain in Rocket League.

## Call of Duty: maximum-FPS starting point

Names and available options differ across Warzone, Modern Warfare and Black Ops releases. Apply only settings your version exposes. First run its built-in benchmark, where available, and look at CPU versus GPU frame times. Lower resolution/scaling helps a GPU limit; it cannot fix a CPU limit.

| Setting | Starting point for your RTX 3080 / 240 Hz setup | Why / adjustment |
|---|---|---|
| Display refresh | 240 Hz | Confirm the game's own menu as well as Windows |
| Display mode | Test the game's available fullscreen and borderless modes | Modern flip-model presentation can be efficient; exclusive fullscreen is not always faster |
| V-Sync | Off for maximum throughput/lowest-latency competition, accepting tearing | Use the separate VRR setup below for tear-free play |
| Gameplay FPS limit | Uncapped for the diagnostic benchmark; then compare uncapped with a sustainable in-game cap | Avoid repeatedly hitting GPU saturation when Reflex is unavailable; highest FPS is not automatically the smoothest configuration |
| Menu/background FPS | Cap menus, e.g. 60, and unfocused gameplay, e.g. 30 | Reduces unnecessary heat/power outside gameplay |
| NVIDIA Reflex | **On** initially; compare **On + Boost** | Reflex can reduce render-queue latency. Boost retains higher GPU clocks at a power/heat cost |
| Upscaling at 1080p | Native or DLSS Quality first | Aggressive upscaling can hurt visibility and may do little in a CPU-limited match |
| Upscaling at 1440p | DLSS Quality; test Balanced if GPU-limited | Commonly valuable for RTX 3080 GPU-limited FPS; compare distant-target clarity |
| Upscaling at 4K | DLSS Balanced/Performance comparison | Reduces substantial GPU work; quality preferences and the particular CoD implementation matter |
| Frame generation | Off for competitive play | RTX 3080 does not support NVIDIA DLSS Frame Generation; alternative generated frames do not equal lower input latency |
| Ray/path tracing, where offered | Off | Expensive rendering is usually a poor fit for a 240 Hz FPS goal |
| Texture quality | Normal initially; lower if the game's VRAM meter/stutters indicate pressure | RTX 3080 models have different VRAM capacities; 64 GB system RAM does not substitute for GPU VRAM |
| VRAM target/scale, if available | Start around 70–80%; compare with default | Headroom can help asset/VRAM pressure; lower is not always faster |
| Shadows and screen-space shadows | Low/off where allowed | Reduces GPU work; preserve visibility-critical features if preferred |
| Ambient occlusion / screen-space reflections | Off or lowest | Often useful GPU savings |
| Volumetrics, particles, weather, water effects | Low; compare visibility in the actual maps | GPU savings vary by title and scene |
| Tessellation and terrain detail | Low/near/off as the title permits | Another optional GPU-work reduction |
| Motion blur, weapon blur, depth of field, film grain | Off for clarity | Primarily a visibility preference; FPS benefit varies |
| On-demand texture streaming | Off/minimal/lowest-bandwidth supported mode; compare streaming behavior | Can reduce downloads/streaming interference; some releases still require a minimum mode |
| Dynamic resolution | Off for a repeatable baseline | Consider it separately if the title supports it and you prefer a target frame rate over fixed resolution |
| Shader compilation/preload | Let it complete; warm up the maps after a game/driver update | Avoid judging performance during compilation |
| RendererWorkerCount/config edits | Start from the game's default/automatic configuration | The 11900K has 8 cores/16 threads; blindly setting 16 can hurt. Filenames/semantics differ by release |

If the uncapped test reports a CPU bottleneck, prioritize RAM/Gear configuration, effective CPU clocks, game CPU-heavy settings and unnecessary background activity. Lowering every graphical setting is unlikely to give a proportionate gain. If GPU frame time dominates, DLSS, resolution and effects are the stronger choices.

## NVIDIA settings: use a profile for each game

| Control | CoD | Rocket League |
|---|---|---|
| Reflex | In-game On; test On + Boost | Use it only if your build actually offers it |
| Low Latency Mode | Leave off when using Reflex; Reflex handles the game's queue | If no Reflex, A/B test On and Ultra. Driver/API support and frame pacing matter |
| Power management | Test Prefer maximum performance **for the game**, especially if GPU clocks dip during CPU-limited play | Same; a high global idle clock is unnecessary |
| Preferred refresh rate | Highest available, where supported | Same |
| Max Frame Rate | Use one primary limiter; start with the game's limiter | Use the game's limiter first |
| Vertical sync | Off for the maximum-FPS/tearing-accepted setup | Same, or use VRR instructions below |
| Shader cache | Retain the driver default/suitable cache capacity and sufficient disk space | Same; avoid clearing it every boot |
| Texture filtering | Start with default Quality; compare High performance only if acceptable visually | Often a small tradeoff; keep ball/field visibility clear |
| DSR / forced AA / driver upscaling | Keep additional rendering/scaling overrides off unless intentionally used | Same |

A 240 Hz refresh cycle is about **4.17 ms**. Rendering above 240 FPS can still lower latency with V-Sync off, but increases power and can tear. More FPS is useful only while frame pacing and the input/render pipeline remain healthy.

### If you prefer tear-free G-SYNC / G-SYNC Compatible

If the monitor actually supports VRR and it is enabled: use G-SYNC, NVIDIA Control Panel V-Sync On, in-game V-Sync Off, and a cap below the 240 Hz ceiling. **237 FPS is a starting point**, not a guarantee. Reflex may impose its own lower cap in supported configurations; use that rather than stacking conflicting limiters. Check actual frame pacing and whether the cap stays below the VRR ceiling. This setup trades a little maximum throughput for tear-free output.

### Rocket League

Start at native resolution, V-Sync off for the tearing-accepted setup, and highest supported refresh. Compare 240/360 FPS or the available in-game caps against a consistently sustainable cap. On this CPU/GPU, simpler competitive settings can become CPU/frame-pacing limited; reducing resolution may bring little benefit. Effects and visual detail are optional visibility/workload tradeoffs. Treat a Low Latency Mode experiment separately from any FPS cap change.

## Network and input

- Use wired Ethernet when feasible. The Prime Z590-A's onboard 2.5 Gb Ethernet needs the correct OEM/Intel driver; inspect the actual adapter model/revision and current driver in the audit.
- Try option 7 only as an A/B test. Lower local interrupt delay does not reduce the remote server's distance or routing latency. Increased DPC/interrupt work can also hurt frame-time consistency.
- Keep RSS, checksum offloads and TCP auto-tuning at supported defaults initially. Blanket disabling of offloads is not a general gaming fix, and many games use UDP.
- If ping spikes during uploads/downloads, investigate router SQM/QoS and bufferbloat. Router-side queue management addresses a problem a Windows registry preset cannot solve.
- Energy Efficient Ethernet/Green Ethernet can be a driver-specific experiment for observed link wake/stability issues. Labels and support vary; record the current value before changing it. The script avoids guessing a driver-specific property.
- Start with a stable 1000 Hz mouse polling rate. Compare higher rates only if the device supports them and CoD's frame times remain good; 4000/8000 Hz can add CPU work.
- Prefer the game's raw-input path if it offers one. Turning off Windows pointer acceleration is not an FPS optimization and usually has no effect on a raw-input game's sensitivity.
- Keep only the overlays/recorders you use. Compare Discord, NVIDIA, Steam/Xbox, browser video and RGB monitoring individually rather than killing services indiscriminately.

## Advanced experiments and diagnosis

| Item | Decision for this PC |
|---|---|
| HAGS | Compare On/Off, with a restart between tests. Windows 10 build 19045 + RTX 3080 can support it with the correct driver. No universal winning state |
| Fullscreen optimizations | Keep default first; compare the per-game checkbox only for a specific reproducible issue. Global GameDVR flag recipes are unreliable |
| Aggressive core parking / CPU minimum | Option 3 only as a measured experiment. More idle power and heat can erase any gain on an 11900K |
| USB selective suspend / PCIe ASPM | Option 8 for actual peripheral/link wake problems, not a promised response-time improvement |
| GPU undervolt | Potentially useful for RTX 3080 thermals and sustained clocks, but stability and the exact card matter. Tune/test manually; no universal voltage/frequency curve |
| CPU/DRAM overclock | Cooling, motherboard firmware, DIMMs and stability determine the result. The batch deliberately leaves voltages and timings to firmware tools |
| Hyper-Threading, C-states, CPU affinity | Preserve defaults. Change only for a specific demonstrated game/driver issue; restricting this 8-core CPU can hurt workload scheduling |
| DPC troubleshooting | Use LatencyMon as a driver-investigation clue, followed by workload reproduction/ETW if needed. Its audio-suitability warnings are not a measurement of game input latency |
| Frame-time analysis | PresentMon/CapFrameX or CoD's benchmark. Some GPU execution metrics are less accurate with HAGS; compare presentation/frame-time metrics consistently |
| BIOS/driver updates | Check ASUS, the GPU vendor/NVIDIA and the actual adapter vendor release notes. Use the correct board/card revision. Avoid blind updates or flashing from a batch |
| Windows patching | Build 19045 alone omits the cumulative patch level. Standard Windows 10 support ended October 14, 2025; use applicable ESU coverage or a supported OS for ongoing security fixes |

## Popular tweaks excluded after review

These are not hidden FPS gains established for your PC:

- Forced HPET/platform timers, `useplatformclock`, `useplatformtick`, `disabledynamictick`, or `tscsyncpolicy`. Microsoft documents several of these as debugging options. Leave Windows' timer selection alone; audit existing overrides instead of blindly replacing them.
- A permanent timer-resolution background utility. Timer resolution is not the same as QPC precision or measured click-to-photon latency; the behavior varies with the OS/app. It also changes power use.
- Disabling Defender/firewall/updates, CPU security mitigations, or integrity checks. The batch preserves these. Virtualization-based security can have a workload-dependent cost, but its tradeoff requires an explicit security decision, not an automatic FPS preset.
- Disabling the page file because you have 64 GB RAM, fixed huge page files, memory-compression disabling, standby-list purges, RAM cleaners, or `LargeSystemCache` recipes. Commit limits, crash dumps and caching still matter on a 64 GB PC.
- `NetworkThrottlingIndex`, `SystemResponsiveness`, `Win32PrioritySeparation`, MMCSS task priority recipes and `GpuPriority` values without a demonstrated application-specific problem. No measured benefit is established here.
- Realtime process priority, universal CPU affinity/interrupt affinity, arbitrary MSI-mode registry writes and blanket service removal. These can starve useful work or create stability problems.
- TCP ACK/Nagle registry recipes, disabling all offloads, reservable-bandwidth myths, arbitrary MTU changes and DNS flushing as an FPS/ping fix. DNS choice rarely changes latency to an already-connected game server.
- Deleting shader caches and Prefetch at every boot, daily disk defragmentation on SSDs, and aggressive file-cleaning scripts. They can create fresh compilation/loading work.
- Disabling every animation, transparency, search/indexing, diagnostic task or background service as a global FPS preset. Desktop preferences and a specific competing workload should be handled separately.
- Automatic CoD worker-count edits, forced DLSS/ReBAR profile overrides and disabling fullscreen optimizations for every program. Different game/driver versions need different evidence.

## Measure whether it actually helps

1. Record the original configuration. Run the same CoD built-in benchmark or repeatable scene for at least three warm runs. Keep resolution, game version, driver, route/match, and background tools consistent.
2. Record average FPS, low-percentile FPS/frame-time percentiles, stutter spikes, GPU/CPU frame times where available, temperatures and throttle flags. Use the same tool/version and percentile definition for every comparison.
3. Change one group at a time. For the complete option-15 preset, compare it with a full option-13 rollback; option 14 alone compares only power plans. Separate game/NVIDIA changes from the Windows preset when attributing improvements.
4. Reboot between HAGS/NIC tests and let shaders finish. Repeat enough runs to distinguish a change from normal variation. Revert settings that do not consistently improve the result.
5. Input latency is a separate measurement. Use a supported in-game latency metric for its stated scope; true mouse-to-display comparisons need a suitable hardware analyzer or high-speed-camera method. FPS alone does not prove lower total input latency.

No Windows PC was connected to this workspace. The batch was checked with a real PowerShell parser and simulated backup/restore tests; it has not been executed on your PC. Its settings read-back checks help detect failures, but actual game performance must be measured locally.

See `SOURCES.md` for the material retrieved and the vendor pages that require a separate live check.
