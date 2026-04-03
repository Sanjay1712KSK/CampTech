import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/auth/screens/login_screen.dart';
import 'package:guidewire_gig_ins/features/auth/screens/post_auth_gate_screen.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/auth_storage_service.dart';

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
          home: const _AuthBootstrapScreen(),
        );
      },
    );
  }
}

class _AuthBootstrapScreen extends ConsumerStatefulWidget {
  const _AuthBootstrapScreen();

  @override
  ConsumerState<_AuthBootstrapScreen> createState() => _AuthBootstrapScreenState();
}

class _AuthBootstrapScreenState extends ConsumerState<_AuthBootstrapScreen> {
  Future<_BootstrapResult>? _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<_BootstrapResult> _bootstrap() async {
    final session = await AuthStorageService.getSession();
    if (session == null) return _BootstrapResult.login;

    final biometricEnabled = await AuthStorageService.isBiometricEnabled();
    if (!biometricEnabled) {
      try {
        final user = await ApiService.getCurrentUser(session.accessToken);
        ref.read(userProvider.notifier).setAuthenticatedUser(
              user,
              accessToken: session.accessToken,
            );
        return _BootstrapResult.main;
      } catch (_) {
        await AuthStorageService.clearSession();
        return _BootstrapResult.login;
      }
    }

    final auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics;
    final supported = await auth.isDeviceSupported();
    if (!canCheck && !supported) return _BootstrapResult.login;

    final didAuthenticate = await auth.authenticate(
      localizedReason: 'Unlock your insured gig profile',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!didAuthenticate) return _BootstrapResult.login;

    try {
      final user = await ApiService.getCurrentUser(session.accessToken);
      ref.read(userProvider.notifier).setAuthenticatedUser(
            user,
            accessToken: session.accessToken,
          );
      return _BootstrapResult.main;
    } catch (_) {
      await AuthStorageService.clearSession();
      await AuthStorageService.setBiometricEnabled(false);
      return _BootstrapResult.login;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapResult>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const LoginScreen();
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == _BootstrapResult.main) {
          return const PostAuthGateScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

enum _BootstrapResult { login, main }
