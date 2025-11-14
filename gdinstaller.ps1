# Google Drive Game Downloader and Runner (Browser Download Method)
# Replace these variables with your actual values
$fileId = "1uhSL_IgIvZWI9XXqx5Y34FIsaA6dRv4k"  # Extract from share link
$gameExeName = "GeometryDash.exe"  # Name of the executable inside the zip

# Setup paths
$tempFolder = [System.IO.Path]::GetTempPath()
$downloadPath = Join-Path $tempFolder "game_download.zip"
$extractPath = Join-Path $tempFolder "game_extracted_$(Get-Random)"
$downloadsFolder = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Google Drive Game Launcher" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Open Google Drive link in default browser
    $driveUrl = "https://drive.google.com/file/d/$fileId/view"
    Write-Host "Opening Google Drive in your browser..." -ForegroundColor Yellow
    Start-Process $driveUrl
    
    Write-Host ""
    Write-Host "INSTRUCTIONS:" -ForegroundColor Green
    Write-Host "1. Click the 'Download' button in your browser" -ForegroundColor White
    Write-Host "2. Wait for the download to complete" -ForegroundColor White
    Write-Host "3. Come back here and press ENTER" -ForegroundColor White
    Write-Host ""
    Write-Host "The script will automatically find and process your downloaded file." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press ENTER after download completes"
    
    # Look for the downloaded zip file in Downloads folder
    Write-Host "Searching for downloaded file..." -ForegroundColor Cyan
    
    # Get the most recent .zip file from Downloads
    $recentZip = Get-ChildItem -Path $downloadsFolder -Filter "*.zip" | 
                 Sort-Object LastWriteTime -Descending | 
                 Select-Object -First 1
    
    if ($recentZip) {
        Write-Host "Found: $($recentZip.Name)" -ForegroundColor Green
        Write-Host "Size: $([math]::Round($recentZip.Length/1MB, 2)) MB" -ForegroundColor Green
        
        # Copy to temp location
        Write-Host "Copying to temp folder..." -ForegroundColor Cyan
        Copy-Item -Path $recentZip.FullName -Destination $downloadPath -Force
        
        # Delete from Downloads to keep it clean
        Write-Host "Cleaning up Downloads folder..." -ForegroundColor Cyan
        Remove-Item $recentZip.FullName -Force
        
    } else {
        Write-Host "No ZIP file found in Downloads folder." -ForegroundColor Red
        Write-Host "Please specify the full path to your downloaded file:" -ForegroundColor Yellow
        $manualPath = Read-Host "Enter path"
        
        if (Test-Path $manualPath) {
            Copy-Item -Path $manualPath -Destination $downloadPath -Force
            Write-Host "File loaded successfully!" -ForegroundColor Green
        } else {
            throw "File not found at specified path."
        }
    }
    
    # Verify ZIP file
    Write-Host "Verifying ZIP file..." -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zipTest = [System.IO.Compression.ZipFile]::OpenRead($downloadPath)
        $entryCount = $zipTest.Entries.Count
        $zipTest.Dispose()
        Write-Host "ZIP file is valid! Contains $entryCount files." -ForegroundColor Green
    } catch {
        throw "Downloaded file is not a valid ZIP file."
    }
    
    # Extract the zip file
    Write-Host ""
    Write-Host "Extracting files..." -ForegroundColor Cyan
    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath)
    Write-Host "Extraction completed!" -ForegroundColor Green
    
    # Find and run the game executable
    Write-Host ""
    Write-Host "Looking for game executable: $gameExeName" -ForegroundColor Cyan
    $gamePath = Get-ChildItem -Path $extractPath -Filter $gameExeName -Recurse | Select-Object -First 1
    
    if ($gamePath) {
        Write-Host "Found game at: $($gamePath.FullName)" -ForegroundColor Green
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Yellow
        Write-Host "  LAUNCHING GAME..." -ForegroundColor Yellow
        Write-Host "============================================" -ForegroundColor Yellow
        Write-Host ""
        
        Start-Sleep -Seconds 2
        
        $process = Start-Process -FilePath $gamePath.FullName -WorkingDirectory $gamePath.DirectoryName -PassThru
        
        # Wait for the game to close
        Write-Host "Game is running. Window will close when you exit the game." -ForegroundColor Cyan
        $process.WaitForExit()
        
        Write-Host ""
        Write-Host "Game closed." -ForegroundColor Yellow
    } else {
        Write-Host "Error: Could not find $gameExeName in the extracted files!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available executable files:" -ForegroundColor Yellow
        Get-ChildItem -Path $extractPath -Recurse -Include "*.exe" | ForEach-Object { 
            Write-Host "  - $($_.Name)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Please update the script with the correct executable name." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host ""
    Write-Host "Error occurred: $_" -ForegroundColor Red
} finally {
    # Cleanup - Remove downloaded and extracted files
    Write-Host ""
    Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
    
    if (Test-Path $downloadPath) {
        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        Write-Host "  - Removed temporary ZIP" -ForegroundColor Gray
    }
    
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  - Removed extracted files" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Cleanup completed!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor White
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}