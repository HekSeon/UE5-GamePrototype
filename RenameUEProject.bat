@echo off
setlocal
cd /d "%~dp0"
title Unreal Project Renamer

echo ==============================================
echo   Unreal Engine C++ Project Renamer
echo ==============================================
echo.

set "OLD_NAME="
set COUNT=0
for %%F in (*.uproject) do (
    set "OLD_NAME=%%~nF"
    set /a COUNT+=1
)

if %COUNT%==0 (
    echo [ERROR] No .uproject file found. Put this .bat next to your .uproject file.
    pause
    exit /b 1
)
if %COUNT% GTR 1 (
    echo [ERROR] More than one .uproject file found in this folder.
    pause
    exit /b 1
)

tasklist /FI "IMAGENAME eq UnrealEditor.exe" 2>nul | find /I "UnrealEditor.exe" >nul
if %errorlevel%==0 (
    echo [ERROR] Unreal Editor is running. Please close it and run this script again.
    pause
    exit /b 1
)

echo Current project name : %OLD_NAME%
echo.
set "NEW_NAME="
set /p NEW_NAME=New project name     : 
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); $i=$s.IndexOf('#'+'PS1START'); Invoke-Expression $s.Substring($i)"
echo.
pause
exit /b %errorlevel%

#PS1START
$ErrorActionPreference = 'Stop'
try {
    $old = $env:OLD_NAME
    $new = ("" + $env:NEW_NAME).Trim()

    if ($new -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
        throw "Invalid name '$new'. Use only letters, digits and underscore, and do not start with a digit (no spaces)."
    }
    if ($new -ieq $old) { throw "The new name is the same as the old name." }
    if (Test-Path -LiteralPath "$new.uproject") { throw "$new.uproject already exists." }
    if (Test-Path -LiteralPath "Source\$new") { throw "Source\$new already exists." }

    Write-Host "Old name : $old"
    Write-Host "New name : $new"
    Write-Host ""
    $ans = Read-Host "Type YES to continue (a backup will be created first)"
    if ($ans.Trim() -notin 'y', 'yes') { throw "Cancelled by user." }

    # ---- 1) Backup -------------------------------------------------------
    $bk = "_RenameBackup_" + (Get-Date -Format 'yyyyMMdd_HHmmss')
    New-Item -ItemType Directory -Path $bk | Out-Null
    Copy-Item -LiteralPath "$old.uproject" -Destination $bk
    foreach ($d in 'Source', 'Config') {
        if (Test-Path $d) { Copy-Item -LiteralPath $d -Destination (Join-Path $bk $d) -Recurse }
    }
    Write-Host "[1/6] Backup created: $bk"

    # ---- 2) Clean generated files ---------------------------------------
    foreach ($d in 'Binaries', 'Intermediate', '.vs') {
        if (Test-Path $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Get-ChildItem -Filter *.sln -File | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "[2/6] Cleaned Binaries / Intermediate / .vs / .sln"

    # ---- 3) Collect class redirects (so Blueprints keep working) ---------
    $srcFiles = @()
    if (Test-Path 'Source') {
        $srcFiles = @(Get-ChildItem 'Source' -Recurse -File | Where-Object { '.h','.cpp','.cs','.inl' -contains $_.Extension.ToLower() })
    }
    $found = @{}
    $pattern = '\b([AUFE])(' + [regex]::Escape($old) + '\w*)'
    foreach ($f in ($srcFiles | Where-Object { $_.Extension -eq '.h' })) {
        $c = [IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($c, $pattern)) {
            $found[$m.Groups[1].Value + '|' + $m.Groups[2].Value] = $true
        }
    }
    $redirects = New-Object System.Collections.Generic.List[string]
    $redirects.Add('[CoreRedirects]')
    $redirects.Add('+PackageRedirects=(OldName="/Script/' + $old + '",NewName="/Script/' + $new + '")')
    foreach ($k in $found.Keys) {
        $p = $k.Split('|')[0]; $n = $k.Split('|')[1]
        $nn = $n.Replace($old, $new)
        $kind = 'ClassRedirects'
        if ($p -eq 'F') { $kind = 'StructRedirects' }
        if ($p -eq 'E') { $kind = 'EnumRedirects' }
        $redirects.Add('+' + $kind + '=(OldName="/Script/' + $old + '.' + $n + '",NewName="/Script/' + $new + '.' + $nn + '")')
    }
    Write-Host "[3/6] Prepared $($redirects.Count - 1) redirect entries"

    # ---- 4) Replace text inside project files ----------------------------
    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($f in $srcFiles) { $targets.Add($f.FullName) }
    if (Test-Path 'Config') {
        Get-ChildItem 'Config' -Recurse -File -Filter *.ini | ForEach-Object { $targets.Add($_.FullName) }
    }
    $targets.Add((Join-Path (Get-Location).Path "$old.uproject"))

    $oldApi = $old.ToUpper() + '_API'
    $newApi = $new.ToUpper() + '_API'
    $changed = 0
    foreach ($path in $targets) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $text = [IO.File]::ReadAllText($path)
        $out = $text.Replace($old, $new).Replace($oldApi, $newApi)
        if ($out -ne $text) {
            [IO.File]::WriteAllText($path, $out, (New-Object System.Text.UTF8Encoding($bom)))
            $changed++
        }
    }
    Write-Host "[4/6] Updated text in $changed file(s)"

    # ---- 5) Rename files and folders (deepest first) ---------------------
    $renamed = 0
    if (Test-Path 'Source') {
        Get-ChildItem 'Source' -Recurse |
            Where-Object { $_.Name.Contains($old) } |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                Rename-Item -LiteralPath $_.FullName -NewName $_.Name.Replace($old, $new)
                $renamed++
            }
    }
    Rename-Item -LiteralPath "$old.uproject" -NewName "$new.uproject"
    $renamed++
    Write-Host "[5/6] Renamed $renamed file(s)/folder(s)"

    # ---- 6) Write redirects into DefaultEngine.ini -----------------------
    if ($redirects.Count -gt 1) {
        if (-not (Test-Path 'Config')) { New-Item -ItemType Directory -Path 'Config' | Out-Null }
        $ini = 'Config\DefaultEngine.ini'
        $block = [Environment]::NewLine + ($redirects -join [Environment]::NewLine) + [Environment]::NewLine
        [IO.File]::AppendAllText((Join-Path (Get-Location).Path $ini), $block)
    }
    Write-Host "[6/6] Redirects written to Config\DefaultEngine.ini"

    Write-Host ""
    Write-Host "DONE. Next steps:" -ForegroundColor Green
    Write-Host "  1. Right-click $new.uproject -> Generate Visual Studio project files"
    Write-Host "  2. Open the new .sln and build (Development Editor), or just open $new.uproject and click Yes to rebuild"
    Write-Host "  3. If everything works, you can delete the $bk folder"
    exit 0
}
catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
