// lib/providers/cart_provider.dart

import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart';

class CartProvider with ChangeNotifier {
  List<CartItem> _inStockItems = [];
  List<CartItem> _outOfStockItems = [];
  Customer? _customer;

  List<CartItem> get inStockItems => [..._inStockItems];
  List<CartItem> get outOfStockItems => [..._outOfStockItems];
  Customer? get customer => _customer;

  int get totalUniqueItems => _inStockItems.length + _outOfStockItems.length;

  double get totalAmount {
    var total = 0.0;
    for (var cartItem in _inStockItems) {
      total += cartItem.product.price * cartItem.quantity;
    }
    return total;
  }

  void setCustomer(Customer newCustomer) {
    if (_customer == null || _customer!.id != newCustomer.id) {
      clear();
      _customer = newCustomer;
      notifyListeners();
    }
  }

  void addItem(Product product, {int quantity = 1}) {
    if (product.stock > 0) {
      _addToCorrectList(_inStockItems, product, quantity);
    } else {
      _addToCorrectList(_outOfStockItems, product, quantity);
    }
    notifyListeners();
  }

  void _addToCorrectList(List<CartItem> list, Product product, int quantity) {
    final existingIndex =
        list.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      list[existingIndex].quantity += quantity;
    } else {
      list.add(CartItem(
        product: product,
        quantity: quantity,
      ));
    }
  }

  void removeSingleItem(int productId, {required bool isInStock}) {
    final list = isInStock ? _inStockItems : _outOfStockItems;
    final existingIndex =
        list.indexWhere((item) => item.product.id == productId);
    if (existingIndex < 0) return;

    if (list[existingIndex].quantity > 1) {
      list[existingIndex].quantity--;
    } else {
      list.removeAt(existingIndex);
    }
    notifyListeners();
  }

  void removeItem(int productId, {required bool isInStock}) {
    final list = isInStock ? _inStockItems : _outOfStockItems;
    list.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _inStockItems = [];
    _outOfStockItems = [];
    _customer = null;
    notifyListeners();
  }
}
