import 'package:flutter/material.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/feature_screens.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/create_password_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import 'routes_name.dart';

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RoutesName.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RoutesName.featureScreens:
        return MaterialPageRoute(builder: (_) => const FeatureScreens());
      case RoutesName.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case RoutesName.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case RoutesName.createPassword:
        return MaterialPageRoute(builder: (_) => const CreatePasswordScreen());
      case RoutesName.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingFlowScreen());
      case RoutesName.dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
