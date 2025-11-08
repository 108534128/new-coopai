@echo off
chcp 65001 >nul
echo ========================================
echo 🚀 啟動前端應用 (Flutter)
echo ========================================
echo.

cd /d "%~dp0frontend"

echo 📦 檢查 Flutter 環境...
flutter --version
if errorlevel 1 (
    echo ❌ 錯誤：找不到 Flutter，請先安裝 Flutter
    pause
    exit /b 1
)

echo.
echo 📦 安裝依賴套件...
flutter pub get

echo.
echo ========================================
echo ✅ 啟動前端應用...
echo ========================================
echo.
echo 💡 提示：應用將在瀏覽器或模擬器上運行
echo 💡 按 Ctrl+C 可停止應用
echo.

REM 檢查是否有指定設備，否則使用 chrome
if "%1"=="" (
    echo.
    echo 💡 提示：要執行到手機，請使用「啟動前端-手機版.bat」
    echo.
    flutter run -d chrome
) else (
    flutter run -d %1
)

pause

