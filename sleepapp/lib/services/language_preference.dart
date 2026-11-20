import 'package:flutter/foundation.dart' show kIsWeb;

import 'browser_store.dart';

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/rest_strings.dart';

class LanguagePreference {
  static final selected = ValueNotifier<Locale?>(null);
  static Future<void> _writeTail = Future<void>.value();

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'language.txt'));
  }

  static Future<void> restore() async {
    try {
      String? raw;
      if (kIsWeb) {
        raw = browserRead("rest_language");
      } else {
        final file = await _file();
        if (await file.exists()) raw = await file.readAsString();
      }
      if (raw == null) return;
      final locale = Locale(raw.trim());
      if (RestStrings.supportedLocales.contains(locale)) {
        selected.value = locale;
      }
    } catch (error) {
      debugPrint('Could not restore language: $error');
    }
  }

  static Future<void> save(Locale? locale) {
    selected.value = locale;
    final write = _writeTail.then((_) async {
      if (kIsWeb) {
        browserWrite("rest_language", locale?.languageCode ?? "system");
        return;
      }
      final file = await _file();
      final pending = File('${file.path}.tmp');
      await pending.writeAsString(
        locale?.languageCode ?? 'system',
        flush: true,
      );
      await pending.rename(file.path);
    });
    _writeTail = write.catchError((Object _) {});
    return write;
  }
}
