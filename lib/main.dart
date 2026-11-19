import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashdrop/core/constants/app_constants.dart';
import 'package:flashdrop/core/theme/app_theme.dart';
import 'package:flashdrop/providers/transport_provider.dart';
import 'package:flashdrop/routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FlashDropApp()));
}

class FlashDropApp extends ConsumerWidget {
  const FlashDropApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: FlashDropTheme.light,
      darkTheme: FlashDropTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
