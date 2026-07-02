import '../../models/auth_model.dart';

/// Maps a [UserRole] to its home route. Patients keep the original dashboard;
/// the other mobile roles route to their dedicated home screens. Admins are
/// shown a notice (they use the web portal).
String roleHome(UserRole role) {
  switch (role) {
    case UserRole.patient:
      return '/dashboard';
    case UserRole.doctor:
      return '/doctor';
    case UserRole.labWorker:
      return '/lab';
    case UserRole.receptionist:
      return '/reception';
    case UserRole.admin:
      return '/admin-notice';
    case UserRole.unknown:
      return '/dashboard';
  }
}
