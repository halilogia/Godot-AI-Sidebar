@echo off
setlocal
cd /d "%~dp0"

set SECONDS=%1
if "%SECONDS%"=="" set SECONDS=30

set PROJ=%2
if "%PROJ%"=="" set PROJ=.

echo [Godot AI] Oynanis Kaydedici baslatiliyor...
echo Proje: %PROJ% ^| Sure: %SECONDS% sn ^| Cozunurluk: 1280x720 @ 30fps

powershell -ExecutionPolicy Bypass -File "%~dp0game_clip.ps1" -Project "%PROJ%" -Resolution 1280x720 -Seconds %SECONDS%

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [Godot AI] Kayit basariyla tamamlandi. Video Devlog klasorune aktarildi.
) else (
    echo.
    echo [Godot AI] Hata: Kayit alinamadi.
)
