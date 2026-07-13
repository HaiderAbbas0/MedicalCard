import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';

/// Lightweight in-app localization. Keys resolve to English or Urdu based on
/// the current [LanguageProvider]. Missing keys fall back to the key itself.
class AppStrings {
  static const Map<String, String> _en = {
    // Bottom navigation
    'nav.home': 'Home',
    'nav.history': 'Records',
    'nav.rx': 'Rx',
    'nav.reports': 'Reports',
    'nav.profile': 'Profile',
    // Dashboard
    'dash.greeting_morning': 'Good morning',
    'dash.greeting_afternoon': 'Good afternoon',
    'dash.greeting_evening': 'Good evening',
    'dash.quick_actions': 'Quick Actions',
    'dash.my_card': 'My Card',
    'dash.reminders': 'Reminders',
    'dash.allergies': 'Allergies',
    'dash.appointments': 'Appointments',
    'dash.recent_activity': 'Recent Activity',
    // Settings
    'settings.title': 'Settings',
    'settings.preferences': 'PREFERENCES',
    'settings.language': 'Language',
    'settings.appearance': 'Appearance',
    'settings.security_privacy': 'SECURITY & PRIVACY',
    'settings.change_password': 'Change password',
    'settings.login_security': 'Login & security',
    'settings.consent': 'Consent management',
    'settings.help': 'Help & support',
    'settings.logout': 'Log out',
    // Common
    'common.view_all': 'View all',
    'common.see_all': 'See all',
  };

  static const Map<String, String> _ur = {
    // Bottom navigation
    'nav.home': 'ہوم',
    'nav.history': 'ریکارڈز',
    'nav.rx': 'نسخہ',
    'nav.reports': 'رپورٹس',
    'nav.profile': 'پروفائل',
    // Dashboard
    'dash.greeting_morning': 'صبح بخیر',
    'dash.greeting_afternoon': 'سہ پہر بخیر',
    'dash.greeting_evening': 'شام بخیر',
    'dash.quick_actions': 'فوری اقدامات',
    'dash.my_card': 'میرا کارڈ',
    'dash.reminders': 'یاد دہانیاں',
    'dash.allergies': 'الرجیاں',
    'dash.appointments': 'ملاقاتیں',
    'dash.recent_activity': 'حالیہ سرگرمی',
    // Settings
    'settings.title': 'ترتیبات',
    'settings.preferences': 'ترجیحات',
    'settings.language': 'زبان',
    'settings.appearance': 'ظاہری شکل',
    'settings.security_privacy': 'سیکیورٹی اور پرائیویسی',
    'settings.change_password': 'پاس ورڈ تبدیل کریں',
    'settings.login_security': 'لاگ ان اور سیکیورٹی',
    'settings.consent': 'رضامندی کا انتظام',
    'settings.help': 'مدد اور معاونت',
    'settings.logout': 'لاگ آؤٹ',
    // Common
    'common.view_all': 'سب دیکھیں',
    'common.see_all': 'سب دیکھیں',
  };

  static String get(String key, bool urdu) {
    final map = urdu ? _ur : _en;
    return map[key] ?? _en[key] ?? key;
  }
}

extension Tr on BuildContext {
  /// Translate a key for the current language. Watches LanguageProvider so the
  /// UI rebuilds when the language changes.
  String tr(String key) {
    final urdu = watch<LanguageProvider>().isUrdu;
    return AppStrings.get(key, urdu);
  }
}
