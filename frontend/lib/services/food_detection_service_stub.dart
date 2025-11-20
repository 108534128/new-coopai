// frontend/lib/services/food_detection_service_stub.dart
// Web 平台的空實現

class FoodDetectionService {
  Future<void> initialize() async {
    throw UnsupportedError('食材辨識功能在 Web 平台上不支援');
  }

  Future<Map<String, int>> detectFood(String imagePath) async {
    throw UnsupportedError('食材辨識功能在 Web 平台上不支援');
  }

  void dispose() {
    // 空實現
  }
}
