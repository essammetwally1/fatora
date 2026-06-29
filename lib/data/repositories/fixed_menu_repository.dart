import 'package:hive/hive.dart';

import '../models/fixed_menu_item_model.dart';
import '../services/storage/hive_service.dart';

class FixedMenuRepository {
  Box<FixedMenuItemModel> get _box => HiveService.getFixedMenuBox();

  List<FixedMenuItemModel> getItems() {
    final items = _box.values.toList(growable: false);

    for (final item in items) {
      item.normalize();
    }

    items.sort(_compareItems);
    return items;
  }

  Future<FixedMenuItemModel> createItem({
    required String name,
    required double price,
  }) async {
    final item = FixedMenuItemModel(name: name, price: price);

    await _box.add(item);
    return item;
  }

  Future<FixedMenuItemModel?> updateItem({
    required dynamic itemKey,
    required String name,
    required double price,
  }) async {
    if (itemKey == null) return null;

    final item = _box.get(itemKey);
    if (item == null) return null;

    item.updateData(name: name, price: price);

    await item.save();
    return item;
  }

  Future<bool> deleteItem({
    required FixedMenuItemModel item,
    dynamic itemKey,
  }) async {
    final key = itemKey ?? item.key;

    if (key != null && _box.containsKey(key)) {
      await _box.delete(key);
      return !_box.containsKey(key);
    }

    if (item.isInBox) {
      final attachedKey = item.key;
      await item.delete();

      if (attachedKey == null) return !item.isInBox;
      return !_box.containsKey(attachedKey);
    }

    return false;
  }

  Future<void> compactMenuBox() {
    return _box.compact();
  }

  static int _compareItems(FixedMenuItemModel a, FixedMenuItemModel b) {
    final nameCompare = a.displayName.compareTo(b.displayName);
    if (nameCompare != 0) return nameCompare;

    final aKey = a.key;
    final bKey = b.key;

    if (aKey is int && bKey is int) {
      return bKey.compareTo(aKey);
    }

    return b.updatedAt.compareTo(a.updatedAt);
  }
}
