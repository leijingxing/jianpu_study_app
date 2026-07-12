import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_dependencies.dart';

/// Initializes infrastructure before exposing the application UI.
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppDependencies();
  await dependencies.initialize();
  runApp(
    ProviderScope(
      overrides: [appDependenciesProvider.overrideWithValue(dependencies)],
      child: AppLifecycle(
        dependencies: dependencies,
        child: const JianpuStudyApp(),
      ),
    ),
  );
}

class AppLifecycle extends StatefulWidget {
  const AppLifecycle({
    super.key,
    required this.dependencies,
    required this.child,
  });

  final AppDependencies dependencies;
  final Widget child;

  @override
  State<AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends State<AppLifecycle> {
  @override
  void dispose() {
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
