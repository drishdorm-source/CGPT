@echo off
setlocal
title Windows 10 Competitive Tuning - i9-11900K / RTX 3080
set "PCOPT_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -Command "$f=[IO.File]::ReadAllText($env:PCOPT_SELF); $m='# '+'POWERSHELL_PAYLOAD_START'; $p=$f.IndexOf($m); if($p -lt 0){throw 'Missing payload'}; & ([scriptblock]::Create($f.Substring($p+$m.Length)))"
set "PCOPT_RESULT=%ERRORLEVEL%"
if not "%PCOPT_RESULT%"=="0" (
  echo.
  echo The tool stopped with an error. Read the message above.
  pause
)
exit /b %PCOPT_RESULT%
# POWERSHELL_PAYLOAD_START
#requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Confirm-Action([string]$Message) {
    return ((Read-Host ($Message + ' [y/N]')) -match '^(y|yes)$')
}

function Assert-Admin {
    if (-not $script:IsAdmin) {
        throw 'Right-click the batch file and choose Run as administrator, using your usual Windows account.'
    }
}

function Save-State {
    $temp = $script:StatePath + '.tmp'
    $script:State | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $script:StatePath -Force
}

function Invoke-Native([string]$Exe, [string[]]$Arguments, [switch]$ShowOutput) {
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $Exe @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $oldPreference }
    if ($ShowOutput) { $output | ForEach-Object { Write-Host $_ } }
    if ($code -ne 0) {
        throw ("{0} {1} failed (exit {2}). {3}" -f $Exe, ($Arguments -join ' '), $code, ($output -join ' '))
    }
    return ($output -join "`n")
}

function Get-PowerGuid {
    $text = Invoke-Native 'powercfg.exe' @('/getactivescheme')
    $match = [regex]::Match($text, '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')
    if (-not $match.Success) { throw 'Could not read the active power plan.' }
    return $match.Value.ToLowerInvariant()
}

function Get-RegistryBase([string]$Hive) {
    if ($Hive -eq 'HKCU') { return [Microsoft.Win32.Registry]::CurrentUser }
    if ($Hive -eq 'HKLM') { return [Microsoft.Win32.Registry]::LocalMachine }
    throw 'Unsupported registry hive.'
}

function Read-RegistryValue([string]$Hive, [string]$Path, [string]$Name) {
    $key = (Get-RegistryBase $Hive).OpenSubKey($Path, $false)
    try {
        $exists = ($null -ne $key -and $key.GetValueNames() -contains $Name)
        $kind = $null; $value = $null
        if ($exists) {
            $kind = $key.GetValueKind($Name).ToString()
            $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
        return [pscustomobject]@{ Hive=$Hive; Path=$Path; Name=$Name; Exists=$exists; Kind=$kind; Value=$value }
    } finally { if ($null -ne $key) { $key.Dispose() } }
}

function Remember-RegistryValue([string]$Hive, [string]$Path, [string]$Name) {
    $known = @($script:State.Registry | Where-Object { $_.Hive -eq $Hive -and $_.Path -eq $Path -and $_.Name -eq $Name })
    if ($known.Count -eq 0) {
        $script:State.Registry = @($script:State.Registry) + @(Read-RegistryValue $Hive $Path $Name)
        Save-State
    }
}

function Write-RegistryValue([string]$Hive, [string]$Path, [string]$Name, $Value, [string]$Kind) {
    $key = (Get-RegistryBase $Hive).CreateSubKey($Path)
    try {
        $type = [Microsoft.Win32.RegistryValueKind]::$Kind
        switch ($Kind) {
            'DWord' { $Value = [int]$Value }
            'QWord' { $Value = [long]$Value }
            'Binary' { $Value = [byte[]]$Value }
            'MultiString' { $Value = [string[]]$Value }
            default { $Value = [string]$Value }
        }
        $key.SetValue($Name, $Value, $type)
    } finally { $key.Dispose() }
}

function Set-BackedUpDword([string]$Hive, [string]$Path, [string]$Name, [int]$Value) {
    Remember-RegistryValue $Hive $Path $Name
    Write-RegistryValue $Hive $Path $Name $Value 'DWord'
    $actual = Read-RegistryValue $Hive $Path $Name
    if (-not $actual.Exists -or [int]$actual.Value -ne $Value) { throw "Verification failed: $Path\$Name" }
}

function Restore-RegistryValue($Record) {
    if ($Record.Exists) {
        Write-RegistryValue $Record.Hive $Record.Path $Record.Name $Record.Value $Record.Kind
    } else {
        $key = (Get-RegistryBase $Record.Hive).OpenSubKey($Record.Path, $true)
        try { if ($null -ne $key) { $key.DeleteValue($Record.Name, $false) } }
        finally { if ($null -ne $key) { $key.Dispose() } }
    }
    $actual = Read-RegistryValue $Record.Hive $Record.Path $Record.Name
    if ($actual.Exists -ne $Record.Exists) { throw 'Registry existence verification failed.' }
    if ($Record.Exists -and ($actual.Kind -ne $Record.Kind -or
        (ConvertTo-Json -InputObject $actual.Value -Compress) -ne (ConvertTo-Json -InputObject $Record.Value -Compress))) {
        throw 'Registry value verification failed.'
    }
}

function Set-PlanValue([string]$Plan, [string]$Group, [string]$Setting, [int]$Value, [switch]$Optional) {
    try {
        # /qh includes hidden settings. GUID matching avoids localized setting names.
        $query = Invoke-Native 'powercfg.exe' @('/qh', $Plan, $Group)
        if ($query -notmatch [regex]::Escape($Setting)) { throw 'This power setting is unavailable.' }
        $null = Invoke-Native 'powercfg.exe' @('/setacvalueindex', $Plan, $Group, $Setting, "$Value")
        $updated = Invoke-Native 'powercfg.exe' @('/qh', $Plan, $Group)
        $blocks = $updated -split [regex]::Escape($Setting)
        if ($blocks.Count -lt 2) { throw 'Updated setting was not found.' }
        # A setting's last two 0x values are its AC and DC indexes, in every UI language.
        $block = ($blocks[1] -split '(?im)^\s*[^\r\n]*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')[0]
        $indexes = [regex]::Matches($block, '0x([0-9a-fA-F]+)')
        if ($indexes.Count -lt 2 -or [Convert]::ToInt32($indexes[$indexes.Count-2].Groups[1].Value,16) -ne $Value) {
            throw 'Could not verify the AC power setting.'
        }
        Write-Host "Set and verified $Setting = $Value (AC only)."
    } catch {
        if ($Optional) { Write-Warning ("Optional setting skipped/unverified: {0}. {1}" -f $Setting, $_.Exception.Message) }
        else { throw }
    }
}

function Ensure-Plan([string]$Mode) {
    Assert-Admin
    if ($null -eq $script:State.OriginalPowerScheme) {
        $script:State.OriginalPowerScheme = Get-PowerGuid
        Save-State
    }
    $entry = @($script:State.CreatedPowerSchemes | Where-Object { $_.Mode -eq $Mode }) | Select-Object -First 1
    if ($null -eq $entry) {
        $entry = [pscustomobject]@{ Mode=$Mode; Id=[guid]::NewGuid().ToString(); Created=$false }
        $script:State.CreatedPowerSchemes = @($script:State.CreatedPowerSchemes) + @($entry)
        Save-State
    }
    if (-not $entry.Created) {
        $list = Invoke-Native 'powercfg.exe' @('/list')
        if ($list -notmatch [regex]::Escape($entry.Id)) {
            # Existing schemes are never overwritten, including your original plan.
            $source = $script:BalancedGuid
            if ($Mode -eq 'CoD-High-FPS') { $source = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
            $null = Invoke-Native 'powercfg.exe' @('/duplicatescheme', $source, $entry.Id)
        }
        $entry.Created = $true
        Save-State
    }
    $null = Invoke-Native 'powercfg.exe' @('/changename', $entry.Id, "PCOPT $Mode experiment")
    return $entry.Id
}

function Apply-PowerPlan([string]$Mode) {
    Assert-Admin
    if ($Mode -eq 'Aggressive') {
        Write-Host 'Experiment: 100% CPU minimum and no core parking. Increased power/heat; may worsen throttling.'
    } else {
        Write-Host 'Experiment: cloned Balanced plan, 5% CPU minimum, 100% maximum, performance-first EPP if supported.'
    }
    if (-not (Confirm-Action 'Create/activate this separate AC power plan?')) { return }
    $plan = Ensure-Plan $Mode
    $minimum = 5
    if ($Mode -eq 'Aggressive') { $minimum = 100 }
    Set-PlanValue $plan $script:CpuGroup $script:CpuMin $minimum
    Set-PlanValue $plan $script:CpuGroup $script:CpuMax 100
    Set-PlanValue $plan $script:CpuGroup $script:Epp 0 -Optional
    if ($Mode -eq 'Aggressive') { Set-PlanValue $plan $script:CpuGroup $script:ParkingMin 100 -Optional }
    $null = Invoke-Native 'powercfg.exe' @('/setactive', $plan)
    if ((Get-PowerGuid) -ne $plan) { throw 'Plan activation verification failed.' }
    Write-Host 'Plan activated. Compare repeated game benchmarks with the original plan; keep it only if it helps.'
}

function Apply-GameMode {
    Assert-Admin
    if (-not (Confirm-Action 'Enable Windows Game Mode for this Windows account?')) { return }
    Set-BackedUpDword 'HKCU' 'Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Write-Host 'Game Mode preference saved and read back. Verify the switch in the Windows settings page.'
    Open-Settings 'ms-settings:gaming-gamemode'
}

function Disable-BackgroundCapture {
    Assert-Admin
    Write-Host 'Turns off Xbox game recording preferences, including background capture. Manual Xbox clips may also be unavailable.'
    Write-Host 'OBS and NVIDIA recording are separate.'
    if (-not (Confirm-Action 'Apply this recording preference?')) { return }
    Set-BackedUpDword 'HKCU' 'Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-BackedUpDword 'HKCU' 'System\GameConfigStore' 'GameDVR_Enabled' 0
    Write-Host 'Preferences saved and read back. Verify recording is off in Captures; restart the game.'
    Open-Settings 'ms-settings:gaming-gamedvr'
}

function Apply-CodHighFps {
    Assert-Admin
    Write-Host 'Call of Duty high-FPS Windows preset:'
    Write-Host '  Separate High Performance-based AC plan; CPU minimum 5%, maximum 100%; performance EPP if available.'
    Write-Host '  Game Mode on; Xbox game recording off, including background clips. Manual Xbox clips may also be unavailable.'
    Write-Host '  Increased power/heat is possible.'
    Write-Host '  In-game DLSS, Reflex, resolution, VRAM and NVIDIA settings still need the CoD checklist in GUIDE.md.'
    Write-Host '  This is an experiment, not a guaranteed FPS increase. No CPU overclock or security changes.'
    if (-not (Confirm-Action 'Apply the backed-up Call of Duty high-FPS preset?')) { return }
    $plan = Ensure-Plan 'CoD-High-FPS'
    Set-PlanValue $plan $script:CpuGroup $script:CpuMin 5
    Set-PlanValue $plan $script:CpuGroup $script:CpuMax 100
    Set-PlanValue $plan $script:CpuGroup $script:Epp 0 -Optional
    Set-BackedUpDword 'HKCU' 'Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-BackedUpDword 'HKCU' 'Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-BackedUpDword 'HKCU' 'System\GameConfigStore' 'GameDVR_Enabled' 0
    $null = Invoke-Native 'powercfg.exe' @('/setactive', $plan)
    if ((Get-PowerGuid) -ne $plan) { throw 'CoD plan activation verification failed.' }
    Write-Host 'Windows portion applied and read back. Restart the game; check Game Mode and Captures in Windows settings.'
    Write-Host 'Apply the manual CoD/NVIDIA checklist, then compare multiple warm benchmark runs.'
}

function Initialize-MouseApi {
    if ($null -eq ('PcOptNativeMouse' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PcOptNativeMouse {
    [DllImport("user32.dll", SetLastError=true, EntryPoint="SystemParametersInfoW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool Spi(uint action, uint param, [In, Out] int[] data, uint flags);
}
'@
    }
}

function Get-MouseState {
    Initialize-MouseApi
    $data = New-Object int[] 3
    if (-not [PcOptNativeMouse]::Spi(3, 0, $data, 0)) { throw 'SPI_GETMOUSE failed.' }
    return $data
}

function Set-MouseState([int[]]$Data) {
    Initialize-MouseApi
    if (-not [PcOptNativeMouse]::Spi(4, 0, $Data, 3)) { throw 'SPI_SETMOUSE failed.' }
    $actual = Get-MouseState
    if (($actual -join ',') -ne ($Data -join ',')) { throw 'Mouse state verification failed.' }
}

function Disable-MouseAcceleration {
    Assert-Admin
    Write-Host 'Turns off Windows pointer acceleration. Games using raw mouse input generally ignore this setting.'
    if (-not (Confirm-Action 'Apply this desktop pointer preference?')) { return }
    if ($null -eq $script:State.Mouse) {
        $script:State.Mouse = [pscustomobject]@{ Data=@(Get-MouseState) }
        Save-State
    }
    Set-MouseState ([int[]]@(0,0,0))
    Write-Host 'Pointer acceleration disabled and verified. Mouse sensitivity is unchanged.'
}

function Apply-NicExperiment {
    Assert-Admin
    $adapters = @(Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' })
    if ($adapters.Count -eq 0) { throw 'No active physical network adapter found.' }
    for ($i=0; $i -lt $adapters.Count; $i++) {
        Write-Host ("{0}: {1} / {2}" -f ($i+1), $adapters[$i].Name, $adapters[$i].InterfaceDescription)
    }
    $number = 0
    if (-not [int]::TryParse((Read-Host 'Adapter number, or Enter to cancel'), [ref]$number)) { return }
    if ($number -lt 1 -or $number -gt $adapters.Count) { throw 'Invalid adapter number.' }
    $adapter = $adapters[$number-1]
    $property = @(Get-NetAdapterAdvancedProperty -Name $adapter.Name -AllProperties |
        Where-Object { $_.RegistryKeyword -eq '*InterruptModeration' }) | Select-Object -First 1
    if ($null -eq $property) { throw 'Driver does not expose the standardized *InterruptModeration property. No changes made.' }
    Write-Host 'Disabling NIC interrupt moderation can reduce local packet latency, but raises interrupt/CPU load.'
    Write-Host 'It does not shorten the Internet route or fix bufferbloat. Adapter restart or Windows restart is needed.'
    if (-not (Confirm-Action ('Save the original value and disable moderation on ' + $adapter.Name + '?'))) { return }
    $guid = $adapter.InterfaceGuid.ToString()
    $known = @($script:State.NicChanges | Where-Object { $_.InterfaceGuid -eq $guid })
    if ($known.Count -eq 0) {
        $script:State.NicChanges = @($script:State.NicChanges) + @([pscustomobject]@{
            InterfaceGuid=$guid; Name=$adapter.Name; Keyword='*InterruptModeration'; Value=@($property.RegistryValue)
        })
        Save-State
    }
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword '*InterruptModeration' -RegistryValue @('0') -NoRestart
    $actual = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword '*InterruptModeration'
    if ((@($actual.RegistryValue) -join ',') -ne '0') { throw 'NIC property read-back verification failed.' }
    Write-Host 'Driver preference saved and verified. Restart Windows to activate; network settings were not reset.'
}

function Apply-PeripheralExperiment {
    Assert-Admin
    Write-Host 'Troubleshooting experiment: disable USB selective suspend and PCIe link power saving in a separate AC plan.'
    Write-Host 'Useful for reproducible device wake/dropout issues. No guaranteed FPS or mouse-latency improvement.'
    if (-not (Confirm-Action 'Create/activate this peripheral power experiment?')) { return }
    $plan = Ensure-Plan 'Peripheral'
    Set-PlanValue $plan '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' 0 -Optional
    Set-PlanValue $plan '501a4d13-42af-4429-9fd1-a8218c268e20' 'ee12f906-d277-404b-b6da-e5fa1a576df5' 0 -Optional
    $null = Invoke-Native 'powercfg.exe' @('/setactive', $plan)
    if ((Get-PowerGuid) -ne $plan) { throw 'Peripheral plan activation verification failed.' }
    Write-Host 'Peripheral experiment plan activated. It is independent of the CPU experiments.'
}

function Open-Settings([string]$Uri) {
    try { Start-Process $Uri }
    catch { Write-Warning ('Could not open ' + $Uri + '. Navigate there manually in Settings.') }
}

function Open-GraphicsSettings {
    Write-Host 'HAGS: test On versus Off, reboot after each change. RTX 3080 supports it with a compatible driver.'
    Write-Host 'There is no universal winner. Fullscreen optimizations should stay at default unless a specific game improves without them.'
    Write-Host 'NVIDIA Reflex belongs in each supported game; prefer per-game NVIDIA Control Panel profiles.'
    Open-Settings 'ms-settings:display-advancedgraphics'
    Write-Host "Manual settings changes are not included in this tool's undo backup."
}

function Open-UsefulSettings {
    Write-Host '1 Display/refresh rate  2 Startup apps  3 Captures  4 Game Mode  5 Mouse  6 Virtual memory'
    switch (Read-Host 'Page number, or Enter to cancel') {
        '1' { Open-Settings 'ms-settings:display-advanced' }
        '2' { Open-Settings 'ms-settings:startupapps' }
        '3' { Open-Settings 'ms-settings:gaming-gamedvr' }
        '4' { Open-Settings 'ms-settings:gaming-gamemode' }
        '5' { Start-Process 'main.cpl' }
        '6' { Start-Process 'SystemPropertiesAdvanced.exe' }
    }
    Write-Host 'Manual settings changes are not included in the undo backup.'
}

function Find-NvidiaSmi {
    $command = Get-Command 'nvidia-smi.exe' -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    $path = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
    if (Test-Path -LiteralPath $path) { return $path }
    return $null
}

function Write-Audit {
    $file = Join-Path $script:Root ('audit-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('Local PC audit: ' + (Get-Date -Format o))
    function Add-Section([string]$Name, [scriptblock]$Query) {
        $lines.Add("`r`n=== $Name ===")
        try { $lines.Add(((& $Query) | Out-String -Width 220)) }
        catch { $lines.Add('Unavailable: ' + $_.Exception.Message) }
    }
    Add-Section 'Windows' {
        Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime
        Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Select-Object DisplayVersion, CurrentBuildNumber, UBR
    }
    Add-Section 'CPU and motherboard' {
        Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
        Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product, Version
        Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion, ReleaseDate
    }
    Add-Section 'Memory: actual configured clocks from firmware' {
        Get-CimInstance Win32_PhysicalMemory | Select-Object DeviceLocator, BankLabel, Capacity, Speed, ConfiguredClockSpeed, Manufacturer, PartNumber
        Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory, AutomaticManagedPagefile
        Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage
    }
    Add-Section 'GPU and driver' {
        Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate
        $smi = Find-NvidiaSmi
        if ($null -ne $smi) { Invoke-Native $smi @('--query-gpu=name,driver_version,memory.total,temperature.gpu,power.draw,power.limit', '--format=csv') }
    }
    Add-Section 'Storage and free space' {
        Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, HealthStatus, Size
        Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystem, HealthStatus, Size, SizeRemaining
        Get-Disk | Select-Object Number, FriendlyName, PartitionStyle, IsSystem, IsBoot
        Invoke-Native 'fsutil.exe' @('behavior','query','DisableDeleteNotify')
    }
    Add-Section 'Power: active plan and hidden CPU settings' {
        Invoke-Native 'powercfg.exe' @('/getactivescheme')
        Invoke-Native 'powercfg.exe' @('/list')
        Invoke-Native 'powercfg.exe' @('/qh', 'SCHEME_CURRENT', $script:CpuGroup)
    }
    Add-Section 'Gaming preferences (missing means Windows default, not necessarily off)' {
        Read-RegistryValue 'HKCU' 'Software\Microsoft\GameBar' 'AutoGameModeEnabled'
        Read-RegistryValue 'HKCU' 'Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
        Read-RegistryValue 'HKCU' 'System\GameConfigStore' 'GameDVR_Enabled'
        Read-RegistryValue 'HKLM' 'SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
        Read-RegistryValue 'HKLM' 'SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR'
    }
    Add-Section 'Boot configuration: inspect only; timer overrides are not modified' {
        Invoke-Native 'bcdedit.exe' @('/enum','{current}')
    }
    Add-Section 'Network settings: inspect only' {
        Get-NetAdapter -Physical | Select-Object Name, InterfaceDescription, Status, LinkSpeed, DriverVersion
        Get-NetAdapterRss -ErrorAction SilentlyContinue | Select-Object Name, Enabled, NumberOfReceiveQueues
        Get-NetAdapterAdvancedProperty -Name '*' -AllProperties -ErrorAction SilentlyContinue |
            Where-Object { $_.RegistryKeyword -match 'InterruptModeration|EEE|Energy|Green|Rss' } |
            Select-Object Name, DisplayName, DisplayValue, RegistryKeyword, RegistryValue
        Invoke-Native 'netsh.exe' @('int','tcp','show','global')
    }
    Add-Section 'Startup entries: names only, no command lines' {
        Get-CimInstance Win32_StartupCommand | Select-Object Name, Location
    }
    Add-Section 'Current process CPU-time totals: not live CPU utilization' {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 ProcessName, CPU, WorkingSet64
    }
    $lines | Set-Content -LiteralPath $file -Encoding UTF8
    Write-Host "Audit saved: $file"
    Write-Host 'Refresh-rate and memory firmware reports can be incomplete. Confirm Gear mode, channels and XMP in BIOS/CPU-Z.'
    if (Confirm-Action 'Open the local report?') { Start-Process 'notepad.exe' -ArgumentList ('"' + $file + '"') }
}

function Run-Diagnostics {
    Assert-Admin
    Write-Host 'These are troubleshooting checks, not FPS optimizations. They may take several minutes.'
    if (-not (Confirm-Action 'Run DISM ScanHealth, SFC verify-only, and system-drive storage analysis?')) { return }
    $file = Join-Path $script:Root ('diagnostics-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
    $commands = @(
        @{Exe='dism.exe'; Args=@('/Online','/Cleanup-Image','/ScanHealth')},
        @{Exe='sfc.exe'; Args=@('/verifyonly')},
        @{Exe='defrag.exe'; Args=@($env:SystemDrive,'/A','/V')}
    )
    foreach ($command in $commands) {
        try {
            $result = Invoke-Native $command.Exe $command.Args -ShowOutput
            Add-Content -LiteralPath $file -Value ($command.Exe + "`r`n" + $result) -Encoding UTF8
        } catch {
            Add-Content -LiteralPath $file -Value $_.Exception.Message -Encoding UTF8
            Write-Warning $_.Exception.Message
        }
    }
    Write-Host "Diagnostic output saved: $file. Review each tool's findings; completion alone does not mean no issues."
}

function Record-GpuTelemetry {
    $smi = Find-NvidiaSmi
    if ($null -eq $smi) { throw 'nvidia-smi not found. Install an official NVIDIA driver; this script installs no drivers.' }
    $file = Join-Path $script:Root ('gpu-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv')
    Write-Host 'Start/switch to the game now. Collecting 60 one-second samples; this is not an FPS or input-latency benchmark.'
    $query = '--query-gpu=timestamp,name,temperature.gpu,utilization.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory'
    for ($i=0; $i -lt 60; $i++) {
        $format = '--format=csv,noheader'
        if ($i -eq 0) { $format = '--format=csv' }
        $line = Invoke-Native $smi @($query,$format)
        Add-Content -LiteralPath $file -Value $line -Encoding UTF8
        Start-Sleep -Seconds 1
    }
    Write-Host "GPU telemetry saved: $file. Use HWiNFO for CPU temperatures/throttling and PresentMon for frame times."
}

function Restore-All {
    Assert-Admin
    Write-Host 'Restores the original values saved by this tool. BIOS, NVIDIA profiles and manual Settings changes are separate.'
    if (-not (Confirm-Action 'Undo all recorded tool changes?')) { return }
    $problems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($record in @($script:State.Registry)) {
        try { Restore-RegistryValue $record }
        catch { $problems.Add($record.Path + '\' + $record.Name + ': ' + $_.Exception.Message) }
    }
    if ($null -ne $script:State.Mouse) {
        try { Set-MouseState ([int[]]$script:State.Mouse.Data) }
        catch { $problems.Add('Mouse: ' + $_.Exception.Message) }
    }
    foreach ($record in @($script:State.NicChanges)) {
        try {
            $adapter = @(Get-NetAdapter -Physical | Where-Object { $_.InterfaceGuid.ToString() -eq $record.InterfaceGuid }) | Select-Object -First 1
            if ($null -eq $adapter) { throw 'Original network adapter is unavailable.' }
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $record.Keyword -RegistryValue ([string[]]$record.Value) -NoRestart
            $actual = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $record.Keyword
            if ((@($actual.RegistryValue) -join ',') -ne (@($record.Value) -join ',')) { throw 'NIC restore verification failed.' }
        } catch { $problems.Add('NIC ' + $record.Name + ': ' + $_.Exception.Message) }
    }
    $powerRestored = $true
    if ($null -ne $script:State.OriginalPowerScheme) {
        try {
            $null = Invoke-Native 'powercfg.exe' @('/setactive', $script:State.OriginalPowerScheme)
            if ((Get-PowerGuid) -ne $script:State.OriginalPowerScheme) { throw 'Original plan read-back failed.' }
        } catch {
            $powerRestored = $false
            $problems.Add('Original power plan: ' + $_.Exception.Message)
        }
    }
    if ($powerRestored) {
        foreach ($plan in @($script:State.CreatedPowerSchemes)) {
            try {
                $list = Invoke-Native 'powercfg.exe' @('/list')
                if ($list -match [regex]::Escape($plan.Id)) { $null = Invoke-Native 'powercfg.exe' @('/delete', $plan.Id) }
                $list = Invoke-Native 'powercfg.exe' @('/list')
                if ($list -match [regex]::Escape($plan.Id)) { throw 'Plan still exists after deletion.' }
            } catch { $problems.Add('Tool power plan ' + $plan.Id + ': ' + $_.Exception.Message) }
        }
    }
    if ($problems.Count -gt 0) {
        $problems | ForEach-Object { Write-Warning $_ }
        Write-Warning 'Undo is incomplete. Backup kept; fix the listed issues and retry option 13.'
    } else {
        $archive = Join-Path $script:Root ('restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.json')
        Move-Item -LiteralPath $script:StatePath -Destination $archive
        $script:State = New-State
        Save-State
        Write-Host 'Recorded settings restored and verified. Backup archived. Restart Windows for NIC/capture changes.'
    }
}

function New-State {
    return [pscustomobject]@{
        SchemaVersion=1; Machine=$env:COMPUTERNAME; UserSid=$script:UserSid
        CapturedUtc=[DateTime]::UtcNow.ToString('o'); Registry=@(); Mouse=$null
        OriginalPowerScheme=$null; CreatedPowerSchemes=@(); NicChanges=@()
    }
}

# MAIN_START
try {
    if ($env:OS -ne 'Windows_NT') { throw 'This batch tool must run on Windows.' }
    if (-not [Environment]::Is64BitProcess) { throw 'Run from 64-bit Windows Explorer or a 64-bit command prompt.' }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $script:UserSid = $identity.User.Value
    $script:IsAdmin = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $os = Get-CimInstance Win32_OperatingSystem
    if ([int]$os.BuildNumber -ne 19045) { throw 'This version targets Windows 10 22H2, build 19045. No settings changed.' }
    $script:Root = Join-Path $env:LOCALAPPDATA 'PC-Competitive-Tuning'
    $null = New-Item -ItemType Directory -Path $script:Root -Force
    $script:StatePath = Join-Path $script:Root 'backup.json'
    $script:BalancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
    $script:CpuGroup = '54533251-82be-4824-96c1-47b60b740d00'
    $script:CpuMin = '893dee8e-2bef-41e0-89c6-b55d0929964c'
    $script:CpuMax = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
    $script:Epp = '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'
    $script:ParkingMin = '0cc5b647-c1df-4637-891a-dec35c318583'
    if (Test-Path -LiteralPath $script:StatePath) {
        $script:State = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
        if ($script:State.SchemaVersion -ne 1 -or $script:State.Machine -ne $env:COMPUTERNAME -or $script:State.UserSid -ne $script:UserSid) {
            throw 'Backup belongs to another machine/account or has an unsupported format. Do not overwrite it.'
        }
    } else { $script:State = New-State; Save-State }
    Write-Host 'Windows 10 build 19045 competitive tuning - i9-11900K / RTX 3080 / 64 GB'
    Write-Host 'Use your usual Windows account. Each change asks before applying; Enter means no.'
    Write-Host 'Read GUIDE.md for BIOS, NVIDIA, display settings, evidence and measurement instructions.'
    Write-Host ('Local backup/report folder: ' + $script:Root)
    while ($true) {
        Write-Host ''
        Write-Host ' 1  Audit hardware, drivers, memory, power, storage, network and existing timer tweaks'
        Write-Host ' 2  Moderate CPU power experiment: minimum 5%, maximum 100%, performance EPP'
        Write-Host ' 3  Aggressive CPU experiment: minimum 100%, no core parking (more heat)'
        Write-Host ' 4  Enable Game Mode for this account'
        Write-Host ' 5  Turn off Xbox game recording, including background clips'
        Write-Host ' 6  Turn off desktop mouse acceleration (raw-input games usually unaffected)'
        Write-Host ' 7  Network interrupt-moderation experiment (restart required)'
        Write-Host ' 8  USB/PCIe idle-power troubleshooting experiment'
        Write-Host ' 9  Open graphics settings for manual HAGS testing'
        Write-Host '10  Open refresh-rate / startup / capture / mouse / page-file settings'
        Write-Host '11  Optional Windows/storage diagnostic checks (no automatic repairs)'
        Write-Host '12  Record 60 seconds of NVIDIA GPU telemetry while gaming'
        Write-Host '13  UNDO all changes made by this tool'
        Write-Host '14  Switch back to the original power plan without undoing other settings'
        Write-Host '15  CALL OF DUTY HIGH-FPS preset (power plan + Game Mode + capture preferences)'
        Write-Host ' 0  Exit'
        try {
            switch (Read-Host 'Choose an option') {
                '1' { Write-Audit }
                '2' { Apply-PowerPlan 'Moderate' }
                '3' { Apply-PowerPlan 'Aggressive' }
                '4' { Apply-GameMode }
                '5' { Disable-BackgroundCapture }
                '6' { Disable-MouseAcceleration }
                '7' { Apply-NicExperiment }
                '8' { Apply-PeripheralExperiment }
                '9' { Open-GraphicsSettings }
                '10' { Open-UsefulSettings }
                '11' { Run-Diagnostics }
                '12' { Record-GpuTelemetry }
                '13' { Restore-All }
                '14' {
                    Assert-Admin
                    if ($null -eq $script:State.OriginalPowerScheme) { Write-Host 'No original power plan has been recorded yet.' }
                    else {
                        $null = Invoke-Native 'powercfg.exe' @('/setactive', $script:State.OriginalPowerScheme)
                        if ((Get-PowerGuid) -ne $script:State.OriginalPowerScheme) { throw 'Original plan activation failed.' }
                        Write-Host 'Original power plan active. Experiment plans remain available for comparison.'
                    }
                }
                '15' { Apply-CodHighFps }
                '0' { exit 0 }
                default { Write-Host 'Choose a listed option.' }
            }
        } catch {
            Write-Warning $_.Exception.Message
            Write-Host 'Successful earlier changes may remain applied. Option 13 restores recorded changes.'
        }
    }
} catch {
    Write-Host ('Error: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
