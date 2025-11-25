// frontend/lib/services/food_detection_service.dart
// 真實實現版本（用於 Android/iOS/Desktop）

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
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
  static const double confidenceThreshold = 0.25; // 與後端一致，降低閾值以獲得更多結果
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
      
      // 調試：檢查關鍵類別的 ID
      print('🔍 類別映射檢查:');
      for (var i = 0; i < _classes!.length; i++) {
        if (_classes![i] == 'cabbage' || _classes![i] == 'cayliflower' || _classes![i] == 'corn') {
          print('  ID $i: ${_classes![i]}');
        }
      }
      print('  總類別數: ${_classes!.length}');

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
      
      // 4.5. 後處理過濾：根據檢測結果，過濾明顯的誤判
      List<Detection> finalDetections = correctedDetections;
      if (correctedDetections.length > 1) {
        // 統計各類別的檢測數量
        final classCounts = <String, List<Detection>>{};
        for (final d in correctedDetections) {
          final className = _classes![d.classId];
          classCounts.putIfAbsent(className, () => []).add(d);
        }
        
        // 檢查高麗菜檢測
        final cabbageDetections = classCounts['cabbage'] ?? [];
        if (cabbageDetections.isNotEmpty) {
          final maxCabbageConfidence = cabbageDetections.map((d) => d.confidence).reduce((a, b) => a > b ? a : b);
          final otherDetections = correctedDetections.where((d) {
            final className = _classes![d.classId];
            return className != 'cabbage';
          }).toList();
          
          // 如果高麗菜信心度很高（> 0.9），且其他檢測框信心度都較低（< 0.6），則過濾掉其他檢測框
          // 特別過濾西葫蘆、蘿蔔、酪梨等常見誤判
          final suspiciousClasses = ['vegetable marrow', 'rediska', 'redka', 'avocado'];
          final suspiciousDetections = otherDetections.where((d) {
            final className = _classes![d.classId];
            return suspiciousClasses.contains(className);
          }).toList();
          
          if (maxCabbageConfidence > 0.9 && 
              suspiciousDetections.every((d) => d.confidence < 0.6) &&
              suspiciousDetections.length > 0) {
            print('🥬 高麗菜信心度很高 (${maxCabbageConfidence.toStringAsFixed(3)})，過濾可疑的誤判檢測（共 ${suspiciousDetections.length} 個）');
            finalDetections = correctedDetections.where((d) {
              final className = _classes![d.classId];
              return className == 'cabbage' || !suspiciousClasses.contains(className) || d.confidence >= 0.6;
            }).toList();
          }
        }
        
        // 檢查番茄檢測
        final tomatoDetections = classCounts['tomato'] ?? [];
        if (tomatoDetections.isNotEmpty) {
          final maxTomatoConfidence = tomatoDetections.map((d) => d.confidence).reduce((a, b) => a > b ? a : b);
          final otherDetections = correctedDetections.where((d) {
            final className = _classes![d.classId];
            return className != 'tomato';
          }).toList();
          
          // 如果檢測到番茄，且其他檢測框（西葫蘆、蘿蔔、酪梨）同時出現，則可能是誤判
          // 降低番茄信心度要求（從 0.5 降到 0.25），以觸發過濾
          final suspiciousClasses = ['vegetable marrow', 'rediska', 'redka', 'avocado'];
          final suspiciousDetections = otherDetections.where((d) {
            final className = _classes![d.classId];
            return suspiciousClasses.contains(className);
          }).toList();
          
          // 如果番茄信心度 > 0.25，且存在可疑類別，則過濾掉可疑類別
          // 特別處理：如果可疑類別（西葫蘆、蘿蔔）信心度很高（> 0.8），但與番茄同時出現，可能是誤判
          if (maxTomatoConfidence > 0.25 && suspiciousDetections.isNotEmpty) {
            // 檢查是否有高信心度的可疑類別（可能是誤判）
            final highConfidenceSuspicious = suspiciousDetections.where((d) => d.confidence > 0.8).toList();
            
            if (highConfidenceSuspicious.isNotEmpty) {
              // 如果可疑類別信心度很高，但番茄也存在，則過濾掉可疑類別
              // 這基於假設：如果圖片中只有番茄，不應該同時出現高信心度的西葫蘆或蘿蔔
              print('🍅 檢測到番茄 (信心度: ${maxTomatoConfidence.toStringAsFixed(3)})，但同時存在高信心度的可疑類別（共 ${highConfidenceSuspicious.length} 個），過濾可疑類別');
              finalDetections = correctedDetections.where((d) {
                final className = _classes![d.classId];
                return className == 'tomato' || !suspiciousClasses.contains(className);
              }).toList();
            } else if (suspiciousDetections.every((d) => d.confidence < 0.65)) {
              // 如果可疑類別信心度都較低（< 0.65），則過濾掉
              print('🍅 番茄信心度較高 (${maxTomatoConfidence.toStringAsFixed(3)})，過濾低信心度的可疑檢測（共 ${suspiciousDetections.length} 個）');
              finalDetections = correctedDetections.where((d) {
                final className = _classes![d.classId];
                return className == 'tomato' || !suspiciousClasses.contains(className) || d.confidence >= 0.65;
              }).toList();
            }
          }
        }
        
        // 檢查馬鈴薯檢測（用於過濾誤判）
        final potatoDetections = classCounts['potato'] ?? [];
        if (potatoDetections.isNotEmpty) {
          final maxPotatoConfidence = potatoDetections.map((d) => d.confidence).reduce((a, b) => a > b ? a : b);
          final otherDetections = correctedDetections.where((d) {
            final className = _classes![d.classId];
            return className != 'potato';
          }).toList();
          
          // 如果馬鈴薯信心度較高（> 0.4），且其他檢測框（玉米、番茄）信心度都較低（< 0.7），則過濾掉其他檢測框
          final suspiciousClasses = ['corn', 'tomato'];
          final suspiciousDetections = otherDetections.where((d) {
            final className = _classes![d.classId];
            return suspiciousClasses.contains(className);
          }).toList();
          
          if (maxPotatoConfidence > 0.4 && 
              suspiciousDetections.isNotEmpty &&
              suspiciousDetections.every((d) => d.confidence < 0.7)) {
            print('🥔 馬鈴薯信心度較高 (${maxPotatoConfidence.toStringAsFixed(3)})，過濾可疑的誤判檢測（共 ${suspiciousDetections.length} 個）');
            finalDetections = correctedDetections.where((d) {
              final className = _classes![d.classId];
              return className == 'potato' || !suspiciousClasses.contains(className) || d.confidence >= 0.7;
            }).toList();
          }
        }
        
        // 檢查玉米+番茄組合（可能是馬鈴薯的誤判）
        final cornDetections = classCounts['corn'] ?? [];
        final tomatoDetections2 = classCounts['tomato'] ?? [];
        if (cornDetections.isNotEmpty && tomatoDetections2.isNotEmpty) {
          final maxCornConfidence = cornDetections.map((d) => d.confidence).reduce((a, b) => a > b ? a : b);
          final maxTomatoConfidence2 = tomatoDetections2.map((d) => d.confidence).reduce((a, b) => a > b ? a : b);
          
          // 檢查是否有馬鈴薯檢測
          final potatoDetections2 = classCounts['potato'] ?? [];
          final hasPotato = potatoDetections2.isNotEmpty;
          
          // 如果玉米和番茄同時出現，且沒有檢測到馬鈴薯，則可能是誤判
          // 這種情況下，可能是馬鈴薯被誤判為玉米和番茄
          if (!hasPotato) {
            // 如果玉米和番茄的信心度都不是特別高（< 0.95），且沒有其他明顯的類別，則過濾掉這些檢測
            // 檢查是否有其他明顯的類別（信心度 > 0.7）
            final otherHighConfidenceClasses = correctedDetections.where((d) {
              final className = _classes![d.classId];
              return className != 'corn' && className != 'tomato' && d.confidence > 0.7;
            }).toList();
            
            // 如果沒有其他高信心度的類別，且玉米和番茄的信心度都不是特別高（< 0.95），則過濾掉這些檢測
            if (otherHighConfidenceClasses.isEmpty && 
                maxCornConfidence < 0.95 && 
                maxTomatoConfidence2 < 0.95) {
              print('⚠️ 檢測到玉米+番茄組合（玉米信心度: ${maxCornConfidence.toStringAsFixed(3)}, 番茄信心度: ${maxTomatoConfidence2.toStringAsFixed(3)}），且沒有檢測到馬鈴薯，可能是誤判，過濾這些檢測');
              // 過濾掉玉米和番茄的檢測
              finalDetections = correctedDetections.where((d) {
                final className = _classes![d.classId];
                return className != 'corn' && className != 'tomato';
              }).toList();
            } else {
              print('⚠️ 檢測到玉米+番茄組合（玉米信心度: ${maxCornConfidence.toStringAsFixed(3)}, 番茄信心度: ${maxTomatoConfidence2.toStringAsFixed(3)}），可能是誤判（實際可能是馬鈴薯）');
            }
          }
        }
      }
      
      // 5. 統計每種食材的數量
      final result = _countIngredients(finalDetections);
      
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
      final outputTensor = outputs as OrtValueTensor;
      
      // 獲取輸出數據（可能是多維陣列）
      dynamic outputData = outputTensor.value;
      
      print('📊 輸出數據類型: ${outputData.runtimeType}');
      
      // 添加詳細的調試信息
      if (outputData is List) {
        print('📊 輸出數據長度: ${outputData.length}');
        if (outputData.isNotEmpty) {
          print('📊 第一個元素類型: ${outputData[0].runtimeType}');
          if (outputData[0] is List) {
            print('📊 第一個元素長度: ${(outputData[0] as List).length}');
            if ((outputData[0] as List).isNotEmpty) {
              print('📊 第一個檢測框前10個值: ${(outputData[0] as List).take(10).toList()}');
            }
          } else {
            print('📊 第一個檢測框前10個值: ${outputData.take(10).toList()}');
          }
        }
      }
      
      // 處理不同的輸出格式
      // 格式1: [batch, num_detections, features] -> 移除批次維度
      // 格式2: [num_detections, features] -> 直接使用
      // 格式3: 一維陣列需要重新整形
      
      List<List<dynamic>> detectionsList = [];
      
      // 推斷數據結構
      if (outputData is List) {
        if (outputData.isEmpty) {
          return [];
        }
        
        // 檢查是否為多維陣列
        if (outputData[0] is List) {
          // 二維或三維陣列
          if (outputData[0][0] is List) {
            // 三維陣列 [batch, num_detections, features]
            outputData = outputData[0]; // 移除批次維度
          }
          
          // 二維陣列 [num_detections, features]
          detectionsList = List<List<dynamic>>.from(
            outputData.map((item) => List<dynamic>.from(item))
          );
        } else {
          // 一維陣列，需要重新整形
          // 假設格式為 [x, y, w, h, confidence, class_scores...]
          final features = 4 + _classes!.length; // 4個bbox + 類別數量
          final numDetections = outputData.length ~/ features;
          
          detectionsList = [];
          for (var i = 0; i < numDetections; i++) {
            final start = i * features;
            final end = start + features;
            if (end <= outputData.length) {
              detectionsList.add(List<dynamic>.from(outputData.sublist(start, end)));
            }
          }
        }
      } else {
        // 嘗試展平
        detectionsList = _flattenOutput(outputData);
      }
      
      print('📊 解析出 ${detectionsList.length} 個檢測框');
      
      // 先收集所有檢測框的資訊，找出高麗菜分數最高的檢測框
      final allDetectionsInfo = <Map<String, dynamic>>[];
      
      // 解析每個檢測結果
      for (final detection in detectionsList) {
        if (detection.length < 5) continue;
        
        // YOLO 格式可能是 [x, y, w, h, confidence, class_scores...] 或 [x1, y1, x2, y2, confidence, class_id]
        // 嘗試兩種格式
        double x1, y1, x2, y2;
        double confidence;
        int classId;
        
        if (detection.length == 6 && detection[5] is int) {
          // 格式: [x1, y1, x2, y2, confidence, class_id]
          x1 = (detection[0] as num).toDouble();
          y1 = (detection[1] as num).toDouble();
          x2 = (detection[2] as num).toDouble();
          y2 = (detection[3] as num).toDouble();
          confidence = (detection[4] as num).toDouble();
          classId = detection[5] as int;
        } else {
          // YOLO 格式可能是：
          // 1. [x_center, y_center, width, height, class_scores...] (比例值 0-1)
          // 2. [x1, y1, x2, y2, class_scores...] (像素值或比例值)
          final val0 = (detection[0] as num).toDouble();
          final val1 = (detection[1] as num).toDouble();
          final val2 = (detection[2] as num).toDouble();
          final val3 = (detection[3] as num).toDouble();
          
          // 判斷是中心點格式還是角點格式
          // 如果值都小於 1，可能是比例值；如果值較大，可能是像素值
          if (val0 < 1.0 && val1 < 1.0 && val2 < 1.0 && val3 < 1.0) {
            // 比例值格式：[x_center, y_center, width, height]
            final x = val0;
            final y = val1;
            final w = val2;
            final h = val3;
            
            // 轉換為 x1, y1, x2, y2（比例值）
            x1 = x - w / 2;
            y1 = y - h / 2;
            x2 = x + w / 2;
            y2 = y + h / 2;
          } else {
            // 可能是像素值格式：[x1, y1, x2, y2] 或 [x_center, y_center, width, height]
            // 從日誌看，值可能是像素座標，需要轉換為比例
            // 假設圖片尺寸是 640x640
            final imgSize = inputWidth.toDouble();
            
            // 嘗試兩種格式
            if (val2 > val0 && val3 > val1) {
              // 可能是 [x1, y1, x2, y2] 格式（像素值）
              x1 = val0 / imgSize;
              y1 = val1 / imgSize;
              x2 = val2 / imgSize;
              y2 = val3 / imgSize;
            } else {
              // 可能是 [x_center, y_center, width, height] 格式（像素值）
              final x = val0 / imgSize;
              final y = val1 / imgSize;
              final w = val2 / imgSize;
              final h = val3 / imgSize;
              
              x1 = x - w / 2;
              y1 = y - h / 2;
              x2 = x + w / 2;
              y2 = y + h / 2;
            }
          }
          
          // YOLO 輸出格式：前4個是 bbox，後面是類別分數
          // 從日誌看，模型輸出的是原始分數（可能是 logits），需要正規化
          double maxScore = double.negativeInfinity;
          classId = 0;
          Map<int, double> allScores = {};
          
          if (detection.length >= 4 + _classes!.length) {
            // 標準 YOLO 格式：有完整的類別分數
            // 從索引 4 開始是類別分數
            // 先找到最高分數的類別，同時記錄所有類別的分數
            allScores = <int, double>{};
            for (var j = 4; j < 4 + _classes!.length && j < detection.length; j++) {
              final score = (detection[j] as num).toDouble();
              final cid = j - 4;
              allScores[cid] = score;
              if (score > maxScore) {
                maxScore = score;
                classId = cid; // 類別 ID = 索引 - 4
              }
            }
            
            // 調試：顯示前5個最高分數的類別
            final sortedScores = allScores.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            print('🔍 前5個最高分數的類別:');
            for (var i = 0; i < sortedScores.length && i < 5; i++) {
              final entry = sortedScores[i];
              if (entry.key >= 0 && entry.key < _classes!.length) {
                final className = _classes![entry.key];
                print('  ${i + 1}. $className (ID: ${entry.key}): ${entry.value.toStringAsFixed(2)}');
              } else {
                print('  ${i + 1}. [無效ID: ${entry.key}]: ${entry.value.toStringAsFixed(2)}');
              }
            }
            
            // 特別檢查 ID 11 的分數（模型訓練時可能將高麗菜標記為這個 ID）
            if (allScores.containsKey(11)) {
              final score11 = allScores[11]!;
              if (11 < _classes!.length) {
                final actualClassName = _classes![11];
                print('🥬 檢查 ID 11: 類別名稱是 "$actualClassName"，分數: ${score11.toStringAsFixed(2)}');
                // 注意：模型訓練時 ID 11 可能對應高麗菜，即使 classes.json 中不是
                if (actualClassName != 'cabbage' && score11 > 200) {
                  print('💡 提示：模型 ID 11 分數很高，可能是高麗菜（將在後處理中映射）');
                }
              }
            }
            
            // 信心度計算：簡化為更接近後端的邏輯
            // 後端直接使用 detection[4] 作為 confidence，但前端需要從類別分數中計算
            // 使用簡單的線性縮放：將原始分數映射到 0-1 範圍
            // 觀察：模型輸出的分數範圍大致在 0-300 之間
            // 高分數（> 200）通常對應高信心度，低分數（< 50）通常對應低信心度
            if (maxScore > 200) {
              // 高分數：使用 sigmoid 函數，映射到 0.7-1.0 範圍
              final threshold = 200.0;
              final scale = 50.0;
              confidence = 0.7 + 0.3 * (1.0 / (1.0 + math.exp(-(maxScore - threshold) / scale)));
              confidence = confidence.clamp(0.7, 1.0);
            } else if (maxScore >= 50) {
              // 中分數：線性縮放，映射到 0.3-0.7 範圍
              confidence = 0.3 + (maxScore - 50) / 150.0 * 0.4;
              confidence = confidence.clamp(0.3, 0.7);
            } else {
              // 低分數：線性縮放，映射到 0.1-0.3 範圍
              // 這樣可以讓分數在 20-50 範圍的檢測也能通過閾值（0.25），但不會太高
              confidence = 0.1 + (maxScore / 50.0) * 0.2;
              confidence = confidence.clamp(0.1, 0.3);
            }
            
            print('🔍 原始最高分數: $maxScore, 信心度: ${confidence.toStringAsFixed(3)}');
          } else if (detection.length == 6) {
            // 可能是 [x, y, w, h, confidence, class_id] 格式
            confidence = (detection[4] as num).toDouble();
            classId = (detection[5] as num).toInt();
            maxScore = confidence; // 使用信心度作為分數
            allScores = {classId: confidence}; // 只記錄一個類別
          } else {
            // 格式不符合預期，跳過
            print('⚠️ 檢測框格式不符合預期，長度: ${detection.length}');
            continue;
          }
          
          // 驗證類別 ID 是否有效
          if (classId < 0 || classId >= _classes!.length) {
            print('⚠️ 無效的類別 ID: $classId (範圍: 0-${_classes!.length - 1})');
            continue;
          }
          
          // 收集所有檢測框資訊（包括低信心度的）
          allDetectionsInfo.add({
            'detection': detection,
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
            'confidence': confidence,
            'classId': classId,
            'maxScore': maxScore,
            'allScores': allScores,
          });
        }
      }
      
      // 處理 ID 11 -> cabbage 的映射（模型訓練時 ID 11 對應高麗菜）
      final actualCabbageId = _classes!.indexOf('cabbage');
      if (actualCabbageId == -1) {
        print('⚠️ 警告：找不到 cabbage 類別');
      }
      
      // 檢查所有檢測框，如果 ID 11 分數很高且是最高分或非常接近最高分，則映射為高麗菜
      for (var i = 0; i < allDetectionsInfo.length; i++) {
        final info = allDetectionsInfo[i];
        final allScores = info['allScores'] as Map<int, double>;
        final score11 = allScores[11] ?? 0.0;
        
        // 更嚴格的條件：ID 11 分數必須非常高（> 220），且必須是最高分或差距非常小（< 1）
        // 同時，如果最高分是西葫蘆（vegetable marrow, ID 25）且分數很高，則不映射為高麗菜
        if (score11 > 220 && actualCabbageId != -1) {
          // 找到最高分和對應的類別 ID
          int maxClassId = 0;
          double maxScore = double.negativeInfinity;
          for (var entry in allScores.entries) {
            if (entry.value > maxScore) {
              maxScore = entry.value;
              maxClassId = entry.key;
            }
          }
          
          final scoreDiff = maxScore - score11;
          final maxClassName = maxClassId < _classes!.length ? _classes![maxClassId] : 'unknown';
          
          // 如果最高分是西葫蘆（vegetable marrow, ID 25）且分數很高（> 230），則不映射為高麗菜
          // 這可以避免高麗菜被誤判為西葫蘆，或西葫蘆被誤判為高麗菜
          if (maxClassId == 25 && maxScore > 230 && scoreDiff > 5) {
            print('⚠️ 不映射 ID 11 -> cabbage: 最高分是西葫蘆 (ID: 25, 分數: ${maxScore.toStringAsFixed(2)})，且差距較大 (${scoreDiff.toStringAsFixed(2)})');
          } else if (maxClassId == 11 || (scoreDiff < 1 && score11 > 220)) {
            // 只有當 ID 11 是最高分，或者差距非常小（< 1）時才映射
            // 重新計算信心度（基於 ID 11 的分數）
            final threshold = 200.0;
            final scale = 50.0;
            final cabbageConfidence = 0.7 + 0.3 * (1.0 / (1.0 + math.exp(-(score11 - threshold) / scale)));
            allDetectionsInfo[i]['confidence'] = cabbageConfidence.clamp(0.7, 1.0);
            allDetectionsInfo[i]['classId'] = actualCabbageId;
            
            print('🥬 映射 ID 11 -> cabbage: ID 11 分數=${score11.toStringAsFixed(2)}, 最高分=${maxScore.toStringAsFixed(2)} (類別: $maxClassName, ID: $maxClassId), 差距=${scoreDiff.toStringAsFixed(2)}, 信心度=${cabbageConfidence.toStringAsFixed(3)}');
          } else {
            print('⚠️ 不映射 ID 11 -> cabbage: ID 11 分數=${score11.toStringAsFixed(2)}, 最高分=${maxScore.toStringAsFixed(2)} (類別: $maxClassName, ID: $maxClassId), 差距=${scoreDiff.toStringAsFixed(2)} 太大或最高分不是 ID 11');
          }
        }
      }
      
      // 統計高麗菜、番茄和馬鈴薯檢測框的數量（在循環外部統計，避免重複計算）
      int cabbageCount = 0;
      double maxCabbageConfidence = 0.0;
      int tomatoCount = 0;
      double maxTomatoConfidence = 0.0;
      int potatoCount = 0;
      double maxPotatoConfidence = 0.0;
      for (final info in allDetectionsInfo) {
        final classId = info['classId'] as int;
        final confidence = info['confidence'] as double;
        if (classId >= 0 && classId < _classes!.length) {
          final className = _classes![classId];
          if (className == 'cabbage') {
            cabbageCount++;
            if (confidence > maxCabbageConfidence) {
              maxCabbageConfidence = confidence;
            }
          } else if (className == 'tomato') {
            tomatoCount++;
            if (confidence > maxTomatoConfidence) {
              maxTomatoConfidence = confidence;
            }
          } else if (className == 'potato') {
            potatoCount++;
            if (confidence > maxPotatoConfidence) {
              maxPotatoConfidence = confidence;
            }
          }
        }
      }
      
      print('📊 統計結果：高麗菜 ${cabbageCount} 個（最高信心度: ${maxCabbageConfidence.toStringAsFixed(3)}），番茄 ${tomatoCount} 個（最高信心度: ${maxTomatoConfidence.toStringAsFixed(3)}），馬鈴薯 ${potatoCount} 個（最高信心度: ${maxPotatoConfidence.toStringAsFixed(3)}）');
      
      // 過濾並添加檢測框
      for (final info in allDetectionsInfo) {
        final confidence = info['confidence'] as double;
        var classId = info['classId'] as int;
        
        // 過濾低信心度的檢測
        if (confidence >= confidenceThreshold && classId >= 0 && classId < _classes!.length) {
          final className = _classes![classId];
          
          // 改進的過濾邏輯：根據檢測到的類別，更嚴格地過濾其他類別
          // 1. 如果檢測到高麗菜，且西葫蘆的信心度不是特別高（< 0.9），則過濾掉西葫蘆
          // 2. 如果檢測到高麗菜，且其他類別（如酪梨、番茄、蘿蔔）的信心度較低（< 0.7），則過濾掉
          if (cabbageCount > 0) {
            // 當檢測到高麗菜時，更嚴格地過濾西葫蘆
            if (className == 'vegetable marrow' && confidence < 0.9) {
              print('⚠️ 過濾西葫蘆檢測（檢測到高麗菜，且西葫蘆信心度 ${confidence.toStringAsFixed(3)} < 0.9）');
              continue;
            }
            // 如果高麗菜信心度很高（> 0.85），且其他類別信心度較低（< 0.7），則過濾掉其他類別
            if (maxCabbageConfidence > 0.85 && className != 'cabbage' && confidence < 0.7) {
              print('⚠️ 過濾 ${className} 檢測（高麗菜信心度很高 ${maxCabbageConfidence.toStringAsFixed(3)}，且 ${className} 信心度 ${confidence.toStringAsFixed(3)} < 0.7）');
              continue;
            }
          }
          
          // 當檢測到番茄時，更嚴格地過濾其他誤判的類別（如西葫蘆、蘿蔔、酪梨）
          if (tomatoCount > 0 && maxTomatoConfidence > 0.4) {
            // 如果檢測到番茄，且其他類別（西葫蘆、蘿蔔、酪梨）的信心度較低（< 0.75），則過濾掉
            // 提高閾值到 0.75，更嚴格地過濾誤判
            if ((className == 'vegetable marrow' || className == 'rediska' || className == 'redka' || className == 'avocado') && 
                className != 'tomato' && confidence < 0.75) {
              print('⚠️ 過濾 ${className} 檢測（檢測到番茄，且 ${className} 信心度 ${confidence.toStringAsFixed(3)} < 0.75）');
              continue;
            }
            // 如果番茄信心度較高（> 0.5），且其他可疑類別信心度都較低（< 0.6），則過濾掉所有可疑類別
            if (maxTomatoConfidence > 0.5 && 
                (className == 'vegetable marrow' || className == 'rediska' || className == 'redka' || className == 'avocado') &&
                className != 'tomato' && confidence < 0.6) {
              print('⚠️ 過濾 ${className} 檢測（番茄信心度 ${maxTomatoConfidence.toStringAsFixed(3)}，且 ${className} 信心度 ${confidence.toStringAsFixed(3)} < 0.6）');
              continue;
            }
          }
          
          // 特別標記高麗菜和西葫蘆，用於調試
          if (classId == 11 || className == 'cabbage') {
            print('🥬 檢測到高麗菜: $className (ID: $classId, 信心度: ${confidence.toStringAsFixed(3)})');
          } else if (className == 'vegetable marrow') {
            print('⚠️ 檢測到西葫蘆: $className (ID: $classId, 信心度: ${confidence.toStringAsFixed(3)}) - 請檢查是否為誤判');
          } else {
            print('✅ 檢測到: $className (ID: $classId, 信心度: ${confidence.toStringAsFixed(3)})');
          }
          
          detections.add(Detection(
            x1: info['x1'] as double,
            y1: info['y1'] as double,
            x2: info['x2'] as double,
            y2: info['y2'] as double,
            confidence: confidence,
            classId: classId,
          ));
        } else {
          if (classId < 0 || classId >= _classes!.length) {
            print('⚠️ 無效的類別 ID: $classId (總類別數: ${_classes!.length})');
          }
          if (confidence < confidenceThreshold) {
            print('⚠️ 信心度過低: ${confidence.toStringAsFixed(3)} < $confidenceThreshold');
          }
        }
      }
      
      print('📊 過濾後有 ${detections.length} 個檢測框');
      
      // 應用 NMS (非極大值抑制)
      final nmsDetections = _applyNMS(detections);
      print('📊 NMS 後保留 ${nmsDetections.length} 個檢測框');
      
      return nmsDetections;
    } catch (e, stackTrace) {
      print('❌ 後處理錯誤: $e');
      print('堆疊追蹤: $stackTrace');
      return [];
    }
  }
  
  /// 展平輸出數據
  List<List<dynamic>> _flattenOutput(dynamic data) {
    // 嘗試將多維陣列展平為二維陣列
    try {
      if (data is List) {
        if (data.isNotEmpty && data[0] is List) {
          return List<List<dynamic>>.from(
            data.map((item) => List<dynamic>.from(item))
          );
        } else {
          // 一維陣列，嘗試重新整形
          final numFeatures = 4 + _classes!.length;
          final numDetections = data.length ~/ numFeatures;
          final result = <List<dynamic>>[];
          for (var i = 0; i < numDetections; i++) {
            final start = i * numFeatures;
            final end = (i + 1) * numFeatures;
            if (end <= data.length) {
              result.add(List<dynamic>.from(data.sublist(start, end)));
            }
          }
          return result;
        }
      }
    } catch (e) {
      print('展平輸出時發生錯誤: $e');
    }
    return [];
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
      
      // 對於高麗菜，使用更寬鬆的 NMS 閾值，以保留多個高麗菜檢測框
      final isCabbage = _classes![detections[i].classId] == 'cabbage';
      final currentIouThreshold = isCabbage ? 0.7 : iouThreshold; // 高麗菜使用 0.7，其他使用 0.4
      
      for (var j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        // 如果是相同類別，使用較高的 IoU 閾值
        final sameClass = detections[i].classId == detections[j].classId;
        final threshold = sameClass ? currentIouThreshold : (currentIouThreshold * 0.8);
        
        final iou = _calculateIoU(detections[i], detections[j]);
        if (iou > threshold) {
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
      print('📝 標籤修正表為空，跳過修正');
      return detections;
    }
    
    // 檢查是否有番茄檢測（用於避免錯誤修正）
    final hasTomato = detections.any((d) {
      final className = _classes![d.classId];
      return className == 'tomato';
    });
    
    return detections.map((detection) {
      final className = _classes![detection.classId];
      final fixedClassName = _labelFixes![className];
      
      // 特殊處理：如果檢測到番茄，且信心度超過閾值（> 0.2），則不應用 tomato -> avocado 的修正
      // 這可以避免番茄被錯誤地修正為酪梨
      // 降低閾值以確保更多番茄檢測不被錯誤修正
      if (className == 'tomato' && hasTomato && detection.confidence > 0.2) {
        print('🍅 保留番茄檢測（信心度 ${detection.confidence.toStringAsFixed(3)} > 0.2），不應用 tomato -> avocado 的修正');
        return detection;
      }
      
      // 特殊處理：如果檢測到馬鈴薯，且信心度較高（> 0.3），則不應用 potato -> bell pepper 的修正
      // 這可以避免馬鈴薯被錯誤地修正為青椒
      if (className == 'potato' && detection.confidence > 0.3) {
        print('🥔 保留馬鈴薯檢測（信心度 ${detection.confidence.toStringAsFixed(3)} > 0.3），不應用 potato -> bell pepper 的修正');
        return detection;
      }
      
      if (fixedClassName != null) {
        print('🔧 修正標籤: $className -> $fixedClassName');
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
        } else {
          print('⚠️ 找不到修正後的類別: $fixedClassName');
        }
      }
      
      return detection;
    }).toList();
  }

  /// 統計每種食材的數量
  Map<String, int> _countIngredients(List<Detection> detections) {
    final counts = <String, int>{};
    
    print('📊 開始統計食材數量，共 ${detections.length} 個檢測框');
    
    for (final detection in detections) {
      final className = _classes![detection.classId];
      final chineseName = _chineseMap![className] ?? className;
      
      print('  - 類別: $className (ID: ${detection.classId}) -> 中文: $chineseName (信心度: ${detection.confidence.toStringAsFixed(3)})');
      
      counts[chineseName] = (counts[chineseName] ?? 0) + 1;
    }
    
    print('📊 統計結果: $counts');
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
