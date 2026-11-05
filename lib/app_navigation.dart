import 'environment_config.dart';

class AppNavigation {
  static void Function(String?)? _navigateToLogin;

  static void registerLoginNavigator(void Function(String?) navigate) {
    _navigateToLogin = navigate;
  }

  static void navigateToLoginIfCurrent(int generation, {String? warning}) {
    if (EnvironmentConfig.generation != generation) return;
    _navigateToLogin?.call(warning);
  }
}
