#!/usr/bin/env python3
"""
資料庫初始化腳本
用於建立資料庫和插入測試資料
"""

import pymysql
import hashlib
import os
from datetime import datetime

# 資料庫配置
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '456',  # 請修改為您的MySQL密碼
    'charset': 'utf8mb4'
}

DATABASE_NAME = 'cookpal'

def create_database():
    """建立資料庫"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        cursor = connection.cursor()
        
        # 讀取並執行 schema.sql
        with open('schema.sql', 'r', encoding='utf-8') as f:
            sql_script = f.read()
        
        # 分割 SQL 語句並執行
        sql_statements = [stmt.strip() for stmt in sql_script.split(';') if stmt.strip()]
        
        for statement in sql_statements:
            if statement:
                cursor.execute(statement)
        
        print(f"✅ 資料庫 {DATABASE_NAME} 建立成功")
        print("✅ 用戶表建立成功")
        print("✅ 索引建立成功")
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return True
        
    except Exception as e:
        print(f"❌ 建立資料庫時發生錯誤: {e}")
        return False

def hash_password(password):
    """密碼雜湊"""
    return hashlib.sha256(password.encode()).hexdigest()

def insert_test_data():
    """插入測試資料"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        cursor = connection.cursor()
        cursor.execute(f"USE {DATABASE_NAME}")
        
        # 檢查是否已有測試用戶
        cursor.execute("SELECT COUNT(*) FROM users WHERE username = 'testuser'")
        if cursor.fetchone()[0] > 0:
            print("ℹ️ 測試用戶已存在，跳過插入")
            return True
        
        # 插入測試用戶
        test_users = [
            {
                'username': 'testuser',
                'email': 'test@example.com',
                'password': 'password123',
                'full_name': '測試用戶'
            },
            {
                'username': 'admin',
                'email': 'admin@example.com',
                'password': 'admin123',
                'full_name': '管理員'
            },
            {
                'username': 'demo',
                'email': 'demo@example.com',
                'password': 'demo123',
                'full_name': '示範用戶'
            }
        ]
        
        for user in test_users:
            password_hash = hash_password(user['password'])
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name)
                VALUES (%s, %s, %s, %s)
            """, (user['username'], user['email'], password_hash, user['full_name']))
        
        connection.commit()
        print("✅ 測試資料插入成功")
        
        # 顯示插入的用戶
        cursor.execute("SELECT username, email, full_name FROM users")
        users = cursor.fetchall()
        print("\n📋 已建立的用戶:")
        for user in users:
            print(f"  - {user[0]} ({user[1]}) - {user[2]}")
        
        cursor.close()
        connection.close()
        
        return True
        
    except Exception as e:
        print(f"❌ 插入測試資料時發生錯誤: {e}")
        return False

def test_connection():
    """測試資料庫連接"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        cursor = connection.cursor()
        cursor.execute("SELECT VERSION()")
        version = cursor.fetchone()
        print(f"✅ MySQL 連接成功，版本: {version[0]}")
        
        cursor.close()
        connection.close()
        return True
        
    except Exception as e:
        print(f"❌ 資料庫連接失敗: {e}")
        print("請確認:")
        print("1. MySQL 服務是否正在運行")
        print("2. 用戶名和密碼是否正確")
        print("3. 是否已安裝 PyMySQL: pip install PyMySQL")
        return False

def main():
    """主函數"""
    print("🚀 開始初始化資料庫...")
    print("=" * 50)
    
    # 測試連接
    if not test_connection():
        return
    
    # 建立資料庫
    if not create_database():
        return
    
    print("=" * 50)
    print("🎉 資料庫初始化完成！")
    print("\n🔧 下一步:")
    print("1. 啟動 Flask 後端: python backend/app.py")
    print("2. 啟動 Flutter 前端: flutter run")

if __name__ == "__main__":
    main()