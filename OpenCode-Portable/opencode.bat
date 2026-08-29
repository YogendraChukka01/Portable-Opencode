@echo off
setlocal
title OpenCode Portable

REM ============================================================
REM  OpenCode Portable Launcher -- hardened
REM ============================================================
REM  Uses a portable Node.js runtime and calls the native OpenCode
REM  Windows binary directly. Application data is redirected into
REM  the USB-local data tree.
REM ============================================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

set "NODE_DIR=%ROOT%\engine\node-win"
set "NODE_EXE=%NODE_DIR%\node.exe"
set "NPM_CLI=%NODE_DIR%\node_modules\npm\bin\npm-cli.js"
set "APP_DIR=%ROOT%\opt\opencode-win"

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

echo(
echo   OpenCode Portable (Windows / %ARCH%)
echo   Running from: %ROOT%
echo(

if not exist "%NODE_EXE%" (
    echo [1/3] No portable Node.js runtime found. Downloading it now...
    call :DOWNLOAD_NODE
    if errorlevel 1 goto :FAIL_NODE
    if not exist "%NODE_EXE%" goto :FAIL_NODE
    echo       Done.
) else (
    echo [1/3] Portable Node.js runtime found. OK.
)

call :LOCATE_OPENCODE
if defined OPENCODE_BIN goto :OC_ALREADY

echo [2/3] OpenCode is not yet installed. Resolving + verifying package...
call :GET_OPENCODE
if not defined OPENCODE_TGZ goto :FAIL_OC

set "PATH=%NODE_DIR%;%PATH%"
set "npm_config_cache=%NPMCACHE_DIR%"
set "npm_config_prefix=%APP_DIR%"
"%NODE_EXE%" "%NPM_CLI%" install "%OPENCODE_TGZ%" --prefix "%APP_DIR%" --no-fund --no-audit --no-bin-links --loglevel=error
set "NPM_RC=%errorlevel%"
echo        npm exit code: %NPM_RC%

call :LOCATE_OPENCODE
if not defined OPENCODE_BIN (
    echo ERROR: OpenCode binary was not found after installation.
    goto :FAIL_OC
)
call :RECORD_OC_VERSION

echo       OpenCode installed successfully.
goto :OC_DONE

:OC_ALREADY
echo [2/3] OpenCode already installed. OK.

:OC_DONE
echo [3/3] Launching OpenCode (portable)...
echo(

set "PATH=%NODE_DIR%;%PATH%"
set "HOME=%HOME_DIR%"
set "USERPROFILE=%HOME_DIR%"
set "HOMEDRIVE="
set "HOMEPATH="
set "APPDATA=%SHARE_DIR%\AppData\Roaming"
set "LOCALAPPDATA=%SHARE_DIR%\AppData\Local"
set "XDG_CONFIG_HOME=%CONFIG_DIR%"
set "XDG_DATA_HOME=%SHARE_DIR%"
set "XDG_CACHE_HOME=%CACHE_DIR%"
set "XDG_STATE_HOME=%SHARE_DIR%\state"
set "OPENCODE_CONFIG_DIR=%CONFIG_DIR%\opencode"
set "TEMP=%TEMP_DIR%"
set "TMP=%TEMP_DIR%"
set "npm_config_cache=%NPMCACHE_DIR%"
set "npm_config_prefix=%APP_DIR%"

if not exist "%APPDATA%" mkdir "%APPDATA%" >nul 2>&1
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" >nul 2>&1
if not exist "%OPENCODE_CONFIG_DIR%" mkdir "%OPENCODE_CONFIG_DIR%" >nul 2>&1

pushd "%ROOT%"
call "%OPENCODE_BIN%" %*
set "OC_RC=%errorlevel%"
popd
exit /b %OC_RC%

:DOWNLOAD_NODE
set "TMP_ZIP=%TEMP_DIR%\opencode-portable-node.zip"
set "TMP_EXTRACT=%TEMP_DIR%\opencode-portable-node-extract"
set "PS1=%TEMP_DIR%\opencode-portable-get-node.ps1"

> "%PS1%" echo $ErrorActionPreference = 'Stop'
>> "%PS1%" echo try {
>> "%PS1%" echo   $idx = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
>> "%PS1%" echo   $lts = $idx ^| Where-Object { $_.lts -ne $false } ^| Select-Object -First 1
>> "%PS1%" echo   if (-not $lts^) { throw 'Could not resolve a Node.js LTS release.' }
>> "%PS1%" echo   $ver = $lts.version
>> "%PS1%" echo   $fname = "node-$ver-win-%ARCH%.zip"
>> "%PS1%" echo   $url = "https://nodejs.org/dist/$ver/$fname"
>> "%PS1%" echo   Write-Host "       Downloading Node.js $ver (%ARCH%) ..."
>> "%PS1%" echo   Invoke-WebRequest -Uri $url -OutFile '%TMP_ZIP%'
>> "%PS1%" echo   Write-Host '       Verifying checksum...'
>> "%PS1%" echo   $shasums = Invoke-RestMethod -Uri "https://nodejs.org/dist/$ver/SHASUMS256.txt"
>> "%PS1%" echo   $line = ($shasums -split "`n") ^| Where-Object { $_ -match [Regex]::Escape($fname) } ^| Select-Object -First 1
>> "%PS1%" echo   if (-not $line^) { throw 'Node.js checksum entry not found.' }
>> "%PS1%" echo   $expected = ($line -split '\s+')[0].Trim().ToLower()
>> "%PS1%" echo   $actual = (Get-FileHash -Path '%TMP_ZIP%' -Algorithm SHA256^).Hash.ToLower()
>> "%PS1%" echo   if (-not $expected -or $expected -ne $actual^) { throw 'Node.js checksum mismatch.' }
>> "%PS1%" echo   Write-Host '       Checksum OK.'
>> "%PS1%" echo   if (Test-Path '%TMP_EXTRACT%'^) { Remove-Item '%TMP_EXTRACT%' -Recurse -Force }
>> "%PS1%" echo   Expand-Archive -Path '%TMP_ZIP%' -DestinationPath '%TMP_EXTRACT%' -Force
>> "%PS1%" echo   $inner = Get-ChildItem '%TMP_EXTRACT%' -Directory ^| Select-Object -First 1
>> "%PS1%" echo   if (-not $inner^) { throw 'Node.js archive contained no top-level directory.' }
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
exit /b %PSRC%

:GET_OPENCODE
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
>> "%OC_PS1%" echo   if (-not $version -or -not $integrity -or -not $tarball^) { throw 'Incomplete npm package metadata.' }
>> "%OC_PS1%" echo   Write-Host "       Resolved OpenCode $version (%ARCH%) ..."
>> "%OC_PS1%" echo   $tgz = Join-Path '%TEMP_DIR%' ("opencode-" + $version + ".tgz")
>> "%OC_PS1%" echo   $validCache = $false
>> "%OC_PS1%" echo   if (Test-Path $tgz^) {
>> "%OC_PS1%" echo     $alg, $expect = $integrity -split '-', 2
>> "%OC_PS1%" echo     $bytes = [System.IO.File]::ReadAllBytes($tgz)
>> "%OC_PS1%" echo     $hash = if ($alg -eq 'sha512'^) { [System.Security.Cryptography.SHA512]::Create().ComputeHash($bytes) } elseif ($alg -eq 'sha256'^) { [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes) } else { $null }
>> "%OC_PS1%" echo     if ($hash^) { $validCache = ($expect -eq [Convert]::ToBase64String($hash^)) }
>> "%OC_PS1%" echo   }
>> "%OC_PS1%" echo   if (-not $validCache^) {
>> "%OC_PS1%" echo     Remove-Item $tgz -Force -ErrorAction SilentlyContinue
>> "%OC_PS1%" echo     Invoke-WebRequest -Uri $tarball -OutFile $tgz
>> "%OC_PS1%" echo   }
>> "%OC_PS1%" echo   $alg, $expect = $integrity -split '-', 2
>> "%OC_PS1%" echo   $bytes = [System.IO.File]::ReadAllBytes($tgz)
>> "%OC_PS1%" echo   $hash = if ($alg -eq 'sha512'^) { [System.Security.Cryptography.SHA512]::Create().ComputeHash($bytes) } elseif ($alg -eq 'sha256'^) { [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes) } else { $null }
>> "%OC_PS1%" echo   if (-not $hash^) { throw 'Unsupported npm integrity algorithm.' }
>> "%OC_PS1%" echo   $actual = [Convert]::ToBase64String($hash)
>> "%OC_PS1%" echo   if ($expect -ne $actual^) { Remove-Item $tgz -Force -ErrorAction SilentlyContinue; throw 'OpenCode package integrity mismatch.' }
>> "%OC_PS1%" echo   Write-Host '       Integrity OK.'
>> "%OC_PS1%" echo   Set-Content -Path '%OC_VER%' -Value $version -Encoding ascii
>> "%OC_PS1%" echo } catch {
>> "%OC_PS1%" echo   Write-Host ("ERROR: " + $_.Exception.Message)
>> "%OC_PS1%" echo   exit 1
>> "%OC_PS1%" echo }

powershell -NoProfile -ExecutionPolicy Bypass -File "%OC_PS1%"
set "PSRC=%errorlevel%"
del "%OC_PS1%" >nul 2>&1
if not "%PSRC%"=="0" exit /b 1
if exist "%OC_VER%" call :SET_OC_TARBALL
exit /b 0

:RECORD_OC_VERSION
if exist "%OC_VER%" (
    set /p OCV=<"%OC_VER%"
    >"%APP_DIR%\OPENCODE_VERSION" echo %OCV%
)
exit /b 0

:SET_OC_TARBALL
set /p OCV=<"%OC_VER%"
set "OPENCODE_TGZ=%TEMP_DIR%\opencode-%OCV%.tgz"
exit /b 0

:LOCATE_OPENCODE
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

:FAIL_NODE
echo(
echo ERROR: Could not set up the portable Node.js runtime.
echo Check your internet connection and try again.
goto :END

:FAIL_OC
echo(
echo ERROR: Could not resolve or verify the OpenCode package.
echo Check your internet connection and try again.
goto :END

:END
endlocal
