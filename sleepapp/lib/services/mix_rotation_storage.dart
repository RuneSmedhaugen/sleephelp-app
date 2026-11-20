import 'package:flutter/foundation.dart' show kIsWeb;

import 'browser_store.dart';

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/mix_rotation.dart';

class MixRotationStorage {
  Future<void> _writeTail = Future<void>.value();

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, 'mix_rotation.json'));
  }

  Future<(MixRotation, String?)> load() async {
    String? raw;
    if (kIsWeb) {
      raw = browserRead("rest_rotation");
    } else {
      final file = await _file();
      if (await file.exists()) raw = await file.readAsString();
    }
    if (raw == null) return (const MixRotation(), null);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (
      MixRotation.fromJson(json['rotation'] as Map<String, dynamic>),
      json['lastPlayedId'] as String?,
    );
  }

  Future<void> save(MixRotation rotation, String? lastPlayedId) {
    final contents = jsonEncode({
      'rotation': rotation.toJson(),
      'lastPlayedId': lastPlayedId,
    });
    final write = _writeTail.then((_) async {
      if (kIsWeb) {
        browserWrite("rest_rotation", contents);
        return;
      }
      final file = await _file();
      final pending = File('${file.path}.tmp');
      await pending.writeAsString(contents, flush: true);
      await pending.rename(file.path);
    });
    _writeTail = write.catchError((Object _) {});
    return write;
  }
}
