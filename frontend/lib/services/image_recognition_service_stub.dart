// Web 平台的存根檔案
// 這個檔案在 Web 平台上會被使用，提供空的類型定義以避免編譯錯誤

import 'dart:typed_data';

class OnnxRuntime {
  OnnxRuntime();
  Future<OrtSession> createSessionFromAsset(String assetPath) {
    throw UnsupportedError('ONNX Runtime 在 Web 平台上不支援');
  }
}

class OrtSession {
  List<String> get inputNames => [];
  Future<Map<String, OrtValue>> run(Map<String, OrtValue> inputs) {
    throw UnsupportedError('ONNX Runtime 在 Web 平台上不支援');
  }
  Future<void> close() async {}
}

class OrtValue {
  Future<List<double>> asFlattenedList() {
    throw UnsupportedError('ONNX Runtime 在 Web 平台上不支援');
  }
  Future<void> dispose() async {}
}

class OrtValueTensor {
  static Future<OrtValue> createTensorWithDataAsList(
    Float32List data,
    List<int> shape,
  ) {
    throw UnsupportedError('ONNX Runtime 在 Web 平台上不支援');
  }
}

