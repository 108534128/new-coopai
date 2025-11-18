# 📱 影像辨識模型 - 給組員的檔案

## 📦 檔案說明

這個資料夾包含所有需要的檔案，讓你可以將影像辨識功能內建在 APP 中，**完全離線使用**。

### 檔案清單

1. **best.onnx** (98.85 MB)
   - 訓練好的影像辨識模型
   - 可以識別 26 種食材
   - 輸入尺寸：640x640 像素

2. **classes.json**
   - 26 個類別的英文名稱清單
   - 按 class_id 順序排列（0-25）

3. **chinese_map.json**
   - 英文類別名稱 → 中文名稱的對應表
   - 用於顯示中文名稱

4. **label_fixes.json**
   - 模型識別錯誤時的修正規則
   - 例如：模型識別為 "tomato" 時，實際應該是 "avocado"

5. **離線使用方案.md**
   - 完整的整合說明文件
   - 包含 Flutter 程式碼範例

---

## 🚀 快速開始

### 步驟 1: 將檔案放入 Flutter 專案

#### 模型檔案
```
your_flutter_project/
└── assets/
    └── models/
        └── best.onnx  ← 放在這裡
```

#### 資料檔案
```
your_flutter_project/
└── assets/
    └── data/
        ├── classes.json       ← 放在這裡
        ├── chinese_map.json   ← 放在這裡
        └── label_fixes.json  ← 放在這裡
```

### 步驟 2: 更新 pubspec.yaml

```yaml
flutter:
  assets:
    - assets/models/best.onnx
    - assets/data/classes.json
    - assets/data/chinese_map.json
    - assets/data/label_fixes.json

dependencies:
  onnxruntime: ^1.16.0  # ONNX Runtime
  image: ^4.0.0          # 圖片處理
```

### 步驟 3: 安裝依賴

```bash
flutter pub get
```

### 步驟 4: 實作辨識功能

參考 `離線使用方案.md` 中的完整程式碼範例。

---

## 📋 類別清單（26 種食材）

| ID | 英文名稱 | 中文名稱 |
|----|---------|---------|
| 0 | tomato | 番茄 |
| 1 | broccoli | 青花菜 |
| 2 | onion | 洋蔥 |
| 3 | potato | 馬鈴薯 |
| 4 | avocado | 酪梨 |
| 5 | beans | 豆豆 |
| 6 | beet | 甜菜根 |
| 7 | bell pepper | 青椒 |
| 8 | brus capusta | 抱子甘藍 |
| 9 | cabbage | 高麗菜 |
| 10 | carrot | 紅蘿蔔 |
| 11 | cayliflower | 花椰菜 |
| 12 | celery | 芹菜 |
| 13 | corn | 玉米 |
| 14 | cucumber | 小黃瓜 |
| 15 | eggplant | 茄子 |
| 16 | fasol | 豆豆 |
| 17 | garlic | 大蒜 |
| 18 | hot pepper | 辣椒 |
| 19 | peas | 豌豆 |
| 20 | pumpkin | 南瓜 |
| 21 | rediska | 蘿蔔 |
| 22 | redka | 蘿蔔 |
| 23 | salad | 生菜 |
| 24 | squash-patisson | 櫛瓜 |
| 25 | vegetable marrow | 西葫蘆 |

---

## 🔧 使用流程

1. **載入模型** → 從 assets 載入 best.onnx
2. **載入資料** → 讀取 JSON 檔案
3. **預處理圖片** → 調整為 640x640，轉換為 RGB
4. **執行推理** → 模型識別圖片中的食材
5. **後處理** → 應用 label_fixes 修正錯誤
6. **轉換中文** → 使用 chinese_map 轉換為中文
7. **統計數量** → 計算每種食材的數量
8. **顯示結果** → 生成文字訊息（例如："有 2 個 高麗菜, 1 個 紅蘿蔔"）

---

## ⚠️ 注意事項

### 模型輸入
- **尺寸**：640 x 640 像素
- **格式**：RGB
- **數值範圍**：0.0 - 1.0（需要正規化）

### 模型輸出
- **檢測框座標**：x1, y1, x2, y2
- **類別 ID**：0-25（對應 classes.json）
- **信心度**：0.0 - 1.0（建議閾值：0.5）

### 標籤修正
- `label_fixes.json` 中的規則會自動應用
- 例如：模型識別為 "tomato" → 自動修正為 "avocado"
- 這是為了修正模型常見的識別錯誤

---

## 📞 需要幫助？

1. 查看 `離線使用方案.md` 的完整說明
2. 檢查 Flutter 的錯誤訊息
3. 確認所有檔案都在正確的 assets 資料夾
4. 確認 `pubspec.yaml` 中的路徑正確

---

## ✅ 檢查清單

- [ ] best.onnx 已放入 `assets/models/`
- [ ] 3 個 JSON 檔案已放入 `assets/data/`
- [ ] `pubspec.yaml` 已更新
- [ ] 已執行 `flutter pub get`
- [ ] 已參考 `離線使用方案.md` 實作程式碼

---

**祝整合順利！** 🎉

如有問題，請查看 `離線使用方案.md` 或聯繫後端開發人員。

