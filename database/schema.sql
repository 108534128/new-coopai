-- 智慧食材辨識與個人化食譜推薦系統資料庫設計
-- 建立資料庫
CREATE DATABASE IF NOT EXISTS food_recommendation_system 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE food_recommendation_system;

-- 用戶表
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 建立索引以提升查詢效能
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);