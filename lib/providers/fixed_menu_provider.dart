import 'package:flutter/material.dart';

import '../data/models/fixed_menu_item_model.dart';
import '../data/repositories/fixed_menu_repository.dart';

class FixedMenuProvider extends ChangeNotifier {
  final FixedMenuRepository _repository = FixedMenuRepository();

  List<FixedMenuItemModel> _items = const [];
  final Map<dynamic, FixedMenuItemModel> _itemByKey =
      <dynamic, FixedMenuItemModel>{};

  int _version = 0;

  bool _isLoading = false;
  bool _isMutating = false;

  List<FixedMenuItemModel> get items => _items;

  int get version => _version;

  bool get isLoading => _isLoading;

  bool get isMutating => _isMutating;

  FixedMenuItemModel? itemByKey(dynamic key) {
    if (key == null) return null;
    return _itemByKey[key];
  }

  void loadMenu({bool notify = true}) {
    if (_isLoading) return;

    _isLoading = true;
    if (notify) notifyListeners();

    final items = _repository.getItems();

    _items = List<FixedMenuItemModel>.unmodifiable(items);

    _itemByKey
      ..clear()
      ..addEntries(
        _items
            .where((item) => item.key != null)
            .map((item) => MapEntry(item.key, item)),
      );

    _bumpVersion();

    _isLoading = false;
    if (notify) notifyListeners();
  }

  Future<bool> createItem({required String name, required double price}) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty || price <= 0 || _isMutating) return false;

    _isMutating = true;
    notifyListeners();

    try {
      final createdItem = await _repository.createItem(
        name: cleanName,
        price: price,
      );

      final nextItems = List<FixedMenuItemModel>.of(_items, growable: true)
        ..add(createdItem)
        ..sort(_compareItems);

      _items = List<FixedMenuItemModel>.unmodifiable(nextItems);

      final createdKey = createdItem.key;
      if (createdKey != null) {
        _itemByKey[createdKey] = createdItem;
      }

      _bumpVersion();
      return true;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> updateItem({
    required FixedMenuItemModel item,
    required String name,
    required double price,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty || price <= 0 || _isMutating) return false;

    final itemKey = item.key;
    if (itemKey == null) return false;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedItem = await _repository.updateItem(
        itemKey: itemKey,
        name: cleanName,
        price: price,
      );

      if (updatedItem == null) return false;

      return _replaceItemInMemory(updatedItem);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteItem(FixedMenuItemModel item) async {
    if (_isMutating) return false;

    final itemKey = item.key;

    _isMutating = true;
    notifyListeners();

    try {
      final deleted = await _repository.deleteItem(
        item: item,
        itemKey: itemKey,
      );

      if (!deleted) return false;

      if (itemKey != null) {
        _removeItemFromMemory(itemKey);
      } else {
        loadMenu(notify: false);
      }

      return true;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> compactStorage() {
    return _repository.compactMenuBox();
  }

  bool _replaceItemInMemory(FixedMenuItemModel updatedItem) {
    final updatedKey = updatedItem.key;

    if (updatedKey == null) return false;

    final index = _items.indexWhere((item) => item.key == updatedKey);
    if (index == -1) return false;

    final nextItems = List<FixedMenuItemModel>.of(_items, growable: true);
    nextItems[index] = updatedItem;
    nextItems.sort(_compareItems);

    _items = List<FixedMenuItemModel>.unmodifiable(nextItems);
    _itemByKey[updatedKey] = updatedItem;

    _bumpVersion();
    return true;
  }

  void _removeItemFromMemory(dynamic itemKey) {
    final beforeLength = _items.length;

    _items = List<FixedMenuItemModel>.unmodifiable(
      _items.where((item) => item.key != itemKey),
    );

    _itemByKey.remove(itemKey);

    if (_items.length != beforeLength) {
      _bumpVersion();
    } else {
      loadMenu(notify: false);
    }
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

  void _bumpVersion() {
    _version++;
  }
}
