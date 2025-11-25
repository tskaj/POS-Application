import 'package:flutter/material.dart';

class PosFooter extends StatelessWidget {
  final VoidCallback onNewOrder;
  final VoidCallback onHoldOrder;
  final VoidCallback onPrintReceipt;
  final VoidCallback onSettings;

  const PosFooter({
    super.key,
    required this.onNewOrder,
    required this.onHoldOrder,
    required this.onPrintReceipt,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 120),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1845),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1845),
            const Color(0xFF0D1845).withOpacity(0.95),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrollable Action Buttons
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // New Order Button
                  _buildFooterButton(
                    icon: Icons.add_circle_outline,
                    label: 'New Order',
                    color: Colors.green.shade600,
                    onPressed: onNewOrder,
                  ),

                  const SizedBox(width: 12),

                  // Hold Order Button
                  _buildFooterButton(
                    icon: Icons.pause_circle_outline,
                    label: 'Hold Order',
                    color: Colors.orange.shade600,
                    onPressed: onHoldOrder,
                  ),

                  const SizedBox(width: 12),

                  // Print Receipt Button
                  _buildFooterButton(
                    icon: Icons.print,
                    label: 'Print Receipt',
                    color: Colors.blue.shade600,
                    onPressed: onPrintReceipt,
                  ),

                  const SizedBox(width: 12),

                  // Settings Button
                  _buildFooterButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    color: Colors.grey.shade600,
                    onPressed: onSettings,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Footer Info with improved styling
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store,
                  size: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Dhanpuri By Get Going POS System v1.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 140),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }
}
