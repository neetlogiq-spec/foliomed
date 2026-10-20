import 'package:flutter/material.dart';

/// For code that runs outside the widget tree (e.g. realtime alerts) and
/// still needs to show a banner or navigate.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
