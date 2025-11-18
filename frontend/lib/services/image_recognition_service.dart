import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

// 只在非 Web 平台導入 ONNX Runtime
// 注意：Web 平台編譯時會失敗，請使用 Android 或 iOS 平台
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' if (dart.library.html) 'image_recognition_service_stub.dart';

/// 影像辨識服務 - 離線使用 ONNX 模型辨識食材
/// 
/// 注意：此功能僅支援 Android 和 iOS 平台，不支援 Web 平台
class ImageRecognitionService {
  OrtSession? _session;
  OnnxRuntime? _onnxRuntime;
  List<String>? _classes;
  Map<String, String>? _chineseMap;
  Map<String, String>? _labelFixes;
  bool _isInitialized = false;

  /// 初始化模型和資料
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Web 平台不支援 ONNX Runtime
    if (kIsWeb) {
      throw UnsupportedError('影像辨識功能在 Web 平台上不支援，請使用 Android 或 iOS 平台');
    }

    try {
      print('🔄 開始載入影像辨識模型...');

      // 1. 初始化 ONNX Runtime
      _onnxRuntime = OnnxRuntime();
      print('✅ ONNX Runtime 初始化完成');

      // 2. 載入 ONNX 模型
      _session = await _onnxRuntime!.createSessionFromAsset('assets/models/best.onnx');
      print('✅ 模型載入完成');

      // 3. 載入類別清單
      final classesJson = await rootBundle.loadString('assets/data/classes.json');
      _classes = List<String>.from(json.decode(classesJson));
      print('✅ 類別清單載入完成 (${_classes!.length} 個類別)');

      // 4. 載入中英文對應表
      final chineseJson = await rootBundle.loadString('assets/data/chinese_map.json');
      _chineseMap = Map<String, String>.from(json.decode(chineseJson));
      print('✅ 中英文對應表載入完成');

      // 5. 載入標籤修正表
      final fixesJson = await rootBundle.loadString('assets/data/label_fixes.json');
      _labelFixes = Map<String, String>.from(json.decode(fixesJson));
      print('✅ 標籤修正表載入完成');

      _isInitialized = true;
      print('✅ 影像辨識服務初始化完成！');
    } catch (e, stackTrace) {
      print('❌ 初始化失敗: $e');
      print('❌ 堆疊追蹤: $stackTrace');
      rethrow;
    }
  }

  /// 辨識圖片中的食材
  /// 
  /// 返回辨識結果，包含：
  /// - message: 文字訊息（例如："有 2 個 高麗菜, 1 個 紅蘿蔔"）
  /// - count: 檢測到的食材總數
  /// - ingredients: 食材名稱和數量的對應表
  /// - detections: 詳細的檢測結果列表
  Future<Map<String, dynamic>> recognize(File imageFile) async {
    // Web 平台不支援
    if (kIsWeb) {
      throw UnsupportedError('影像辨識功能在 Web 平台上不支援，請使用 Android 或 iOS 平台');
    }

    if (!_isInitialized || _session == null) {
      throw Exception('模型尚未載入，請先呼叫 initialize()');
    }

    try {
      print('🔄 開始辨識圖片: ${imageFile.path}');

      // 1. 讀取並預處理圖片
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('無法解碼圖片');
      }

      print('📷 原始圖片尺寸: ${image.width}x${image.height}');

      // 調整大小為 640x640（模型輸入尺寸）
      final resized = img.copyResize(image, width: 640, height: 640);
      print('📐 調整後尺寸: ${resized.width}x${resized.height}');

      // 轉換為模型輸入格式（RGB，正規化到 0-1）
      final inputData = _preprocessImage(resized);
      print('✅ 圖片預處理完成');

      // 2. 創建輸入張量
      // 注意：需要根據模型的實際輸入名稱調整，這裡假設是 'images' 或第一個輸入名稱
      final inputName = _session!.inputNames.isNotEmpty ? _session!.inputNames[0] : 'images';
      final inputTensor = await OrtValueTensor.createTensorWithDataAsList(
        inputData,
        [1, 3, 640, 640],
      );
      print('✅ 輸入張量創建完成');

      // 3. 執行模型推理
      final inputs = {inputName: inputTensor};
      final outputs = await _session!.run(inputs) as Map<String, OrtValue>;
      print('✅ 模型推理完成');

      // 4. 處理輸出結果
      final detections = await _processOutputs(outputs);
      print('✅ 檢測到 ${detections.length} 個物件');

      // 5. 應用標籤修正
      final fixedDetections = detections.map((det) {
        final classId = det['class_id'] as int;
        final rawName = _classes![classId];
        final fixedName = _labelFixes![rawName] ?? rawName;
        final chineseName = _chineseMap![fixedName] ?? fixedName;

        return {
          'class_id': classId,
          'raw_name': rawName,
          'fixed_name': fixedName,
          'chinese_name': chineseName,
          'confidence': det['confidence'],
          'bbox': det['bbox'],
        };
      }).toList();

      // 6. 統計數量
      final counts = <String, int>{};
      for (var det in fixedDetections) {
        final name = det['chinese_name'] as String;
        counts[name] = (counts[name] ?? 0) + 1;
      }

      // 7. 生成訊息
      String message;
      if (counts.isEmpty) {
        message = '未檢測到任何食材';
      } else {
        message = '有 ' + counts.entries.map((e) => '${e.value} 個 ${e.key}').join(', ');
      }

      print('✅ 辨識完成: $message');

      // 釋放輸入張量資源
      await inputTensor.dispose();

      return {
        'message': message,
        'count': fixedDetections.length,
        'ingredients': counts,
        'detections': fixedDetections,
      };
    } catch (e, stackTrace) {
      print('❌ 辨識失敗: $e');
      print('❌ 堆疊追蹤: $stackTrace');
      rethrow;
    }
  }

  /// 預處理圖片（轉換為模型輸入格式）
  /// 
  /// 將圖片轉換為 [1, 3, 640, 640] 的格式
  /// - 通道順序：RGB
  /// - 數值範圍：0.0 - 1.0（正規化）
  Float32List _preprocessImage(img.Image image) {
    final data = Float32List(1 * 3 * 640 * 640);

    int index = 0;
    for (var y = 0; y < 640; y++) {
      for (var x = 0; x < 640; x++) {
        // 從 Pixel 物件中提取 RGB 值
        // image 套件中，getPixel 返回 Pixel 物件，可以直接訪問 r, g, b 屬性
        final pixel = image.getPixel(x, y);
        
        // Pixel 物件有 r, g, b 屬性
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        data[index++] = (r.toDouble() / 255.0);   // R
        data[index++] = (g.toDouble() / 255.0);   // G
        data[index++] = (b.toDouble() / 255.0);   // B
      }
    }

    return data;
  }

  /// 處理模型輸出
  /// 
  /// YOLO 模型輸出格式通常為：
  /// - 檢測框座標：x1, y1, x2, y2
  /// - 類別 ID：0-25
  /// - 信心度：0.0 - 1.0
  Future<List<Map<String, dynamic>>> _processOutputs(Map<String, OrtValue> outputs) async {
    // 注意：這裡需要根據實際的 ONNX 模型輸出格式進行調整
    // 以下是一個簡化的範例實現
    
    if (outputs.isEmpty) {
      return [];
    }

    final detections = <Map<String, dynamic>>[];
    final confidenceThreshold = 0.5; // 信心度閾值

    try {
      // 獲取第一個輸出（通常 YOLO 模型只有一個輸出）
      final output = outputs.values.first;
      final outputData = await output.asFlattenedList();
      
      // YOLO 輸出通常是 [num_detections, 6] 或 [num_detections, 85] 等格式
      // 其中可能包含 [x1, y1, x2, y2, confidence, class_id] 或類似的格式
      // 實際格式需要根據模型調整
      
      // 這裡假設輸出是 [num_detections, 6] 格式
      // 實際可能需要根據模型的實際輸出格式調整
      final numDetections = outputData.length ~/ 6; // 假設每個檢測有 6 個值
      
      for (var i = 0; i < numDetections; i++) {
        final baseIndex = i * 6;
        if (baseIndex + 5 < outputData.length) {
          final confidence = (outputData[baseIndex + 4] as num).toDouble();
          
          if (confidence >= confidenceThreshold) {
            detections.add({
              'bbox': [
                (outputData[baseIndex + 0] as num).toDouble(), // x1
                (outputData[baseIndex + 1] as num).toDouble(), // y1
                (outputData[baseIndex + 2] as num).toDouble(), // x2
                (outputData[baseIndex + 3] as num).toDouble(), // y2
              ],
              'confidence': confidence,
              'class_id': (outputData[baseIndex + 5] as num).toInt(),
            });
          }
        }
      }
      
      // 釋放輸出張量資源
      for (var output in outputs.values) {
        await output.dispose();
      }
    } catch (e) {
      print('⚠️ 解析模型輸出時發生錯誤: $e');
      print('⚠️ 輸出格式可能需要調整');
      
      // 釋放輸出張量資源
      for (var output in outputs.values) {
        await output.dispose();
      }
    }

    return detections;
  }

  /// 檢查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 釋放資源
  Future<void> dispose() async {
    if (_session != null) {
      await _session!.close();
      _session = null;
    }
    _onnxRuntime = null;
    _isInitialized = false;
    print('🗑️ 影像辨識服務資源已釋放');
  }
}
