import 'package:shared_preferences/shared_preferences.dart';

const _onboardingKey = 'onboarding_done';

Future<bool> loadOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingKey) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingKey, true);
}
