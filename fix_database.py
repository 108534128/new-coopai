#!/usr/bin/env python3
"""
修正 cookpal.users 表結構
"""

import pymysql

# 資料庫配置
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',
    'charset': 'utf8mb4'
}

DATABASE_NAME = 'cookpal'

def fix_users_table():
    """修正 users 表結構"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        cursor = connection.cursor()
        
        # 使用 cookpal 資料庫
        cursor.execute(f"USE {DATABASE_NAME}")
        
        # 檢查現有表結構
        cursor.execute("DESCRIBE users")
        columns = cursor.fetchall()
        print("現有表結構:")
        for col in columns:
            print(f"  {col}")
        
        # 修正 uid 欄位為 AUTO_INCREMENT
        cursor.execute("ALTER TABLE users MODIFY COLUMN uid INT AUTO_INCREMENT PRIMARY KEY")
        print("✅ uid 欄位已設定為 AUTO_INCREMENT")
        
        # 修正 name 欄位允許 NULL
        cursor.execute("ALTER TABLE users MODIFY COLUMN name VARCHAR(100) NULL")
        print("✅ name 欄位已設定為允許 NULL")
        
        connection.commit()
        cursor.close()
        connection.close()
        
        print("🎉 資料庫表結構修正完成！")
        return True
        
    except Exception as e:
        print(f"❌ 修正資料庫時發生錯誤: {e}")
        return False

if __name__ == "__main__":
    print("🔧 開始修正 cookpal.users 表結構...")
    print("=" * 50)
    fix_users_table()