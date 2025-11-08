@echo off
chcp 65001 >nul
echo ========================================
echo 🚀 啟動後端伺服器 (Flask)
echo ========================================
echo.

cd /d "%~dp0backend"

echo 📦 檢查 Python 環境...
python --version
if errorlevel 1 (
    echo ❌ 錯誤：找不到 Python，請先安裝 Python
    pause
    exit /b 1
)

echo.
echo 📦 檢查依賴套件...
if not exist "requirements.txt" (
    echo ❌ 錯誤：找不到 requirements.txt
    pause
    exit /b 1
)

echo.
echo 🔧 安裝/更新依賴套件...
pip install -q -r requirements.txt

echo.
echo ========================================
echo ✅ 啟動後端伺服器...
echo 📍 API 端點: http://localhost:5000
echo 🔍 健康檢查: http://localhost:5000/api/health
echo ========================================
echo.
echo 💡 提示：保持此視窗開啟，後端服務正在運行
echo 💡 按 Ctrl+C 可停止服務
echo.

python run.py

pause

