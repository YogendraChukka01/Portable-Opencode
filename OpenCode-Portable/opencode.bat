@echo off
setlocal EnableDelayedExpansion
title OpenCode Portable

REM ============================================================
REM  OpenCode Portable Launcher  -- v2 (bugfixed)
REM  Runs entirely off this drive. Never touches, reads, or runs
REM  any OpenCode that may already be installed on the host
REM  machine. All config / sessions / credentials / cache / temp
REM  files are redirected onto the drive itself.
REM
REM  Fixes vs v1:
REM   - The npm-generated node_modules\.bin\opencode.cmd shim is
REM     BROKEN on stock Windows: it tries to run the package's
REM     POSIX shell shim via "/bin/sh.exe", which doesn't exist
REM     on Windows, so opencode.cmd fails with
REM     "'/bin/sh.exe' is not recognized..." or
REM     "cannot execute binary file" (this is a known upstream
REM     packaging issue in opencode-ai, see anomalyco/opencode#2447).
REM     This launcher now calls the real compiled
REM     opencode-windows-<arch>\bin\opencode.exe directly instead,
REM     which sidesteps the broken shim entirely (and starts faster,
REM     since there's no extra JS shim layer to go through).
REM   - npm install now uses --no-bin-links, which avoids npm having
REM     to create that broken shim (and the symlink/EPERM permission
REM     issues that can come with it) in the first place.
REM   - Detects CPU architecture (x64 / arm64) instead of hardcoding
REM     x64, for ARM64 Windows devices (Snapdragon X Elite, etc).
REM   - Node.js download errors are now actually detected instead of
REM     always reporting success (old code's helper always returned
REM     "exit /b 0" no matter what PowerShell did).
REM ============================================================

REM --- ROOT = the folder this .bat file lives in (works on any drive letter) ---
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

REM --- Detect CPU architecture ---
set "ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

set "NODE_DIR=%ROOT%\engine\node-win"
set "NODE_EXE=%NODE_DIR%\node.exe"
set "NPM_CMD=%NODE_DIR%\npm.cmd"
REM Drive npm via node.exe + npm-cli.js directly. Invoking the npm.cmd
REM wrapper without `call` abandons this batch (npm.cmd ends the process
REM instead of returning), so the launcher would stop right after install.
REM node.exe is a real executable and returns control cleanly, and we
REM avoid `call` (which re-splits `--loglevel=error`/`--prefix "..."` at
REM the `=`, causing npm "EUSAGE").
set "NPM_CLI=%NODE_DIR%\node_modules\npm\bin\npm-cli.js"

set "APP_DIR=%ROOT%\opt\opencode-win"
REM The real compiled binary lives in the platform package
REM (opencode-windows-<arch>). npm hoists that package to the top-level
REM node_modules, but some layouts nest it under opencode-ai/node_modules;
REM --no-bin-links also means the .bin shim is absent. :LOCATE_OPENCODE
REM checks the known locations and, failing that, searches the whole tree.

set "DATA_DIR=%ROOT%\data\win"
set "HOME_DIR=%DATA_DIR%\home"
set "CONFIG_DIR=%DATA_DIR%\config"
set "SHARE_DIR=%DATA_DIR%\share"
set "CACHE_DIR=%DATA_DIR%\cache"
set "TEMP_DIR=%DATA_DIR%\temp"
set "NPMCACHE_DIR=%DATA_DIR%\npm-cache"
set "LOG_DIR=%DATA_DIR%\logs"

for %%D in ("%HOME_DIR%" "%CONFIG_DIR%" "%SHARE_DIR%" "%CACHE_DIR%" "%TEMP_DIR%" "%NPMCACHE_DIR%" "%LOG_DIR%" "%APP_DIR%") do (
    if not exist "%%~D" mkdir "%%~D" >nul 2>&1
)

echo.
echo   OpenCode Portable (%ARCH%)
echo   Running from: %ROOT%
echo.

REM ------------------------------------------------------------
REM  STEP 1 - Portable Node.js runtime (only downloaded once)
REM ------------------------------------------------------------
if not exist "%NODE_EXE%" (
    echo [1/3] No portable Node.js runtime found. Downloading it now...
    call :DOWNLOAD_NODE
    if errorlevel 1 (
        echo.
        echo ERROR: Could not set up the portable Node.js runtime.
        echo Check your internet connection and try again.
        goto :END
    )
    if not exist "%NODE_EXE%" (
        echo.
        echo ERROR: Could not set up the portable Node.js runtime.
        echo Check your internet connection and try again.
        goto :END
    )
    echo       Done.
) else (
    echo [1/3] Portable Node.js runtime found. OK.
)

REM ------------------------------------------------------------
REM  STEP 2 - OpenCode itself (only installed once, onto the drive)
REM ------------------------------------------------------------
call :LOCATE_OPENCODE
if defined OPENCODE_BIN goto :OC_ALREADY

echo [2/3] OpenCode is not yet installed. Resolving + verifying package now...
call :GET_OPENCODE
if not defined OPENCODE_TGZ (
    echo.
    echo ERROR: Could not resolve/verify the OpenCode package.
    echo Check your internet connection and try again.
    goto :END
)

REM Install OpenCode. IMPORTANT: this `npm install` must run at the TOP
REM LEVEL of the script, never inside a parenthesised `if (...)` block.
REM cmd re-parses arguments inside `(...)` and splits tokens such as
REM `--loglevel=error` and `--prefix "..."` at the `=`, handing npm a
REM broken argument list and producing "npm error code EUSAGE". Running
REM it as a bare, top-level command passes the arguments intact
REM (verified on GitHub Actions windows-latest, npm 11.16.0).
set "PATH=%NODE_DIR%;%PATH%"
set "npm_config_cache=%NPMCACHE_DIR%"
set "npm_config_prefix=%APP_DIR%"
"%NODE_EXE%" "%NPM_CLI%" install "%OPENCODE_TGZ%" --prefix "%APP_DIR%" --no-fund --no-audit --no-bin-links --loglevel=error
set "NPM_RC=%errorlevel%"
echo        npm exit code: %NPM_RC%

REM npm can return a non-zero exit for non-fatal reasons (e.g. an
REM EBADENGINE/peer-dependency note) even when the package was installed
REM successfully. Treat the install as successful when the real binary
REM exists; only bail out if it is genuinely missing.
call :LOCATE_OPENCODE
if not defined OPENCODE_BIN (
    echo.
    if "%NPM_RC%"=="0" (
        echo ERROR: OpenCode install reported success but the binary was not found.
    ) else (
        echo ERROR: OpenCode installation failed (npm exit %NPM_RC%). Check your internet connection and try again.
    )
    goto :END
)

REM Record the resolved OpenCode version for reference (mirrors the
REM Linux launcher, which writes opt/opencode-linux/OPENCODE_VERSION).
if exist "%OC_VER%" (
    set /p OCV=<"%OC_VER%"
    >"%APP_DIR%\OPENCODE_VERSION" echo !OCV!
)
echo       OpenCode installed successfully.
goto :OC_DONE

:OC_ALREADY
echo [2/3] OpenCode already installed. OK.

:OC_DONE

REM ------------------------------------------------------------
REM  STEP 3 - Launch OpenCode, fully sandboxed to the drive
REM  These environment variables only exist inside THIS window /
REM  THIS process tree. Nothing is written to the Windows registry
REM  and nothing persists on the host once you close this window.
REM ------------------------------------------------------------
echo [3/3] Launching OpenCode ^(portable^)...
echo.

set "PATH=%NODE_DIR%;%PATH%"

REM Redirect the "home directory" concept everywhere Node/OpenCode might look for it
set "HOME=%HOME_DIR%"
set "USERPROFILE=%HOME_DIR%"
set "HOMEDRIVE="
set "HOMEPATH="

REM Redirect Windows-style app-data folders
set "APPDATA=%SHARE_DIR%\AppData\Roaming"
set "LOCALAPPDATA=%SHARE_DIR%\AppData\Local"

REM Redirect XDG-style folders (used by many cross-platform CLIs, including OpenCode)
set "XDG_CONFIG_HOME=%CONFIG_DIR%"
set "XDG_DATA_HOME=%SHARE_DIR%"
set "XDG_CACHE_HOME=%CACHE_DIR%"
set "XDG_STATE_HOME=%SHARE_DIR%\state"

REM OpenCode's own documented config-directory override
set "OPENCODE_CONFIG_DIR=%CONFIG_DIR%\opencode"

REM Keep temp files off the host disk too
set "TEMP=%TEMP_DIR%"
set "TMP=%TEMP_DIR%"

REM Keep npm itself sandboxed in case you later run npm commands manually
set "npm_config_cache=%NPMCACHE_DIR%"
set "npm_config_prefix=%APP_DIR%"

if not exist "%APPDATA%" mkdir "%APPDATA%" >nul 2>&1
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" >nul 2>&1
if not exist "%OPENCODE_CONFIG_DIR%" mkdir "%OPENCODE_CONFIG_DIR%" >nul 2>&1

REM Call the drive's own copy of OpenCode by its exact, absolute path.
REM This deliberately ignores any OpenCode that may be on the host's PATH.
pushd "%~dp0"
call "!OPENCODE_BIN!" %*
popd

goto :END

REM ==============================================================
:DOWNLOAD_NODE
REM Downloads the current LTS portable Node.js zip for this CPU
REM architecture and extracts it into %NODE_DIR%, using only
REM PowerShell (built into Windows).
REM
REM The actual PowerShell logic lives in a generated .ps1 file rather
REM than an inline `-Command "..."` string: a single inline command
REM with this much nested quoting is a common source of subtle
REM batch/PowerShell escaping bugs, and a real .ps1 file is easier to
REM get right and easier to audit.
REM
REM Also: this now genuinely reports failure via errorlevel. The old
REM version's helper always ended with `exit /b 0`, so a failed
REM download was only ever caught by accident, via the later
REM "does node.exe exist" check.
set "TMP_ZIP=%TEMP_DIR%\opencode-portable-node.zip"
set "TMP_EXTRACT=%TEMP_DIR%\opencode-portable-node-extract"
set "PS1=%TEMP_DIR%\opencode-portable-get-node.ps1"

> "%PS1%" echo $ErrorActionPreference = 'Stop'
>> "%PS1%" echo try {
>> "%PS1%" echo   $idx = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
>> "%PS1%" echo   $lts = $idx ^| Where-Object { $_.lts -ne $false } ^| Select-Object -First 1
>> "%PS1%" echo   $ver = $lts.version
>> "%PS1%" echo   $url = "https://nodejs.org/dist/$ver/node-$ver-win-%ARCH%.zip"
>> "%PS1%" echo   Write-Host "       Downloading Node.js $ver (%ARCH%) ..."
>> "%PS1%" echo   Invoke-WebRequest -Uri $url -OutFile '%TMP_ZIP%'
>> "%PS1%" echo   Write-Host '       Verifying checksum...'
>> "%PS1%" echo   $shasums = Invoke-RestMethod -Uri "https://nodejs.org/dist/$ver/SHASUMS256.txt"
>> "%PS1%" echo   $fname = "node-$ver-win-%ARCH%.zip"
>> "%PS1%" echo   $line = ($shasums -split "`n") ^| Where-Object { $_ -match [Regex]::Escape($fname) } ^| Select-Object -First 1
>> "%PS1%" echo   if ($line) {
>> "%PS1%" echo     $expected = ($line -split '\s+')[0].Trim().ToLower()
>> "%PS1%" echo     $actual = (Get-FileHash -Path '%TMP_ZIP%' -Algorithm SHA256^).Hash.ToLower()
>> "%PS1%" echo     if ($expected -and ($expected -ne $actual)) {
>> "%PS1%" echo       Write-Host 'ERROR: checksum mismatch on downloaded Node.js zip.'
>> "%PS1%" echo       exit 1
>> "%PS1%" echo     }
>> "%PS1%" echo     Write-Host '       Checksum OK.'
>> "%PS1%" echo   }
>> "%PS1%" echo   Write-Host '       Extracting...'
>> "%PS1%" echo   if (Test-Path '%TMP_EXTRACT%'^) { Remove-Item '%TMP_EXTRACT%' -Recurse -Force }
>> "%PS1%" echo   Expand-Archive -Path '%TMP_ZIP%' -DestinationPath '%TMP_EXTRACT%' -Force
>> "%PS1%" echo   $inner = Get-ChildItem '%TMP_EXTRACT%' -Directory ^| Select-Object -First 1
>> "%PS1%" echo   if (Test-Path '%NODE_DIR%'^) { Remove-Item '%NODE_DIR%' -Recurse -Force }
>> "%PS1%" echo   $nodeParent = Split-Path '%NODE_DIR%'
>> "%PS1%" echo   if (-not (Test-Path $nodeParent^)^) { New-Item -ItemType Directory -Force -Path $nodeParent ^| Out-Null }
>> "%PS1%" echo   Move-Item $inner.FullName '%NODE_DIR%'
>> "%PS1%" echo   Remove-Item '%TMP_ZIP%' -Force
>> "%PS1%" echo   Remove-Item '%TMP_EXTRACT%' -Recurse -Force -ErrorAction SilentlyContinue
>> "%PS1%" echo } catch {
>> "%PS1%" echo   Write-Host ("ERROR: " + $_.Exception.Message)
>> "%PS1%" echo   exit 1
>> "%PS1%" echo }

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "PSRC=%errorlevel%"
del "%PS1%" >nul 2>&1

if not "%PSRC%"=="0" (
    exit /b 1
)
exit /b 0

REM ==============================================================
:GET_OPENCODE
REM Resolves the exact OpenCode npm package version from the registry,
REM downloads its tarball onto the drive, and verifies its SHA-512
REM "Subresource Integrity" (SRI) -- the same scheme npm uses to validate
REM every package. The OpenCode version can be pinned for reproducibility
REM via the OPENCODE_VERSION env var; otherwise "latest" is used. The
REM resolved version is written (as ASCII, see note below) to %OC_VER%;
REM the caller derives the tarball path from it.
REM
REM IMPORTANT: the version file is written with -Encoding ascii on
REM purpose. The bundled Windows PowerShell (5.1) defaults Set-Content
REM to UTF-16 LE, which packs a NUL byte after every character; the
REM batch `set /p` that reads it back would truncate at the first NUL
REM (leaving just the drive letter) and hand npm a garbage path ->
REM "npm error code EUSAGE". ASCII is single-byte with no BOM, so it
REM round-trips cleanly through `set /p`. The tarball path itself is
REM derived from the version string in the batch rather than written
REM to a file, avoiding any non-ASCII path issues entirely.
REM
REM All transient files (the generated .ps1, the tarball) live under
REM %TEMP_DIR% on the drive, so nothing is left on the host machine.
set "OPENCODE_TGZ="
set "OC_PS1=%TEMP_DIR%\opencode-get.ps1"
set "OC_VER=%TEMP_DIR%\opencode-version.txt"
if exist "%OC_PS1%" del "%OC_PS1%" >nul 2>&1

> "%OC_PS1%" echo $ErrorActionPreference = 'Stop'
>> "%OC_PS1%" echo try {
>> "%OC_PS1%" echo   $arch = '%ARCH%'
>> "%OC_PS1%" echo   $ver = $env:OPENCODE_VERSION
>> "%OC_PS1%" echo   $base = "https://registry.npmjs.org/opencode-windows-$arch"
>> "%OC_PS1%" echo   $url = if ($ver^) { "$base/$ver" } else { "$base/latest" }
>> "%OC_PS1%" echo   $meta = Invoke-RestMethod -Uri $url
>> "%OC_PS1%" echo   $version = $meta.version
>> "%OC_PS1%" echo   $integrity = $meta.dist.integrity
>> "%OC_PS1%" echo   $tarball = $meta.dist.tarball
>> "%OC_PS1%" echo   Write-Host "       Resolved OpenCode $version (%ARCH%) ..."
>> "%OC_PS1%" echo   $tgz = Join-Path '%TEMP_DIR%' ("opencode-" + $version + ".tgz")
>> "%OC_PS1%" echo   if (-not (Test-Path $tgz^)) { Invoke-WebRequest -Uri $tarball -OutFile $tgz }
>> "%OC_PS1%" echo   Write-Host '       Verifying package integrity (SHA-512) ...'
>> "%OC_PS1%" echo   $alg, $expect = $integrity -split '-', 2
>> "%OC_PS1%" echo   $bytes = [System.IO.File]::ReadAllBytes($tgz)
>> "%OC_PS1%" echo   $hash = [System.Security.Cryptography.SHA512]::Create().ComputeHash($bytes)
>> "%OC_PS1%" echo   $actual = [Convert]::ToBase64String($hash)
>> "%OC_PS1%" echo   if ($expect -and ($expect -ne $actual^)) { Write-Host 'ERROR: OpenCode package integrity mismatch.'; exit 1 }
>> "%OC_PS1%" echo   if (-not $expect^) { Write-Host 'WARNING: no integrity info; skipping verification.' } else { Write-Host '       Integrity OK.' }
>> "%OC_PS1%" echo   Set-Content -Path '%OC_VER%' -Value $version -Encoding ascii
>> "%OC_PS1%" echo } catch {
>> "%OC_PS1%" echo   Write-Host ("ERROR: " + $_.Exception.Message)
>> "%OC_PS1%" echo   exit 1
>> "%OC_PS1%" echo }

powershell -NoProfile -ExecutionPolicy Bypass -File "%OC_PS1%"
set "PSRC=%errorlevel%"
del "%OC_PS1%" >nul 2>&1
if not "%PSRC%"=="0" (
    exit /b 1
)
if exist "%OC_VER%" (
    set /p OCV=<"%OC_VER%"
    set "OPENCODE_TGZ=%TEMP_DIR%\opencode-!OCV!.tgz"
)
exit /b 0

REM ==============================================================
:LOCATE_OPENCODE
REM Finds the compiled OpenCode binary and stores it in OPENCODE_BIN.
REM npm hoists the platform package (opencode-windows-<arch>) to the
REM top-level node_modules, but some layouts nest it under
REM opencode-ai/node_modules; --no-bin-links also means the .bin shim
REM is absent -- so we check the known locations and, failing that,
REM search the whole tree.
set "OPENCODE_BIN="
if exist "%APP_DIR%\node_modules\opencode-ai\node_modules\opencode-windows-%ARCH%\bin\opencode.exe" (
    set "OPENCODE_BIN=%APP_DIR%\node_modules\opencode-ai\node_modules\opencode-windows-%ARCH%\bin\opencode.exe"
    goto :LOCATE_DONE
)
if exist "%APP_DIR%\node_modules\opencode-windows-%ARCH%\bin\opencode.exe" (
    set "OPENCODE_BIN=%APP_DIR%\node_modules\opencode-windows-%ARCH%\bin\opencode.exe"
    goto :LOCATE_DONE
)
if exist "%APP_DIR%\node_modules\opencode-ai\bin\opencode.exe" (
    set "OPENCODE_BIN=%APP_DIR%\node_modules\opencode-ai\bin\opencode.exe"
    goto :LOCATE_DONE
)
for /f "delims=" %%F in ('dir /s /b "%APP_DIR%\node_modules\opencode-windows-%ARCH%\bin\opencode.exe" 2^>nul') do (
    set "OPENCODE_BIN=%%F"
    goto :LOCATE_DONE
)
:LOCATE_DONE
exit /b 0

:END
endlocal
