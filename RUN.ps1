# Self-Elevate #
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($PSCommandPath) {
        $argList = ($args | ForEach-Object { "`"$_`"" }) -join " "
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $argList" -Verb RunAs
    } else {
        Write-Host "Run PowerShell as Administrator first." -ForegroundColor Red
    }
    return
}

# P/Invoke #
try { [RR.Display] | Out-Null } catch {
    Add-Type -TypeDefinition @"
namespace RR {
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion;  public short dmDriverVersion;
    public short dmSize;         public short dmDriverExtra;
    public int   dmFields;       public int   dmPositionX;
    public int   dmPositionY;    public int   dmDisplayOrientation;
    public int   dmDisplayFixedOutput;
    public short dmColor;        public short dmDuplex;
    public short dmYResolution;  public short dmTTOption;
    public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels;    public int   dmBitsPerPel;
    public int   dmPelsWidth;    public int   dmPelsHeight;
    public int   dmDisplayFlags; public int   dmDisplayFrequency;
    public int   dmICMMethod;    public int   dmICMIntent;
    public int   dmMediaType;    public int   dmDitherType;
    public int   dmReserved1;    public int   dmReserved2;
    public int   dmPanningWidth; public int   dmPanningHeight;
}

public class Display {
    public const int ENUM_CURRENT_SETTINGS  = -1;
    public const int DM_DISPLAYFREQUENCY    = 0x00400000;
    public const int CDS_UPDATEREGISTRY     = 1;
    public const int DISP_CHANGE_SUCCESSFUL = 0;

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplaySettingsW(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int ChangeDisplaySettingsExW(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, int dwflags, IntPtr lParam);
}
}
"@
}

# Parse Arguments #
$targets = @{}
$force = $false
$list  = $false

foreach ($a in $args) {
    if ($a -match "^-{1,2}f(orce)?$") {
        $force = $true
    } elseif ($a -match "^-{1,2}l(ist)?$") {
        $list = $true
    } elseif ($a -match "^-{1,2}D(\d+)=(\d+)$") {
        $targets[[int]$Matches[1]] = [int]$Matches[2]
    }
}

# List Mode #
if ($list) {
    $adapters = @((Get-CimInstance -ClassName "Win32_VideoController").Name)
    $index = 1
    while ($index -le 10) {
        $device  = "\\.\DISPLAY$index"
        $current = New-Object RR.DEVMODE
        $current.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($current)

        if (-not [RR.Display]::EnumDisplaySettingsW($device, [RR.Display]::ENUM_CURRENT_SETTINGS, [ref]$current)) {
            $index++
            continue
        }
        if ($current.dmPelsWidth -eq 0) {
            $index++
            continue
        }

        $adapterName = if ($index -le $adapters.Count) { $adapters[$index - 1] } else { $adapters[0] }

        Write-Host ""
        Write-Host "=== DISPLAY$index ===" -ForegroundColor Cyan
        Write-Host "Adapter:  $adapterName"
        Write-Host "Current:  $($current.dmPelsWidth)x$($current.dmPelsHeight) @ $($current.dmDisplayFrequency) Hz ($($current.dmBitsPerPel)-bit)"
        Write-Host "Available:" -ForegroundColor Yellow

        $modes = @()
        $i = 0
        while ($true) {
            $m = New-Object RR.DEVMODE
            $m.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($m)
            if (-not [RR.Display]::EnumDisplaySettingsW($device, $i, [ref]$m)) { break }
            $modes += [PSCustomObject]@{
                Width  = $m.dmPelsWidth
                Height = $m.dmPelsHeight
                Hz     = $m.dmDisplayFrequency
                Bits   = $m.dmBitsPerPel
            }
            $i++
        }

        $modes |
            Sort-Object -Property Width, Height, Hz, Bits -Unique |
            Group-Object -Property Width, Height |
            ForEach-Object {
                $res   = "$($_.Group[0].Width)x$($_.Group[0].Height)"
                $rates = ($_.Group.Hz | Sort-Object -Unique) -join ", "
                "  {0,-12} -> {1} Hz" -f $res, $rates
            }

        $index++
    }
    return
}

# Apply Mode #
if ($targets.Count -eq 0) {
    Write-Host "Usage: script.ps1 -D1=240 [-D2=144] [-f] [-l]"
    return
}

$states = @()

foreach ($index in ($targets.Keys | Sort-Object)) {
    $hz     = $targets[$index]
    $device = "\\.\DISPLAY$index"
    $mode   = New-Object RR.DEVMODE
    $mode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mode)

    if (-not [RR.Display]::EnumDisplaySettingsW($device, [RR.Display]::ENUM_CURRENT_SETTINGS, [ref]$mode)) {
        Write-Host "Failed to read current mode for $device"
        continue
    }

    $original = $mode
    $mode.dmFields = [RR.Display]::DM_DISPLAYFREQUENCY
    $mode.dmDisplayFrequency = $hz

    if ([RR.Display]::ChangeDisplaySettingsExW($device, [ref]$mode, [IntPtr]::Zero, [RR.Display]::CDS_UPDATEREGISTRY, [IntPtr]::Zero) -ne [RR.Display]::DISP_CHANGE_SUCCESSFUL) {
        Write-Host "Failed to apply $hz Hz to $device"
        continue
    }

    Write-Host "Applied $hz Hz to $device"
    $states += [PSCustomObject]@{ Device = $device; Mode = $original }
}

if ($states.Count -eq 0) {
    Write-Host "No changes applied."
    return
}

if ($force) {
    Write-Host "Force flag set. Changes kept."
    return
}

# Confirm or Revert #
Write-Host "`nKeep changes? Press ENTER within 10 seconds..."
$confirmed = $false
$deadline  = (Get-Date).AddSeconds(10)

while ((Get-Date) -lt $deadline) {
    if ([Console]::KeyAvailable) {
        [Console]::ReadLine() | Out-Null
        $confirmed = $true
        break
    }
    Start-Sleep -Milliseconds 100
}

if ($confirmed) {
    Write-Host "Changes confirmed."
} else {
    Write-Host "Reverting changes..."
    foreach ($state in $states) {
        [RR.Display]::ChangeDisplaySettingsExW($state.Device, [ref]$state.Mode, [IntPtr]::Zero, [RR.Display]::CDS_UPDATEREGISTRY, [IntPtr]::Zero) | Out-Null
    }
    Write-Host "All displays restored."
}
