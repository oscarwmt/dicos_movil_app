// lib/widgets/cart_item_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item_model.dart';
import '../providers/cart_provider.dart';

class CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final bool isInStock;

  const CartItemCard(
      {super.key, required this.cartItem, required this.isInStock});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${cartItem.product.id}_${isInStock ? 'in' : 'out'}'),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        child: const Icon(Icons.delete, color: Colors.white, size: 40),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) {
        return showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Estás seguro?'),
            content: const Text('¿Quieres eliminar este artículo?'),
            actions: <Widget>[
              TextButton(
                  child: const Text('No'),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: const Text('Sí'),
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        Provider.of<CartProvider>(context, listen: false)
            .removeItem(cartItem.product.id, isInStock: isInStock);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ListTile(
            leading: CircleAvatar(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: FittedBox(
                  child: Text('\$${cartItem.product.price}'),
                ),
              ),
            ),
            title: Text(cartItem.product.name),
            subtitle: Text(
                'Total: \$${(cartItem.product.price * cartItem.quantity)}'),
            trailing: Text('${cartItem.quantity} x'),
          ),
        ),
      ),
    );
  }
}
