@echo off
echo ========================================================
echo       DANADA LOANS - WINDOWS RELEASE BUILD SCRIPT
echo ========================================================
echo.

echo [1/4] Checking Flutter...
call flutter --version
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not installed or not in PATH!
    echo Please install Flutter and Visual Studio 2022 with C++ desktop workload.
    pause
    exit /b %errorlevel%
)

echo.
echo [2/4] Enabling Windows desktop support...
call flutter config --enable-windows-desktop

echo.
echo [3/4] Getting dependencies...
call flutter pub get

echo.
echo [4/4] Building Windows Release (danada_loans.exe)...
call flutter build windows --release

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Windows build failed. Please check the logs above.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo [SUCCESS] Windows Release Build Completed!
echo Executable is located at:
echo build\windows\x64\runner\Release\danada_loans.exe
echo ========================================================
echo.

set "OUTPUT_DIR=build\windows\x64\runner\Release"
if not exist "%OUTPUT_DIR%" (
    set "OUTPUT_DIR=build\windows\runner\Release"
)

if exist "%OUTPUT_DIR%" (
    echo Opening output folder...
    explorer "%OUTPUT_DIR%"
)

pause
