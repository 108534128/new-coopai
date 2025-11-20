// frontend/lib/services/food_detection_service.dart
// 真實實現版本（用於 Android/iOS/Desktop）

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

class FoodDetectionService {
  OrtSession? _session;
  List<String>? _classes;
  Map<String, String>? _chineseMap;
  Map<String, String>? _labelFixes;
  bool _isInitialized = false;

  // 模型參數
  static const int inputWidth = 640;
  static const int inputHeight = 640;
  static const double confidenceThreshold = 0.5;
  static const double iouThreshold = 0.4;

  /// 初始化服務，載入模型和資料
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ FoodDetectionService 已經初始化');
      return;
    }

    try {
      print('🚀 開始初始化 FoodDetectionService...');

      // 1. 載入模型
      print('📦 載入 ONNX 模型...');
      final modelBytes = await rootBundle.load('assets/models/best.onnx');
      final modelData = modelBytes.buffer.asUint8List();
      
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(modelData, sessionOptions);
      print('✅ 模型載入成功');

      // 2. 載入類別清單
      print('📦 載入類別清單...');
      final classesJson = await rootBundle.loadString('assets/data/classes.json');
      _classes = List<String>.from(json.decode(classesJson));
      print('✅ 載入 ${_classes!.length} 個類別');

      // 3. 載入中文對照表
      print('📦 載入中文對照表...');
      final chineseJson = await rootBundle.loadString('assets/data/chinese_map.json');
      _chineseMap = Map<String, String>.from(json.decode(chineseJson));
      print('✅ 中文對照表載入成功');

      // 4. 載入標籤修正規則
      print('📦 載入標籤修正規則...');
      final fixesJson = await rootBundle.loadString('assets/data/label_fixes.json');
      _labelFixes = Map<String, String>.from(json.decode(fixesJson));
      print('✅ 標籤修正規則載入成功');

      _isInitialized = true;
      print('🎉 FoodDetectionService 初始化完成');
    } catch (e) {
      print('❌ FoodDetectionService 初始化失敗: $e');
      rethrow;
    }
  }

  /// 檢測食材
  Future<Map<String, int>> detectFood(String imagePath) async {
    if (!_isInitialized) {
      throw Exception('服務尚未初始化，請先呼叫 initialize()');
    }

    try {
      print('🔍 開始辨識圖片: $imagePath');

      // 1. 載入並預處理圖片
      final inputTensor = await _preprocessImage(imagePath);
      
      // 2. 執行推理
      print('🧠 執行模型推理...');
      
      final inputTensorOrt = OrtValueTensor.createTensorWithDataList(
        inputTensor,
        [1, 3, inputHeight, inputWidth],
      );
      final inputs = {'images': inputTensorOrt};
      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, inputs);
      
      // 3. 後處理結果
      print('📊 處理輸出結果...');
      final detections = _postprocess(outputs.isNotEmpty ? outputs[0] : null);
      
      // 4. 應用標籤修正
      final correctedDetections = _applyLabelFixes(detections);
      
      // 5. 統計每種食材的數量
      final result = _countIngredients(correctedDetections);
      
      print('✅ 辨識完成，找到 ${result.length} 種食材');
      return result;
    } catch (e) {
      print('❌ 辨識過程發生錯誤: $e');
      rethrow;
    }
  }

  /// 預處理圖片
  Future<Float32List> _preprocessImage(String imagePath) async {
    print('🖼️ 預處理圖片...');
    
    // 讀取圖片
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);
    
    if (image == null) {
      throw Exception('無法解碼圖片');
    }

    // 調整大小為 640x640
    image = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.linear,
    );

    // 轉換為模型輸入格式 [1, 3, 640, 640] 並展平為一維陣列
    // 格式: NCHW (Batch, Channels, Height, Width)
    // 使用 Float32List 確保資料類型為 float32
    final inputSize = 1 * 3 * inputHeight * inputWidth;
    final input = Float32List(inputSize);
    var index = 0;
    
    // 按照 NCHW 順序：Batch -> Channel -> Height -> Width
    for (var c = 0; c < 3; c++) { // RGB channels
      for (var h = 0; h < inputHeight; h++) {
        for (var w = 0; w < inputWidth; w++) {
          final pixel = image.getPixel(w, h);
          final value = c == 0
              ? pixel.r / 255.0
              : c == 1
                  ? pixel.g / 255.0
                  : pixel.b / 255.0;
          input[index++] = value;
        }
      }
    }

    print('✅ 圖片預處理完成，張量大小: ${input.length}');
    return input;
  }

  /// 後處理模型輸出
  List<Detection> _postprocess(OrtValue? outputs) {
    if (outputs == null) {
      return [];
    }

    final detections = <Detection>[];
    
    try {
      // 獲取輸出張量數據
      // YOLOv8 輸出格式: [1, 84, 8400] 或類似
      // 其中 84 = 4 (bbox) + 80 (classes)
      final outputData = (outputs as OrtValueTensor).value as List;
      
      // 解析檢測結果
      for (var i = 0; i < outputData.length; i++) {
        final detection = outputData[i];
        
        // 提取邊界框座標
        final x1 = detection[0] as double;
        final y1 = detection[1] as double;
        final x2 = detection[2] as double;
        final y2 = detection[3] as double;
        
        // 提取類別和信心度
        double maxConfidence = 0.0;
        int classId = 0;
        
        for (var j = 4; j < detection.length; j++) {
          final confidence = detection[j] as double;
          if (confidence > maxConfidence) {
            maxConfidence = confidence;
            classId = j - 4;
          }
        }
        
        // 過濾低信心度的檢測
        if (maxConfidence >= confidenceThreshold) {
          detections.add(Detection(
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            confidence: maxConfidence,
            classId: classId,
          ));
        }
      }
      
      // 應用 NMS (非極大值抑制)
      final nmsDetections = _applyNMS(detections);
      print('📊 NMS 後保留 ${nmsDetections.length} 個檢測框');
      
      return nmsDetections;
    } catch (e) {
      print('❌ 後處理錯誤: $e');
      return [];
    }
  }

  /// 非極大值抑制 (NMS)
  List<Detection> _applyNMS(List<Detection> detections) {
    if (detections.isEmpty) return [];
    
    // 按信心度排序
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    final selected = <Detection>[];
    final suppressed = <bool>[...List.filled(detections.length, false)];
    
    for (var i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      selected.add(detections[i]);
      
      for (var j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        final iou = _calculateIoU(detections[i], detections[j]);
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    
    return selected;
  }

  /// 計算 IoU (Intersection over Union)
  double _calculateIoU(Detection a, Detection b) {
    final xLeft = a.x1 > b.x1 ? a.x1 : b.x1;
    final yTop = a.y1 > b.y1 ? a.y1 : b.y1;
    final xRight = a.x2 < b.x2 ? a.x2 : b.x2;
    final yBottom = a.y2 < b.y2 ? a.y2 : b.y2;
    
    if (xRight < xLeft || yBottom < yTop) return 0.0;
    
    final intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    final aArea = (a.x2 - a.x1) * (a.y2 - a.y1);
    final bArea = (b.x2 - b.x1) * (b.y2 - b.y1);
    
    return intersectionArea / (aArea + bArea - intersectionArea);
  }

  /// 應用標籤修正規則
  List<Detection> _applyLabelFixes(List<Detection> detections) {
    if (_labelFixes == null || _labelFixes!.isEmpty) {
      return detections;
    }
    
    return detections.map((detection) {
      final className = _classes![detection.classId];
      final fixedClassName = _labelFixes![className];
      
      if (fixedClassName != null) {
        // 找到修正後的類別 ID
        final fixedClassId = _classes!.indexOf(fixedClassName);
        if (fixedClassId != -1) {
          return Detection(
            x1: detection.x1,
            y1: detection.y1,
            x2: detection.x2,
            y2: detection.y2,
            confidence: detection.confidence,
            classId: fixedClassId,
          );
        }
      }
      
      return detection;
    }).toList();
  }

  /// 統計每種食材的數量
  Map<String, int> _countIngredients(List<Detection> detections) {
    final counts = <String, int>{};
    
    for (final detection in detections) {
      final className = _classes![detection.classId];
      final chineseName = _chineseMap![className] ?? className;
      
      counts[chineseName] = (counts[chineseName] ?? 0) + 1;
    }
    
    return counts;
  }

  /// 釋放資源
  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
    print('🔚 FoodDetectionService 已釋放資源');
  }
}

/// 檢測結果類別
class Detection {
  final double x1, y1, x2, y2;
  final double confidence;
  final int classId;

  Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.confidence,
    required this.classId,
  });
}
