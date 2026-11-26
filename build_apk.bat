@echo off
cd /d d:\dialer\umar_dailer
echo Starting Flutter Build...
flutter build apk --release
if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo BUILD SUCCESSFUL!
    echo ============================================
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
) else (
    echo.
    echo ============================================
    echo BUILD FAILED! Error Code: %errorlevel%
    echo ============================================
    echo.
)
pause
