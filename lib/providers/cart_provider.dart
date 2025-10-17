// lib/providers/cart_provider.dart

import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart'; // Asegúrate de que esta importación exista

class CartProvider with ChangeNotifier {
  final Map<int, CartItem> _items = {};
  Customer? _currentCustomer;

  // --- Getters ---
  List<CartItem> get items => _items.values.toList();
  Customer? get currentCustomer => _currentCustomer;
  int get totalUniqueItems => _items.length;
  double get totalAmount {
    double total = 0.0;
    for (var item in _items.values) {
      if (item.product.stock > 0) {
        total += item.product.price * item.quantity;
      }
    }
    return total;
  }

  List<CartItem> get inStockItems =>
      _items.values.where((item) => item.product.stock > 0).toList();
  List<CartItem> get outOfStockItems =>
      _items.values.where((item) => item.product.stock <= 0).toList();

  // --- Métodos de Mutación ---

  void setCustomer(Customer customer) {
    _currentCustomer = customer;
    notifyListeners();
  }

  // ✅ SOLUCIÓN: Se añadió el tipo 'Product' al parámetro 'product'
  void addItem(Product product, {int quantity = 1}) {
    final productId = product.id;
    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + quantity,
        ),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(product: product, quantity: quantity),
      );
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void removeSingleItem(int productId) {
    if (!_items.containsKey(productId)) {
      return;
    }

    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _currentCustomer = null;
    notifyListeners();
  }
}
