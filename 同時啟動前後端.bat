@echo off
chcp 65001 >nul
echo ========================================
echo 🚀 同時啟動前後端服務
echo ========================================
echo.

REM 獲取當前腳本目錄
set "SCRIPT_DIR=%~dp0"

echo 📍 專案目錄: %SCRIPT_DIR%
echo.

REM 啟動後端（在新視窗中）
echo 🚀 啟動後端伺服器...
start "後端伺服器 - Flask" cmd /k "cd /d "%SCRIPT_DIR%backend" && python run.py"

REM 等待後端啟動
timeout /t 3 /nobreak >nul

REM 啟動前端（在新視窗中）
echo 🚀 啟動前端應用...
start "前端應用 - Flutter" cmd /k "cd /d "%SCRIPT_DIR%frontend" && flutter pub get && flutter run -d chrome"

echo.
echo ========================================
echo ✅ 前後端已啟動！
echo ========================================
echo.
echo 📍 後端 API: http://localhost:5000
echo 📍 前端應用: 將在瀏覽器中開啟
echo.
echo 💡 提示：
echo    - 兩個視窗都會保持開啟
echo    - 關閉視窗即可停止對應的服務
echo    - 請確保後端先啟動完成再使用前端
echo.

pause

