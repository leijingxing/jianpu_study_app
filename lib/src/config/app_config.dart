import 'environment.dart';

final class AppConfig {
  const AppConfig({required this.environment});

  const AppConfig.production() : environment = Environment.production;

  final Environment environment;
}
