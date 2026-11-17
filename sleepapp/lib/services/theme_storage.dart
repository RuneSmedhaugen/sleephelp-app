import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/rest_style.dart';

class ThemeStorage {
  static Future<void> _writeTail = Future<void>.value();

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'theme.txt'));
  }

  static Future<RestStyle> load() async {
    final file = await _file();
    if (!await file.exists()) return RestStyle.all.first;
    final id = (await file.readAsString()).trim();
    return RestStyle.all.firstWhere(
      (style) => style.id == id,
      orElse: () => RestStyle.all.first,
    );
  }

  static Future<void> save(RestStyle style) {
    // Finish writes in tap order when the user tries several themes quickly.
    final write = _writeTail.then((_) async {
      final file = await _file();
      final pending = File('${file.path}.tmp');
      await pending.writeAsString(style.id, flush: true);
      await pending.rename(file.path);
    });
    _writeTail = write.catchError((Object _) {});
    return write;
  }
}
