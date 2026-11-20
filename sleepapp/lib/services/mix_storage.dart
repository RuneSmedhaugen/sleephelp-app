import 'package:flutter/foundation.dart' show kIsWeb;

import 'browser_store.dart';

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/sound_mix.dart';

class MixStorage {
  Future<void> _writeTail = Future<void>.value();
  Future<File> _storageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}saved_mixes.json');
  }

  Future<List<SoundMix>> load() async {
    try {
      if (kIsWeb) {
        final raw = browserRead("rest_mixes");
        if (raw == null) return [];
        return (jsonDecode(raw) as List)
            .map((item) => SoundMix.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      final file = await _storageFile();
      if (!await file.exists()) return [];
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      return decoded
          .map((item) => SoundMix.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    } on FileSystemException {
      return [];
    }
  }

  Future<void> save(List<SoundMix> mixes) {
    final contents = jsonEncode(mixes.map((mix) => mix.toJson()).toList());
    final write = _writeTail.then((_) async {
      if (kIsWeb) {
        browserWrite("rest_mixes", contents);
        return;
      }
      final file = await _storageFile();
      final pending = File('${file.path}.tmp');
      await pending.writeAsString(contents, flush: true);
      await pending.rename(file.path);
    });
    _writeTail = write.catchError((Object _) {});
    return write;
  }
}
