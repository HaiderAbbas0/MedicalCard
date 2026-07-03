import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/language/language_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/card/health_card_screen.dart';
import 'screens/card/card_request_screen.dart';
import 'screens/card/physical_card_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/history/visit_detail_screen.dart';
import 'screens/prescriptions/prescriptions_screen.dart';
import 'screens/medications/reminders_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/messages/chat_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/settings_pages.dart';
import 'screens/doctor/doctor_home_screen.dart';
import 'screens/lab/lab_home_screen.dart';
import 'screens/receptionist/reception_home_screen.dart';
import 'screens/common/admin_notice_screen.dart';
import 'screens/patient/appointments_screen.dart';
import 'screens/patient/allergies_screen.dart';
import 'widgets/common/bottom_nav_bar.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Fade transition used for full-screen pushes.
CustomTransitionPage<T> _fadePage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(
      opacity: CurveTween(curve: Curves.easeOut).animate(animation),
      child: child,
    ),
  );
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/language', builder: (_, _) => const LanguageScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
    GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(
            pendingSignup: state.extra as Map<String, dynamic>?)),

    // ── Role home screens (doctor / lab / receptionist / admin) ──────────
    GoRoute(path: '/doctor', builder: (_, _) => const DoctorHomeScreen()),
    GoRoute(path: '/lab', builder: (_, _) => const LabHomeScreen()),
    GoRoute(path: '/reception', builder: (_, _) => const ReceptionHomeScreen()),
    GoRoute(path: '/admin-notice', builder: (_, _) => const AdminNoticeScreen()),

    // ── Patient appointment booking (full-screen pushes) ─────────────────
    GoRoute(path: '/my-appointments', builder: (_, _) => const AppointmentsScreen()),
    GoRoute(path: '/my-allergies', builder: (_, _) => const AllergiesScreen()),
    GoRoute(
        path: '/reminders',
        pageBuilder: (_, s) => _fadePage(const RemindersScreen(), s)),

    // Full-screen pushes (above the bottom-nav shell).
    GoRoute(
        path: '/card',
        pageBuilder: (_, s) => _fadePage(const HealthCardScreen(), s)),
    GoRoute(
        path: '/card-request',
        pageBuilder: (_, s) => _fadePage(const CardRequestScreen(), s)),
    GoRoute(
        path: '/physical-card',
        pageBuilder: (_, s) => _fadePage(const PhysicalCardScreen(), s)),
    GoRoute(
        path: '/messages',
        pageBuilder: (_, s) => _fadePage(const MessagesScreen(), s)),
    GoRoute(
      path: '/chat/:doctorId',
      pageBuilder: (_, s) =>
          _fadePage(ChatScreen(doctorId: s.pathParameters['doctorId']!), s),
    ),
    GoRoute(
        path: '/notifications',
        pageBuilder: (_, s) => _fadePage(const NotificationsScreen(), s)),
    GoRoute(
        path: '/settings',
        pageBuilder: (_, s) => _fadePage(const SettingsScreen(), s)),
    GoRoute(
        path: '/settings/change-password',
        pageBuilder: (_, s) => _fadePage(const ChangePasswordScreen(), s)),
    GoRoute(
        path: '/settings/login-security',
        pageBuilder: (_, s) => _fadePage(const LoginSecurityScreen(), s)),
    GoRoute(
        path: '/settings/consent',
        pageBuilder: (_, s) => _fadePage(const ConsentManagementScreen(), s)),
    GoRoute(
        path: '/settings/help',
        pageBuilder: (_, s) => _fadePage(const HelpSupportScreen(), s)),
    GoRoute(
        path: '/edit-profile',
        pageBuilder: (_, s) => _fadePage(const EditProfileScreen(), s)),

    // ── Bottom-nav shell ──────────────────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/dashboard',
              builder: (_, _) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/history',
            builder: (_, _) => const HistoryScreen(),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (_, s) => _fadePage(
                    VisitDetailScreen(visitId: s.pathParameters['id']!), s),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/prescriptions',
              builder: (_, _) => const PrescriptionsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ]),
      ],
    ),
  ],
);
