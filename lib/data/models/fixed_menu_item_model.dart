import 'package:hive/hive.dart';

part 'fixed_menu_item_model.g.dart';

@HiveType(typeId: 2)
class FixedMenuItemModel extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1, defaultValue: 0.0)
  double price;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  FixedMenuItemModel({
    required String name,
    required double price,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : name = name.trim(),
       price = _safePositive(price),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now() {
    normalize();
  }

  String get displayName {
    final value = name.trim();
    return value.isEmpty ? 'صنف بدون اسم' : value;
  }

  void normalize() {
    name = name.trim();
    price = _safePositive(price);
  }

  void updateData({required String name, required double price}) {
    this.name = name.trim();
    this.price = _safePositive(price);
    updatedAt = DateTime.now();
    normalize();
  }

  static double _safePositive(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0.0;
    return value;
  }
}
