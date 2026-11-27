import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';

class PetMateApp extends ConsumerStatefulWidget {
  const PetMateApp({super.key});

  @override
  ConsumerState<PetMateApp> createState() => _PetMateAppState();
}

class _PetMateAppState extends ConsumerState<PetMateApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize();
      ref.read(fcmServiceProvider).syncToken();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // If a pending notification route exists after login or cold start, navigate to it
    ref.listen(pendingNotificationRouteProvider, (_, next) {
      if (next != null && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            router.go(next);
          } catch (_) {
            router.go('/');
          }
          ref.read(pendingNotificationRouteProvider.notifier).clear();
        });
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
