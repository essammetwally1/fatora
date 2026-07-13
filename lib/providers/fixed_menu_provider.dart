import 'package:flutter/material.dart';

import '../data/models/fixed_menu_item_model.dart';
import '../data/repositories/fixed_menu_repository.dart';

class FixedMenuProvider extends ChangeNotifier {
  FixedMenuProvider({FixedMenuRepository? repository})
    : _repository = repository ?? FixedMenuRepository();

  final FixedMenuRepository _repository;

  List<FixedMenuItemModel> _items = const [];
  final Map<dynamic, FixedMenuItemModel> _itemByKey =
      <dynamic, FixedMenuItemModel>{};

  int _version = 0;

  bool _isLoading = false;
  bool _isMutating = false;

  Object? _lastError;
  StackTrace? _lastStackTrace;
  String? _lastErrorMessage;

  List<FixedMenuItemModel> get items => _items;

  int get version => _version;

  bool get isLoading => _isLoading;

  bool get isMutating => _isMutating;

  Object? get lastError => _lastError;

  StackTrace? get lastStackTrace => _lastStackTrace;

  String? get lastErrorMessage => _lastErrorMessage;

  FixedMenuItemModel? itemByKey(dynamic key) {
    if (key == null) return null;
    return _itemByKey[key];
  }

  bool loadMenu({bool notify = true}) {
    if (_isLoading) return false;

    _isLoading = true;
    clearError(notify: false);

    if (notify) {
      notifyListeners();
    }

    try {
      final loadedItems = _repository.getItems();

      _items = List<FixedMenuItemModel>.unmodifiable(loadedItems);

      _rebuildItemIndex();
      _bumpVersion();

      return true;
    } catch (error, stackTrace) {
      _recordError(error, stackTrace, message: 'تعذر تحميل القائمة الثابتة');

      return false;
    } finally {
      _isLoading = false;

      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<bool> createItem({required String name, required double price}) async {
    clearError(notify: false);

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      _setOperationError('اسم الصنف مطلوب');
      return false;
    }

    if (!_isValidPrice(price)) {
      _setOperationError('سعر الصنف غير صحيح');
      return false;
    }

    return _runMutation(
      failureMessage: 'تعذر إضافة الصنف',
      operation: () async {
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
      },
    );
  }

  Future<bool> updateItem({
    required FixedMenuItemModel item,
    required String name,
    required double price,
  }) async {
    clearError(notify: false);

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      _setOperationError('اسم الصنف مطلوب');
      return false;
    }

    if (!_isValidPrice(price)) {
      _setOperationError('سعر الصنف غير صحيح');
      return false;
    }

    final itemKey = item.key;

    if (itemKey == null) {
      _setOperationError('الصنف غير محفوظ');
      return false;
    }

    final currentItem = _itemByKey[itemKey] ?? item;

    if (currentItem.name.trim() == cleanName && currentItem.price == price) {
      return true;
    }

    return _runMutation(
      failureMessage: 'تعذر تعديل الصنف',
      operation: () async {
        final updatedItem = await _repository.updateItem(
          itemKey: itemKey,
          name: cleanName,
          price: price,
        );

        if (updatedItem == null) {
          _setOperationError('لم يعد الصنف موجودًا');
          return false;
        }

        return _replaceItemInMemory(updatedItem);
      },
    );
  }

  Future<bool> deleteItem(FixedMenuItemModel item) async {
    clearError(notify: false);

    return _runMutation(
      failureMessage: 'تعذر حذف الصنف',
      operation: () async {
        final itemKey = item.key;

        final deleted = await _repository.deleteItem(
          item: item,
          itemKey: itemKey,
        );

        if (!deleted) {
          _setOperationError('لم يعد الصنف موجودًا');
          return false;
        }

        if (itemKey == null) {
          return loadMenu(notify: false);
        }

        return _removeItemFromMemory(itemKey);
      },
    );
  }

  Future<void> compactStorage() async {
    await _runMutation(
      failureMessage: 'تعذر تحسين مساحة التخزين',
      operation: () async {
        await _repository.compactMenuBox();
        return true;
      },
    );
  }

  bool _replaceItemInMemory(FixedMenuItemModel updatedItem) {
    final updatedKey = updatedItem.key;

    if (updatedKey == null) {
      _setOperationError('تعذر تحديد الصنف بعد الحفظ');
      return false;
    }

    final index = _items.indexWhere((item) => item.key == updatedKey);

    if (index == -1) {
      final loaded = loadMenu(notify: false);

      if (!loaded) {
        _setOperationError('تم الحفظ ولكن تعذر تحديث القائمة');
      }

      return loaded;
    }

    final nextItems = List<FixedMenuItemModel>.of(_items, growable: true);

    nextItems[index] = updatedItem;
    nextItems.sort(_compareItems);

    _items = List<FixedMenuItemModel>.unmodifiable(nextItems);
    _itemByKey[updatedKey] = updatedItem;

    _bumpVersion();

    return true;
  }

  bool _removeItemFromMemory(dynamic itemKey) {
    final beforeLength = _items.length;

    final nextItems = _items
        .where((item) => item.key != itemKey)
        .toList(growable: false);

    if (nextItems.length == beforeLength) {
      return loadMenu(notify: false);
    }

    _items = List<FixedMenuItemModel>.unmodifiable(nextItems);
    _itemByKey.remove(itemKey);

    _bumpVersion();

    return true;
  }

  void _rebuildItemIndex() {
    _itemByKey
      ..clear()
      ..addEntries(
        _items
            .where((item) => item.key != null)
            .map((item) => MapEntry(item.key, item)),
      );
  }

  Future<bool> _runMutation({
    required String failureMessage,
    required Future<bool> Function() operation,
  }) async {
    if (_isMutating) {
      _setOperationError('توجد عملية حفظ أخرى قيد التنفيذ');
      return false;
    }

    _isMutating = true;
    clearError(notify: false);
    notifyListeners();

    try {
      final success = await operation();

      if (!success && _lastErrorMessage == null) {
        _lastErrorMessage = failureMessage;
      }

      return success;
    } catch (error, stackTrace) {
      _recordError(error, stackTrace, message: failureMessage);

      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  void clearError({bool notify = true}) {
    if (_lastError == null &&
        _lastStackTrace == null &&
        _lastErrorMessage == null) {
      return;
    }

    _lastError = null;
    _lastStackTrace = null;
    _lastErrorMessage = null;

    if (notify) {
      notifyListeners();
    }
  }

  void _setOperationError(String message) {
    _lastError = null;
    _lastStackTrace = null;
    _lastErrorMessage = message;
  }

  void _recordError(
    Object error,
    StackTrace stackTrace, {
    required String message,
  }) {
    _lastError = error;
    _lastStackTrace = stackTrace;
    _lastErrorMessage = message;

    debugPrint(
      'FixedMenuProvider error: $message\n'
      'Error: $error\n'
      'StackTrace: $stackTrace',
    );
  }

  static bool _isValidPrice(double price) {
    return price.isFinite && price > 0;
  }

  static int _compareItems(FixedMenuItemModel a, FixedMenuItemModel b) {
    final nameCompare = a.displayName.compareTo(b.displayName);

    if (nameCompare != 0) {
      return nameCompare;
    }

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
