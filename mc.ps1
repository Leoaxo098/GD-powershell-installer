# ==========================================================
# Minecraft Installer (.7z) - Fully Automated with 7zr.exe
# ==========================================================

# -------- User variables --------
$files = @{
    "1" = @{ Name="Launcher Only"; Id="1NX8QmMpWqOmyED2SmuKxZiK_8bpc3Gny"; SizeMB=50 }
    "2" = @{ Name="Preinstalled (Full)"; Id="1uJZHsLYTuve0JRW6UNLLGDp7Fb1gJfk_"; SizeMB=1200 }
}
$gameExeName = "prismlauncher.exe"

# -------- Internal paths --------
$tempFolder = [System.IO.Path]::GetTempPath().TrimEnd('\')
$downloadPath = Join-Path $tempFolder "minecraft_download.7z"
$extractPath = Join-Path $tempFolder ("minecraft_extracted_{0}" -f ([System.Guid]::NewGuid().ToString("N")))
$downloadsFolder = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

# Portable 7-Zip Extra (.7z)
$portable7zUrl = "https://www.7-zip.org/a/7z2301-extra.7z"
$sevenZip7zPath = Join-Path $tempFolder "7zip_extra.7z"
$sevenZipExtractPath = Join-Path $tempFolder "7zip"
$sevenZipExe = Join-Path $sevenZipExtractPath "7za.exe"

# Minimal 7zr.exe
$sevenZr = Join-Path $tempFolder "7zr.exe"
$sevenZrUrl = "https://www.7-zip.org/a/7zr.exe"

# -------- Helpers --------
function Throttled-WriteProgress {
    param([string]$Activity,[string]$Status,[int]$Percent,[ref]$LastUpdateTime,[int]$MinMs=400)
    $now = [DateTime]::UtcNow
    if (($LastUpdateTime.Value -eq $null) -or (($now - $LastUpdateTime.Value).TotalMilliseconds -ge $MinMs) -or $Percent -ge 100) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $Percent
        $LastUpdateTime.Value = $now
    }
}

# -------- Ensure 7zr.exe --------
function Ensure-7zr {
    if (!(Test-Path $sevenZr)) {
        Write-Host "Downloading 7zr.exe..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $sevenZrUrl -OutFile $sevenZr
        if (!(Test-Path $sevenZr)) { throw "Failed to download 7zr.exe" }
        Write-Host "7zr.exe ready: $sevenZr" -ForegroundColor Green
    }
}

# -------- Ensure portable 7-Zip Extra using 7zr.exe --------
function Ensure-7ZipPortable {
    if (Test-Path $sevenZipExe) { return }

    Ensure-7zr

    Write-Host "Downloading portable 7-Zip Extra (.7z)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $portable7zUrl -OutFile $sevenZip7zPath
    if (!(Test-Path $sevenZip7zPath)) { throw "Failed to download portable 7-Zip" }

    if (!(Test-Path $sevenZipExtractPath)) { New-Item -ItemType Directory -Path $sevenZipExtractPath | Out-Null }

    Write-Host "Extracting portable 7-Zip Extra using 7zr.exe..." -ForegroundColor Cyan
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $sevenZr
    $psi.Arguments = "x `"$sevenZip7zPath`" -o`"$sevenZipExtractPath`" -y"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()

    if (!(Test-Path $sevenZipExe)) { throw "Failed to extract 7za.exe from portable 7-Zip" }
    Write-Host "Portable 7-Zip ready: $sevenZipExe" -ForegroundColor Green
}

# -------- Download Google Drive file --------
function Download-GDriveFile {
    param([string]$fileId,[string]$output)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://drive.google.com/uc?export=download&id=$fileId"
    Write-Host "Downloading $output via PowerShell..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $output
    Write-Host "Download completed: $output" -ForegroundColor Green
}

# -------- UI --------
Write-Host "Select version to download:" -ForegroundColor Yellow
foreach ($k in $files.Keys) { Write-Host " [$k] $($files[$k].Name) ($($files[$k].SizeMB) MB)" -ForegroundColor Green }

do { $choice = Read-Host "Enter choice (1 or 2)" } while (-not $files.ContainsKey($choice))
$username = Read-Host "Enter your Minecraft username"
if ([string]::IsNullOrWhiteSpace($username)) { Write-Host "Error: Username cannot be empty!"; exit 1 }

try {
    $fileInfo = $files[$choice]

    if ($choice -eq "1") {
        Download-GDriveFile $fileInfo.Id $downloadPath
    } else {
        $driveUrl = "https://drive.google.com/file/d/$($fileInfo.Id)/view"
        Write-Host "Opening browser to download Preinstalled file..." -ForegroundColor Cyan
        Start-Process $driveUrl
        Write-Host "After download completes, press ENTER"
        Read-Host

        $manualPath = Join-Path $downloadsFolder "PrismLauncher.7z"
        if (!(Test-Path $manualPath)) { throw "File not found at $manualPath" }
        Copy-Item $manualPath $downloadPath -Force
        Write-Host "Copied Preinstalled file to temp: $downloadPath" -ForegroundColor Green
    }

    # Ensure portable 7-Zip
    Ensure-7ZipPortable

    # -------- Extract Minecraft files with 7za.exe (-mmt) --------
    if (!(Test-Path $extractPath)) { New-Item -ItemType Directory -Path $extractPath | Out-Null }
    Write-Host "Extracting Minecraft with 7za.exe (-mmt)..." -ForegroundColor Yellow

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $sevenZipExe
    $psi.Arguments = "x `"$downloadPath`" -o`"$extractPath`" -y -mmt -bsp1"
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.Start() | Out-Null

    $lastTime=[ref]$null
    while (-not $proc.HasExited) {
        while (-not $proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line -match '(\d+)%') {
                $pct = [int]$matches[1]
                Throttled-WriteProgress -Activity "Extracting Minecraft" -Status "$pct% done" -Percent $pct -LastUpdateTime $lastTime -MinMs 300
            }
        }
        Start-Sleep -Milliseconds 150
    }
    $proc.WaitForExit()
    Write-Progress -Activity "Extracting Minecraft" -Completed
    Write-Host "Extraction completed!" -ForegroundColor Green

    # -------- Configure accounts.json --------
    Write-Host "Configuring username..." -ForegroundColor Cyan
    $accountsJsonPath = Get-ChildItem -Path $extractPath -Filter "accounts.json" -Recurse | Select-Object -First 1
    $newUuid=[guid]::NewGuid().ToString("N")
    $clientToken=[guid]::NewGuid().ToString("N")
    $timestamp=[int][double]::Parse((Get-Date -UFormat %s))

    if ($accountsJsonPath) {
        $json = Get-Content $accountsJsonPath.FullName -Raw | ConvertFrom-Json
        if ($json.accounts.Count -gt 0) {
            $json.accounts[0].profile.name = $username
            $json.accounts[0].profile.id = $newUuid
            if ($json.accounts[0].ygg -and $json.accounts[0].ygg.extra) { $json.accounts[0].ygg.extra.userName = $username }
            $json | ConvertTo-Json -Depth 10 | Set-Content $accountsJsonPath.FullName -Encoding UTF8
        }
    } else {
        $launcherDir = Get-ChildItem -Path $extractPath -Filter $gameExeName -Recurse | Select-Object -First 1
        if ($launcherDir) {
            $accountsJsonPath=Join-Path $launcherDir.DirectoryName "accounts.json"
            $newAccountsJson=@{
                accounts=@(@{
                    active=$true
                    entitlement=@{ canPlayMinecraft=$true; ownsMinecraft=$true }
                    profile=@{ capes=@(); id=$newUuid; name=$username; skin=@{ id=""; url=""; variant="" } }
                    type="Offline"
                    ygg=@{ extra=@{ clientToken=$clientToken; userName=$username }; iat=$timestamp; token="0" }
                })
                formatVersion=3
            }
            $newAccountsJson | ConvertTo-Json -Depth 10 | Set-Content $accountsJsonPath -Encoding UTF8
        }
    }

    # -------- Launch Minecraft ----------
    $launcherPath = Get-ChildItem -Path $extractPath -Filter $gameExeName -Recurse | Select-Object -First 1
    if ($launcherPath) {
        $process = Start-Process -FilePath $launcherPath.FullName -WorkingDirectory $launcherPath.DirectoryName -PassThru
        Write-Host "Launcher started. Waiting for it to exit..." -ForegroundColor Cyan
        $process.WaitForExit()

        $keep = Read-Host "Launcher closed. Keep files? (Y/N)"
        if ($keep -match '^[Yy]') {
            $appdataFolder = Join-Path $env:APPDATA "minecraft1"
            if (!(Test-Path $appdataFolder)) { New-Item -ItemType Directory -Path $appdataFolder | Out-Null }
            Copy-Item -Path $extractPath\* -Destination $appdataFolder -Recurse -Force
            Write-Host "Files moved to $appdataFolder" -ForegroundColor Green
        } else {
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $downloadPath) { Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue }
            Write-Host "Temporary files deleted." -ForegroundColor Gray
        }
    } else { Write-Host "Launcher not found!" -ForegroundColor Red }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
