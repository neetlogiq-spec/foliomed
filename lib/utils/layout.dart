import 'package:flutter/widgets.dart';

/// Adds the bottom inset of floating chrome (the translucent tab bar and
/// the home indicator) to a scroll view's own padding, so content can
/// scroll *under* the bar yet the last row still clears it.
///
/// [MediaQuery.paddingOf] already includes the tab bar's height inside
/// the main scaffold (it uses `extendBody`), and just the safe area
/// elsewhere.
EdgeInsets withBottomBarInset(BuildContext context, EdgeInsets padding) =>
    padding.copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom);
