import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/neu_colors.dart';

/// Root wrapper for every Neu screen.
///
/// Controls status-bar / nav-bar icon colours and SafeArea from a single
/// place. Swap [lightStatusIcons] to true on dark-background screens so
/// the system icons stay visible.
class NeuBaseScreen extends StatelessWidget {
  const NeuBaseScreen({
    super.key,
    required this.child,
    this.backgroundColor = NeuColors.screenBackground,
    this.lightStatusIcons = false,
    this.useSafeArea = true,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final Color backgroundColor;

  /// true  → dark background → white status-bar icons.
  /// false → light background → dark status-bar icons.
  final bool lightStatusIcons;
  final bool useSafeArea;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            lightStatusIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            lightStatusIcons ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness:
            lightStatusIcons ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: useSafeArea ? SafeArea(child: child) : child,
      ),
    );
  }
}