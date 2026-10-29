🧾 Usage

```powershell
refresh-rate-setter.exe --D1=240
refresh-rate-setter.exe --D1=144 --D2=60
refresh-rate-setter.exe --D1=240 --D2=144 --force
```

 • --D<N>=<Hz> — set refresh rate for display N (starting from 1)
 
 • --force — apply changes without waiting for confirmation

```shell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/GoHo-DohJi/refresh-rate-setter/main/RUN.ps1"))) -D1=240 -f
```


```
# Refresh Rate Setter

Change display refresh rates on Windows directly from PowerShell — no installation required.

## Quick Start

Open **PowerShell as Administrator** and run:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/GoHo-DohJi/refresh-rate-setter/main/RUN.ps1"))) -D1=240
```

> [!NOTE]
> Administrator privileges are required. The script will prompt you if not elevated when run as a local `.ps1` file. For `irm | iex`, open PowerShell as Admin beforehand.

## Usage

```powershell
$url = "https://raw.githubusercontent.com/GoHo-DohJi/refresh-rate-setter/main/RUN.ps1"
$run = [scriptblock]::Create((irm $url))

# Set refresh rate for a single display
& $run -D1=240

# Set multiple displays
& $run -D1=240 -D2=144

# Apply without confirmation prompt
& $run -D1=240 -D2=144 -f

# List all displays and available refresh rates
& $run -l
```

## Arguments

| Flag | Description |
|------|-------------|
| `-D<N>=<Hz>` | Set refresh rate for display N (e.g. `-D1=240`, `-D2=144`) |
| `-f`, `--force` | Apply changes permanently, skip 10-second confirmation |
| `-l`, `--list` | List all active displays and their available refresh rates |

Multiple `-D` flags can be combined in a single command.

## How It Works

1. Reads the current display mode via `EnumDisplaySettingsW`
2. Applies the requested refresh rate via `ChangeDisplaySettingsExW`
3. Waits **10 seconds** for you to press **Enter** to confirm
4. If no confirmation — automatically **reverts** all changes

The `-f` flag skips step 3–4 and keeps changes immediately.

## List Output Example

```
=== DISPLAY1 ===
Adapter:  NVIDIA GeForce RTX 4070
Current:  2560x1440 @ 240 Hz (32-bit)
Available:
  1920x1080    -> 60, 120, 144, 240 Hz
  2560x1440    -> 60, 120, 144, 165, 180, 200, 240 Hz

=== DISPLAY2 ===
Adapter:  NVIDIA GeForce RTX 4070
Current:  1920x1080 @ 144 Hz (32-bit)
Available:
  1920x1080    -> 50, 60, 100, 120, 144 Hz
```

## Requirements

- Windows 10 / 11
- PowerShell 5.1+ (built-in)
- Administrator privileges

## License

MIT
```
