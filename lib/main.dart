import 'package:flutter/widgets.dart';

import 'app/foliomed_app.dart';
import 'app/startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ready = await prepareApp();
  runApp(ready ? const FolioMedApp() : const ConfigMissingApp());
}
