@echo off
chcp 65001 >nul
echo ========================================
echo   Ngrok 後端 API 隧道啟動腳本
echo ========================================
echo.

echo [1/3] 啟動後端服務...
start "後端服務" cmd /k "cd /d %~dp0backend && python run.py"

timeout /t 3 /nobreak >nul

echo.
echo [2/3] 啟動 Ngrok 隧道...
echo 請注意：ngrok 會顯示一個 HTTPS 地址
echo 例如：https://abc123.ngrok-free.app
echo.
start "Ngrok 隧道" cmd /k "ngrok http 5000"

timeout /t 5 /nobreak >nul

echo.
echo [3/3] 請執行以下步驟：
echo.
echo 1. 查看 Ngrok 視窗，複製 HTTPS 地址
echo    例如：https://abc123-def456.ngrok-free.app
echo.
echo 2. 在新的終端執行：
echo    cd frontend
echo    flutter run --dart-define=API_HOST=您的ngrok地址
echo.
echo 或者直接執行：
echo    flutter run --dart-define=API_HOST=https://abc123-def456.ngrok-free.app
echo.
echo ========================================
pause

