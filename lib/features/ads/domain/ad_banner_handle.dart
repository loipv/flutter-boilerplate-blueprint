import 'package:flutter/widgets.dart';

/// A loaded banner ad. Call [dispose] when the banner leaves the screen.
abstract class AdBannerHandle {
  Widget get widget;
  Size get size;
  void dispose();
}
