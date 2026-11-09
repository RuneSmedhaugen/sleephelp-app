import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/sound_mix.dart';

class MixStorage {
  Future<File> _storageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}saved_mixes.json');
  }

  Future<List<SoundMix>> load() async {
    try {
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

  Future<void> save(List<SoundMix> mixes) async {
    final file = await _storageFile();
    await file.writeAsString(
      jsonEncode(mixes.map((mix) => mix.toJson()).toList()),
      flush: true,
    );
  }
}
