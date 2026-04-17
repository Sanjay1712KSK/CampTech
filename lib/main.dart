import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/auth/screens/email_confirmation_result_screen.dart';
import 'package:guidewire_gig_ins/features/auth/screens/role_selection_screen.dart';
import 'package:guidewire_gig_ins/features/dashboard/screens/dashboard_loader.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/auth_storage_service.dart';
import 'package:guidewire_gig_ins/services/device_auth_service.dart';

ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
          navigatorKey: rootNavigatorKey,
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
          home: const _DeepLinkHost(),
        );
      },
    );
  }
}

class _DeepLinkHost extends StatefulWidget {
  const _DeepLinkHost();

  @override
  State<_DeepLinkHost> createState() => _DeepLinkHostState();
}

class _DeepLinkHostState extends State<_DeepLinkHost> {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      return;
    }
    _appLinks = AppLinks();
    _linkSubscription = _appLinks!.uriLinkStream.listen(_handleUri);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    });
  }

  void _handleUri(Uri uri) {
    if (uri.scheme != 'gigshield' || uri.host != 'confirm-email') {
      return;
    }
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => EmailConfirmationResultScreen(link: uri),
      ),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const _AuthBootstrapScreen();
  }
}

class _AuthBootstrapScreen extends ConsumerStatefulWidget {
  const _AuthBootstrapScreen();

  @override
  ConsumerState<_AuthBootstrapScreen> createState() =>
      _AuthBootstrapScreenState();
}

class _AuthBootstrapScreenState extends ConsumerState<_AuthBootstrapScreen> {
  static const DeviceAuthService _deviceAuth = DeviceAuthService();
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
        ref
            .read(userProvider.notifier)
            .setAuthenticatedUser(user, accessToken: session.accessToken);
        return _BootstrapResult.main;
      } catch (_) {
        await AuthStorageService.clearSession();
        return _BootstrapResult.login;
      }
    }

    final canUseBiometrics = await _deviceAuth.canUseBiometrics();
    if (!canUseBiometrics) return _BootstrapResult.login;

    final didAuthenticate = await _deviceAuth.authenticate(
      reason: 'Unlock your insured gig profile',
    );
    if (!didAuthenticate) return _BootstrapResult.login;

    try {
      final user = await ApiService.getCurrentUser(session.accessToken);
      ref
          .read(userProvider.notifier)
          .setAuthenticatedUser(user, accessToken: session.accessToken);
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
          return const RoleSelectionScreen();
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == _BootstrapResult.main) {
          return const DashboardLoader();
        }

        return const RoleSelectionScreen();
      },
    );
  }
}

enum _BootstrapResult { login, main }
