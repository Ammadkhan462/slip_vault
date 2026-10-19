import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');

  void setLocale(Locale loc) {
    state = loc;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class ProStatusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setPro(bool isPro) {
    state = isPro;
  }
}

final proStatusProvider = NotifierProvider<ProStatusNotifier, bool>(
  ProStatusNotifier.new,
);

class AppLockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLock(bool enabled) {
    state = enabled;
  }
}

final appLockProvider = NotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);
