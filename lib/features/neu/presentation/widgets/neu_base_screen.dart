import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';

/// Root wrapper for every Neu screen.
///
/// Controls status-bar / nav-bar icon colours and SafeArea from a single
/// place. Icon colour follows the active theme — black on light, white on dark —
/// unless [lightStatusIcons] overrides it, which only the screens painting a
/// dark full-bleed image need to do.
class NeuBaseScreen extends StatelessWidget {
  const NeuBaseScreen({
    super.key,
    required this.child,
    this.backgroundColor = NeuColors.screenBackground,
    this.lightStatusIcons,
    this.useSafeArea = true,
    this.bottomSafeArea = true,
    this.navigationBarColor,
    this.backgroundImage,
    this.backgroundFit = BoxFit.cover,
    this.backgroundOpacity = 1.0,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final Color backgroundColor;

  /// Optional full-screen background image behind the content. Accepts an
  /// asset path ending in `.svg` (rendered with flutter_svg) or a raster asset
  /// (`.jpg` / `.jpeg` / `.png`, rendered with [Image.asset]). Declare the
  /// asset under `assets/` in pubspec.yaml first.
  final String? backgroundImage;
  final BoxFit backgroundFit;
  final double backgroundOpacity;

  /// true  → white status-bar icons (for a dark background).
  /// false → black status-bar icons (for a light background).
  /// null  → follow the active theme. This is the default.
  final bool? lightStatusIcons;
  final bool useSafeArea;

  /// When false, the child paints through the bottom safe-area inset (so a
  /// bottom bar can reach the physical screen edge / home indicator). The child
  /// is then responsible for adding its own bottom padding.
  final bool bottomSafeArea;

  /// Android system navigation-bar backdrop colour. Defaults to
  /// [backgroundColor]; set to e.g. white to match a white bottom bar.
  final Color? navigationBarColor;

  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final navBarColor = navigationBarColor ?? backgroundColor;
    final lightIcons = lightStatusIcons ?? NeuSurface.of(context).isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: lightIcons
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: lightIcons
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: navBarColor,
        systemNavigationBarIconBrightness: lightIcons
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        // Install Hanken Grotesk as the ambient default so every `Text` on a
        // Neu screen inherits the brand sans unless it opts into the serif.
        body: DefaultTextStyle.merge(
          style: NeuTypography.baseSans,
          child: _withBackground(
            useSafeArea
                ? SafeArea(bottom: bottomSafeArea, child: child)
                : child,
          ),
        ),
      ),
    );
  }

  /// Paints [backgroundImage] (if any) full-bleed behind [content].
  Widget _withBackground(Widget content) {
    final image = backgroundImage;
    if (image == null) return content;

    final isSvg = image.toLowerCase().endsWith('.svg');
    final Widget bg = isSvg
        ? SvgPicture.asset(image, fit: backgroundFit)
        : Image.asset(image, fit: backgroundFit);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(opacity: backgroundOpacity, child: bg),
        ),
        content,
      ],
    );
  }
}
