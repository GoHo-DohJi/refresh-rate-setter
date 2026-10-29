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
