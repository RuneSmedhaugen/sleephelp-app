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
      final file = await _file();
      if (!await file.exists()) return;
      final locale = Locale((await file.readAsString()).trim());
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
