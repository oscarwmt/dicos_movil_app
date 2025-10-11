// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'sale_order/customer_selector_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  // Widget para mostrar la información del usuario
  Widget _buildUserInfoHeader(BuildContext context) {
    // --- INICIO DE LA CORRECCIÓN ---
    // Hacemos una validación segura para el equipo de venta.
    final teamInfoValue = userData['sale_team_id'];
    String teamName = 'Sin equipo'; // Valor por defecto

    // Solo si el valor es una lista y tiene al menos 2 elementos, extraemos el nombre.
    if (teamInfoValue is List && teamInfoValue.length > 1) {
      teamName = teamInfoValue[1];
    }
    // Si teamInfoValue es 'false' o cualquier otra cosa, teamName se queda como 'Sin equipo'.
    // --- FIN DE LA CORRECCIÓN ---

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Colors.deepPurple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido,',
            style: TextStyle(fontSize: 18, color: Colors.white.withAlpha(230)),
          ),
          const SizedBox(height: 4),
          Text(
            userData['name'] ?? 'Vendedor',
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.group_work_outlined,
                  color: Colors.white.withAlpha(230), size: 20),
              const SizedBox(width: 8),
              Text(
                'Zona: $teamName', // Usamos la variable segura
                style:
                    TextStyle(fontSize: 16, color: Colors.white.withAlpha(230)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para crear cada botón del menú
  Widget _buildMenuOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isFeatured = false,
  }) {
    final cardColor =
        isFeatured ? Theme.of(context).primaryColor : Colors.white;
    final textColor =
        isFeatured ? Colors.white : Theme.of(context).primaryColorDark;
    final iconColor =
        isFeatured ? Colors.white : Theme.of(context).primaryColor;

    return Card(
      elevation: isFeatured ? 8 : 4,
      shadowColor: isFeatured
          ? Theme.of(context).primaryColor.withAlpha(128)
          : Colors.black.withAlpha(51),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void showComingSoonMessage() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta funcionalidad estará disponible próximamente.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Vendedor'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildUserInfoHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuOption(
                    context: context,
                    icon: Icons.add_shopping_cart,
                    label: 'Nueva Venta',
                    isFeatured: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const CustomerSelectorScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuOption(
                    context: context,
                    icon: Icons.receipt_long,
                    label: 'Mis Ventas',
                    onTap: showComingSoonMessage,
                  ),
                  _buildMenuOption(
                    context: context,
                    icon: Icons.event_available,
                    label: 'Agenda y Oportunidades',
                    onTap: showComingSoonMessage,
                  ),
                  _buildMenuOption(
                    context: context,
                    icon: Icons.inventory_2_outlined,
                    label: 'Catálogo',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const CustomerSelectorScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
