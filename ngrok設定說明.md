# Ngrok 設定說明 - 後端 API 隧道

## 📋 步驟 1: 建立 Ngrok 隧道

為後端 API（port 5000）建立 ngrok 隧道：

```bash
ngrok http 5000
```

執行後，ngrok 會顯示類似這樣的資訊：

```
Forwarding   https://abc123.ngrok-free.app -> http://localhost:5000
```

**記下這個地址**：`abc123.ngrok-free.app`（您的地址會不同）

## 📋 步驟 2: 設定 APP 使用 Ngrok 地址

### 方法 A: 使用環境變數（推薦）

在執行 Flutter APP 時，使用 `--dart-define` 參數：

```bash
cd frontend
flutter run --dart-define=API_HOST=https://abc123.ngrok-free.app
```

### 方法 B: 修改程式碼直接設定

在 `frontend/lib/services/api_service.dart` 中，找到 `baseUrl` getter，暫時修改為：

```dart
static String get baseUrl {
  // 暫時使用 ngrok 地址
  return 'https://abc123.ngrok-free.app/api';
  
  // 或使用環境變數
  if (_envApiHost.isNotEmpty) {
    return _envApiHost.replaceAll(RegExp(r'\/+\$'), '') + '/api';
  }
  // ... 其他程式碼
}
```

### 方法 C: 使用 SharedPreferences 儲存（需要修改程式碼）

可以添加一個設定畫面，讓用戶手動輸入 ngrok 地址。

## 📋 步驟 3: 確保後端正在運行

在建立 ngrok 隧道之前，確保後端服務正在運行：

```bash
cd backend
python run.py
```

您應該看到：
```
 * Running on http://0.0.0.0:5000
```

## 📋 步驟 4: 測試連接

1. 啟動 ngrok 隧道
2. 啟動後端服務
3. 使用 ngrok 地址啟動 Flutter APP
4. 嘗試登入

## ⚠️ 注意事項

1. **免費版限制**：
   - ngrok 免費版每次重新啟動會改變地址
   - 每次重新啟動 ngrok 後，需要更新 APP 中的地址

2. **HTTPS vs HTTP**：
   - ngrok 免費版使用 HTTPS
   - 確保後端支援 HTTPS（Flask 預設支援）

3. **ngrok 警告頁面**：
   - 免費版首次訪問會顯示警告頁面
   - 點擊 "Visit Site" 即可繼續

4. **同時運行多個隧道**：
   - 您已經有一個資料庫隧道（tcp://0.tcp.jp.ngrok.io:14672）
   - 現在需要另一個 HTTP 隧道（http://localhost:5000）
   - 兩個隧道可以同時運行

## 🔧 快速測試命令

```bash
# 終端 1: 啟動後端
cd backend
python run.py

# 終端 2: 啟動 ngrok
ngrok http 5000

# 終端 3: 啟動 Flutter APP（使用 ngrok 地址）
cd frontend
flutter run --dart-define=API_HOST=https://您的ngrok地址.ngrok-free.app
```

## 📝 範例

假設 ngrok 顯示：
```
Forwarding   https://abc123-def456.ngrok-free.app -> http://localhost:5000
```

則執行：
```bash
flutter run --dart-define=API_HOST=https://abc123-def456.ngrok-free.app
```

## 🎯 自動化腳本（可選）

您可以建立一個批次檔來自動啟動：

**start_with_ngrok.bat**:
```batch
@echo off
echo 啟動後端服務...
start "後端" cmd /k "cd backend && python run.py"

timeout /t 3

echo 啟動 ngrok 隧道...
start "Ngrok" cmd /k "ngrok http 5000"

echo 請複製 ngrok 顯示的 HTTPS 地址，然後按任意鍵繼續...
pause

echo 啟動 Flutter APP...
cd frontend
flutter run --dart-define=API_HOST=https://請替換為您的ngrok地址.ngrok-free.app
```

