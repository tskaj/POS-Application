import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'calculator_dialog.dart';

class PosNavbar extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final Function(String)? onNavigateToContent;

  const PosNavbar({
    super.key,
    this.onBackToDashboard,
    this.onNavigateToContent,
  });

  @override
  State<PosNavbar> createState() => _PosNavbarState();
}

class _PosNavbarState extends State<PosNavbar> {
  late Timer _timer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateFormat('HH:mm:ss').format(DateTime.now());
    if (mounted && now != _currentTime) {
      setState(() {
        _currentTime = now;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: const Color(0xFF0D1845),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const SizedBox(width: 8),

          // Time Display (fixed minimum width to avoid jitter when seconds change)
          Container(
            constraints: const BoxConstraints(minWidth: 107),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _currentTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          // Calculator to the right of time with a small gap
          _buildActionButton(
            icon: Icons.calculate,
            tooltip: 'Calculator',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const CalculatorDialog(),
              );
            },
          ),

          // Invoices button
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: Tooltip(
              message: 'Invoices',
              child: ElevatedButton.icon(
                onPressed: () => widget.onNavigateToContent?.call('Invoices'),
                icon: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text(
                  'Invoices',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }
}
