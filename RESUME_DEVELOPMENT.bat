@echo off
echo Starting Yuh Blockin Development Environment...
echo ================================================

cd /d "C:\Users\valjo\AndroidStudioProjects\Yuh_Blockin"

echo.
echo Current Directory: %CD%
echo.

echo Checking Git status...
git status --porcelain
if %ERRORLEVEL% NEQ 0 (
    echo Warning: Git status check failed
) else (
    echo Git status: OK
)

echo.
echo Starting Flutter Premium App...
echo.
echo To run premium version: flutter run --target=lib/main_premium.dart --device-id=chrome --release
echo To run web version: flutter run --target=lib/main_web.dart --device-id=chrome --release
echo.

echo Opening SESSION_STATE.md for reference...
if exist SESSION_STATE.md (
    notepad SESSION_STATE.md
) else (
    echo SESSION_STATE.md not found
)

echo.
echo Development environment ready!
echo Press any key to start Flutter development server...
pause > nul

flutter run --target=lib/main_premium.dart --device-id=chrome --release

pause