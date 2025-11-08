@echo off
REM 啟動 Web 版本，讓手機可以通過區域網路訪問

echo ========================================
echo 啟動 Flutter Web 版本（手機可訪問）
echo ========================================
echo.

REM 獲取本機 IP 地址
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set IP=%%a
    goto :found
)
:found
set IP=%IP: =%

echo 本機 IP 地址: %IP%
echo.
echo 手機訪問方式：
echo 1. 確保手機和電腦在同一 Wi-Fi 網路
echo 2. 在手機瀏覽器中訪問: http://%IP%:端口號
echo 3. 端口號會在下方顯示
echo.
echo ========================================
echo.

REM 切換到前端目錄
cd /d "%~dp0"

REM 啟動 Flutter Web（監聽所有網路介面）
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080

pause

