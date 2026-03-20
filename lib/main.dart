import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/auth/screens/login_screen.dart';
import 'package:guidewire_gig_ins/features/auth/screens/signup_screen.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';

ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final String? savedLang = prefs.getString('app_language');
  if (savedLang != null) {
    appLocale.value = Locale(savedLang);
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'Gig Worker Insurance',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('kn'),
            Locale('mr'),
            Locale('ta'),
            Locale('te'),
            Locale('ur'),
          ],
          home: const SignupScreen(),
        );
      },
    );
  }
}
