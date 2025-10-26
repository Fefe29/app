import 'package:flutter/material.dart';

/// Bouton de zoom moderne : noir sur fond blanc, rond, ombre légère
class ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const ZoomButton({required this.icon, required this.onTap, this.tooltip, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.black, size: 28),
        ),
      ),
    );
  }
}
