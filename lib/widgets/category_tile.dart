// lib/widgets/category_tile.dart

import 'package:flutter/material.dart';

class CategoryTile extends StatelessWidget {
  final String categoryName;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.categoryName,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    // Corrección de sintaxis: Envuelto en llaves {}
    if (name.contains('bebidas')) {
      return Icons.local_drink_outlined;
    }
    if (name.contains('lácteos') || name.contains('leche')) {
      return Icons.water_drop_outlined;
    }
    if (name.contains('panadería')) {
      return Icons.bakery_dining_outlined;
    }
    if (name.contains('frutas') || name.contains('verduras')) {
      return Icons.local_florist_outlined;
    }
    if (name.contains('limpieza')) {
      return Icons.cleaning_services_outlined;
    }
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 85,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green[100] : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                _getCategoryIcon(categoryName),
                size: 30,
                color: isSelected ? Colors.green[700] : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              categoryName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green[700] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
