@echo off
chcp 65001 >nul
echo ========================================
echo 📱 直接執行到手機（USB 連接）
echo ========================================
echo.

cd /d "%~dp0frontend"

echo 📦 檢查 Flutter 環境...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 錯誤：找不到 Flutter，請先安裝 Flutter
    pause
    exit /b 1
)

echo.
echo 🔍 檢查已連接的設備...
echo.
flutter devices

echo.
echo ========================================
echo 📱 準備執行到手機...
echo ========================================
echo.

REM 檢查是否有 Android 設備
flutter devices | findstr /i "android" >nul
if errorlevel 1 (
    echo ⚠️  未檢測到已連接的 Android 設備
    echo.
    echo 💡 請確認：
    echo    1. 手機已用 USB 線連接到電腦
    echo    2. 手機已開啟「USB 偵錯模式」
    echo       設定 → 關於手機 → 連續點擊「版本號碼」7次
    echo       設定 → 開發人員選項 → 開啟「USB 偵錯」
    echo    3. 手機已授權電腦存取（手機上會跳出提示）
    echo.
    echo 🔄 等待設備連接...
    echo    請連接手機後按任意鍵繼續...
    pause >nul
    echo.
    echo 🔍 重新檢查設備...
    flutter devices
    echo.
)

echo.
echo 📦 安裝/更新依賴套件...
flutter pub get

echo.
echo ========================================
echo ✅ 開始執行到手機...
echo ========================================
echo.
echo 💡 提示：
echo    - 應用會自動安裝到手機
echo    - 首次安裝可能需要一些時間
echo    - 按 Ctrl+C 可停止應用
echo    - 修改程式碼後會自動熱重載
echo.
echo ⚠️  重要：確保後端服務正在運行！
echo    後端 API: http://localhost:5000
echo.

REM 直接執行到手機（Flutter 會自動選擇 Android 設備）
flutter run

pause

