#!/usr/bin/env python3
"""
Flask 應用程式啟動腳本
"""

from app import app

if __name__ == '__main__':
    print("🚀 啟動智慧食材辨識與食譜推薦系統後端...")
    print("📍 API 端點: http://localhost:5000")
    print("🔍 健康檢查: http://localhost:5000/api/health")
    print("📚 API 文檔: http://localhost:5000/api")
    print("=" * 50)
    
    app.run(
        debug=True,
        host='0.0.0.0',
        port=5000,
        threaded=True
    )