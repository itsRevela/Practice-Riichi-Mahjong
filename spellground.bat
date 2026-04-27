@echo off
setlocal EnableDelayedExpansion
title Spellground Background Mod Installer

set "URL=https://i.imgur.com/I0n6yk7.png"
set "TEXTURE_DIR=%~dp0Data\Textures"
set "TARGET=%TEXTURE_DIR%\field_high.png"
set "BACKUP=%TEXTURE_DIR%\field_high.png.bak"
set "TEMP_FILE=%TEMP%\spellground_field_high.png"

echo ============================================
echo  Spellground Background Mod Installer
echo ============================================
echo.

if not exist "%TEXTURE_DIR%\" (
    echo [ERROR] Could not find:
    echo     %TEXTURE_DIR%
    echo.
    echo Place this script next to OpenRiichi.exe in the game folder
    echo and run it again.
    echo.
    pause
    exit /b 1
)

echo Downloading texture from:
echo     %URL%
echo.

curl --location --fail --silent --show-error --output "%TEMP_FILE%" "%URL%"
if errorlevel 1 (
    echo.
    echo [ERROR] Download failed. Check your internet connection and try again.
    echo.
    pause
    exit /b 1
)

if not exist "%TEMP_FILE%" (
    echo [ERROR] Download finished but no file was written.
    echo.
    pause
    exit /b 1
)

if exist "%TARGET%" (
    if exist "%BACKUP%" (
        echo Existing backup found at field_high.png.bak, leaving it in place
        echo so the original texture stays recoverable.
    ) else (
        echo Backing up original field_high.png to field_high.png.bak ...
        move /Y "%TARGET%" "%BACKUP%" >nul
        if errorlevel 1 (
            echo [ERROR] Failed to back up the original texture.
            echo.
            pause
            exit /b 1
        )
    )
) else (
    echo No existing field_high.png found, installing fresh.
)

echo Installing new field_high.png ...
move /Y "%TEMP_FILE%" "%TARGET%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to install new texture.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Installation complete!
echo ============================================
echo.
echo The Spellground background is now active.
echo To revert, rename:
echo     Data\Textures\field_high.png.bak
echo back to:
echo     Data\Textures\field_high.png
echo.
pause
endlocal
