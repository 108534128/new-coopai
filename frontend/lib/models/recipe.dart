class Recipe {
  final String uid;
  final String externalId;
  final String name;
  final String ingredients;  // 存儲原始字串
  final String tag;
  final String porsi;
  final int? cookMinutes;  // 可為 null
  final String instructions;  // 存儲原始字串
  final String image;
  final int likes;
  final String createdAt;
  final String updatedAt;

  Recipe({
    required this.uid,
    required this.externalId,
    required this.name,
    required this.ingredients,
    required this.tag,
    required this.porsi,
    this.cookMinutes,
    required this.instructions,
    required this.image,
    this.likes = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // 將逗號分隔的字串轉換為列表
  List<String> get ingredientsList => 
      ingredients.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> get instructionsList =>
      instructions.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      uid: json['uid'] ?? '',
      externalId: json['external_id'] ?? '',
      name: json['name'] ?? '',
      ingredients: json['ingredients'] ?? '',
      tag: json['tag'] ?? '',
      porsi: json['porsi'] ?? '',
      cookMinutes: json['cook_minutes'],  // 允許 null
      instructions: json['instructions'] ?? '',
      image: json['image'] ?? '',
      likes: json['likes'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'external_id': externalId,
      'name': name,
      'ingredients': ingredients,
      'tag': tag,
      'porsi': porsi,
      'cook_minutes': cookMinutes,
      'instructions': instructions,
      'image': image,
      'likes': likes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}