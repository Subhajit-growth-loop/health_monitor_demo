import 'package:flutter/material.dart';

/// Drop-in image placeholder. Swap the internals for Image.asset / SvgPicture
/// once the real asset is ready — callers never need to change.
class NeuImagePlaceholder extends StatelessWidget {
  const NeuImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.image_rounded,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
    this.label,
  });

  final double? width;
  final double? height;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final BorderRadius? borderRadius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.grey.shade200;
    final ic = iconColor ?? Colors.grey.shade400;
    final iconSize = () {
      final w = width;
      final h = height;
      if (w != null && h != null && w.isFinite && h.isFinite) {
        return (w < h ? w : h) * 0.38;
      }
      return 40.0;
    }();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: ic, size: iconSize),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(
              label!,
              style: TextStyle(color: ic, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
