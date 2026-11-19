import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flashdrop/screens/benchmark/benchmark_screen.dart';
import 'package:flashdrop/screens/connection/connection_screen.dart';
import 'package:flashdrop/screens/history/history_screen.dart';
import 'package:flashdrop/screens/home/home_screen.dart';
import 'package:flashdrop/screens/receive/receive_screen.dart';
import 'package:flashdrop/screens/send/send_screen.dart';
import 'package:flashdrop/screens/settings/settings_screen.dart';
import 'package:flashdrop/screens/success/success_screen.dart';
import 'package:flashdrop/screens/transfer/transfer_screen.dart';

CustomTransitionPage<void> _subtlePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (_, animation, __, pageChild) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: pageChild,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', pageBuilder: (_, state) => _subtlePage(state, const HomeScreen())),
    GoRoute(path: '/send', pageBuilder: (_, state) => _subtlePage(state, const SendScreen())),
    GoRoute(path: '/receive', pageBuilder: (_, state) => _subtlePage(state, const ReceiveScreen())),
    GoRoute(path: '/connection', pageBuilder: (_, state) => _subtlePage(state, const ConnectionScreen())),
    GoRoute(path: '/transfer', pageBuilder: (_, state) => _subtlePage(state, const TransferScreen())),
    GoRoute(path: '/success', pageBuilder: (_, state) => _subtlePage(state, const SuccessScreen())),
    GoRoute(path: '/history', pageBuilder: (_, state) => _subtlePage(state, const HistoryScreen())),
    GoRoute(path: '/settings', pageBuilder: (_, state) => _subtlePage(state, const SettingsScreen())),
    GoRoute(path: '/benchmark', pageBuilder: (_, state) => _subtlePage(state, const BenchmarkScreen())),
  ],
);
