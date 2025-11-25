# 食材辨識模型使用說明

## 📦 檔案說明

- `best.onnx`: 訓練好的食材辨識模型（ONNX 格式）
- `classes.json`: 類別名稱清單（26 個食材類別）
- `chinese_map.json`: 英文類別名稱對應中文名稱
- `label_fixes.json`: 標籤修正表（修正模型識別錯誤）

## 🚀 API 使用方式

### 1. 檢查模型狀態

```bash
GET /api/recognize-ingredients/status
```

**回應範例：**
```json
{
  "status": "success",
  "model_loaded": true,
  "model_path": "backend/models/best.onnx",
  "classes_count": 27,
  "chinese_map_count": 27,
  "label_fixes_count": 10
}
```

### 2. 上傳圖片進行辨識

```bash
POST /api/recognize-ingredients
Content-Type: multipart/form-data
Authorization: Bearer <your_jwt_token>

# 表單欄位：
# - image: 圖片檔案（支援 png, jpg, jpeg, gif, bmp, webp）
```

**回應範例：**
```json
{
  "status": "success",
  "message": "有 2 個 番茄, 1 個 高麗菜",
  "count": 3,
  "ingredients": {
    "番茄": 2,
    "高麗菜": 1
  },
  "detections": [
    {
      "raw_name": "tomato",
      "fixed_name": "tomato",
      "chinese_name": "番茄",
      "confidence": 0.85,
      "bbox": [100, 150, 200, 250]
    },
    ...
  ]
}
```

## 📱 手機測試步驟

1. **安裝依賴**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **啟動後端服務**
   ```bash
   python app.py
   ```
   或使用提供的批次檔：
   ```bash
   啟動後端.bat
   ```

3. **確認模型已載入**
   - 查看後端啟動時的日誌，應該會看到：
     ```
     📦 正在載入模型：...
     ✅ 模型載入成功
     ✅ 載入 27 個類別
     ✅ 載入中英文對應表
     ✅ 載入標籤修正表
     ```

4. **從手機測試**
   - 確保手機和電腦在同一個網路
   - 使用手機的 IP 地址訪問 API（例如：`http://192.168.1.100:5000/api/recognize-ingredients`）
   - 使用 Postman 或類似的工具上傳圖片測試

## ⚠️ 注意事項

1. **模型載入時間**：首次啟動時，模型載入可能需要幾秒鐘
2. **圖片格式**：支援常見的圖片格式（png, jpg, jpeg, gif, bmp, webp）
3. **圖片大小**：建議圖片大小不超過 10MB
4. **辨識速度**：每張圖片辨識時間約 0.5-2 秒（取決於硬體性能）
5. **信心度閾值**：目前設定為 0.25，可以根據需要調整

## 🔧 疑難排解

### 模型載入失敗
- 檢查 `backend/models/best.onnx` 檔案是否存在
- 確認檔案路徑正確
- 檢查是否有足夠的記憶體

### 辨識結果不準確
- 檢查圖片品質（光線、清晰度）
- 確認圖片中包含的食材在類別清單中
- 可以調整信心度閾值（在 `app.py` 的 `recognize` 方法中）

### API 無法訪問
- 確認後端服務正在運行
- 檢查防火牆設定
- 確認手機和電腦在同一個網路

## 📝 模型輸出格式說明

模型輸出格式可能因 YOLO 版本而異，目前程式碼已支援：
- 格式1: `[x, y, w, h, confidence, class_id]`
- 格式2: `[x, y, w, h, confidence, class_scores...]` (YOLOv5/v8)

如果辨識結果異常，可能需要根據實際模型輸出格式調整 `app.py` 中的解析邏輯。

