// lib/providers/cart_provider.dart

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';

// ChangeNotifier es lo que Provider usa para notificar a los widgets sobre cambios
class CartProvider with ChangeNotifier {
  // Lista privada de ítems en el carrito
  final List<CartItem> _items = [];

  // Getter público para acceder a la lista (inmutable)
  List<CartItem> get items => _items;

  // Getter para obtener el número total de ítems únicos
  int get itemCount => _items.length;

  // Getter para calcular el total de la compra
  double get totalAmount {
    double total = 0.0;
    for (var item in _items) {
      total += item.product.price * item.quantity;
    }
    return total;
  }

  // Lógica para añadir un producto al carrito
  void addItem(Product product, {int quantity = 1}) {
    // 1. Verificar si el producto ya está en el carrito
    final existingItemIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingItemIndex >= 0) {
      // 2. Si existe, simplemente actualiza la cantidad
      _items[existingItemIndex].quantity += quantity;
    } else {
      // 3. Si no existe, añádelo como un nuevo ítem
      _items.add(CartItem(product: product, quantity: quantity));
    }

    // Notificar a todos los widgets que escuchan que el carrito ha cambiado
    notifyListeners();
  }

  // Lógica para remover un ítem completamente
  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  // Lógica para decrementar la cantidad de un producto
  void removeSingleItem(int productId) {
    final existingItemIndex = _items.indexWhere(
      (item) => item.product.id == productId,
    );

    if (existingItemIndex < 0) {
      return; // No hay nada que remover
    }

    if (_items[existingItemIndex].quantity > 1) {
      // Decrementa la cantidad
      _items[existingItemIndex].quantity--;
    } else {
      // Si la cantidad es 1, remueve el ítem completo
      _items.removeAt(existingItemIndex);
    }

    notifyListeners();
  }

  // Lógica para vaciar completamente el carrito
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
