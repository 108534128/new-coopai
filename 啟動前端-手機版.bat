@echo off
chcp 65001 >nul
echo ========================================
echo 📱 啟動前端應用 - 手機執行版本
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
echo ========================================
echo 請選擇執行方式：
echo ========================================
echo 1. 構建 Android APK（安裝到手機）
echo 2. 啟動 Web 版本（手機瀏覽器訪問）
echo 3. 直接運行到已連接的手機設備
echo ========================================
echo.
set /p choice=請輸入選項 (1/2/3): 

if "%choice%"=="1" goto build_apk
if "%choice%"=="2" goto web_mobile
if "%choice%"=="3" goto run_device
goto invalid_choice

:build_apk
echo.
echo ========================================
echo 📦 構建 Android APK...
echo ========================================
echo.
echo 💡 提示：這可能需要幾分鐘時間
echo.

REM 設置 Gradle 緩存目錄
set GRADLE_USER_HOME=E:\.gradle

echo 📦 安裝依賴套件...
flutter pub get

echo.
echo 🔨 開始構建 APK...
flutter build apk --debug

if errorlevel 1 (
    echo.
    echo ❌ APK 構建失敗
    echo.
    echo 💡 可能的解決方案：
    echo    1. 檢查專案路徑是否包含中文字符（建議移到英文路徑）
    echo    2. 確認 Android SDK 已正確安裝
    echo    3. 執行 flutter doctor 檢查環境
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ APK 構建成功！
echo ========================================
echo.
echo 📍 APK 位置：
echo    %CD%\build\app\outputs\flutter-apk\app-debug.apk
echo.
echo 📱 安裝步驟：
echo    1. 將 APK 檔案傳到手機
echo    2. 在手機上開啟 APK 檔案
echo    3. 允許安裝未知來源的應用程式
echo    4. 完成安裝後即可使用
echo.
echo ⚠️  重要：確保後端服務正在運行！
echo    後端 API: http://電腦IP:5000
echo.
pause
exit /b 0

:web_mobile
echo.
echo ========================================
echo 🌐 啟動 Web 版本（手機瀏覽器訪問）
echo ========================================
echo.

echo 📦 安裝依賴套件...
flutter pub get

echo.
echo 🔍 獲取電腦 IP 地址...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set ip=%%a
    set ip=!ip: =!
    goto :found_ip
)
:found_ip

echo.
echo ========================================
echo ✅ 前端服務啟動中...
echo ========================================
echo.
echo 📍 電腦 IP 地址: %ip%
echo 📍 訪問地址: http://%ip%:8080
echo.
echo 📱 手機訪問步驟：
echo    1. 確保手機和電腦連接同一個 Wi-Fi
echo    2. 在手機瀏覽器中輸入：http://%ip%:8080
echo    3. 如果無法訪問，請檢查防火牆設定
echo.
echo ⚠️  重要：確保後端服務正在運行！
echo    後端 API: http://%ip%:5000
echo.
echo 💡 提示：保持此視窗開啟，按 Ctrl+C 可停止服務
echo.

flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080

pause
exit /b 0

:run_device
echo.
echo ========================================
echo 📱 運行到已連接的手機設備（USB）
echo ========================================
echo.

echo 🔍 檢查已連接的設備...
echo.
flutter devices

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

echo 📦 安裝/更新依賴套件...
flutter pub get

echo.
echo ========================================
echo ✅ 啟動應用...
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

flutter run

pause
exit /b 0

:invalid_choice
echo.
echo ❌ 無效的選項，請重新執行並選擇 1、2 或 3
pause
exit /b 1

