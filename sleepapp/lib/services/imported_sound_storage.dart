import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sound.dart';

class ImportedSoundStorage {
  static const _extensions = ['mp3', 'm4a', 'wav'];
  static const _audioTypes = XTypeGroup(
    label: 'Audio files',
    extensions: _extensions,
    mimeTypes: [
      'audio/mpeg',
      'audio/mp4',
      'audio/x-m4a',
      'audio/wav',
      'audio/x-wav',
    ],
    uniformTypeIdentifiers: [
      'public.mp3',
      'com.apple.m4a-audio',
      'public.mpeg-4-audio',
      'com.microsoft.waveform-audio',
    ],
  );

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'imported_sounds'));
  }

  Future<List<Sound>> load() async {
    final directory = await _directory();
    if (!await directory.exists()) return [];

    final sounds = <Sound>[];
    await for (final entry in directory.list(followLinks: false)) {
      final id = p.basename(entry.path);
      if (entry is! Directory || !id.startsWith('sound-')) continue;
      await for (final file in entry.list(followLinks: false)) {
        if (file is File && _isSupported(file.path)) {
          sounds.add(_sound(id, file.path));
          break;
        }
      }
    }
    sounds.sort((a, b) => b.file.compareTo(a.file));
    return sounds;
  }

  Future<Sound?> pickAndImport() async {
    final source = await openFile(acceptedTypeGroups: [_audioTypes]);
    if (source == null) return null;
    if (!_isSupported(source.name)) {
      throw const FormatException('Choose an MP3, M4A, or WAV audio file.');
    }

    final directory = await (await _directory()).create(recursive: true);
    final staging = await directory.createTemp('.pending-');
    try {
      final name = _safeName(source.name);
      final copy = File(p.join(staging.path, name));
      final sink = copy.openWrite();
      try {
        await sink.addStream(source.openRead());
      } finally {
        await sink.close();
      }
      if (await copy.length() == 0) {
        throw const FormatException('This audio file is empty.');
      }

      await _checkPlayable(copy.path);
      // Publish only completed imports. The stable directory name is the
      // saved mix key, even if the device changes the app's storage path.
      final suffix = p.basename(staging.path).substring('.pending-'.length);
      final id = 'sound-${DateTime.now().microsecondsSinceEpoch}-$suffix';
      final imported = await staging.rename(p.join(directory.path, id));
      return _sound(id, p.join(imported.path, name));
    } catch (_) {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        // An incomplete import is ignored when the library is loaded.
      }
      rethrow;
    }
  }

  Future<void> _checkPlayable(String path) async {
    final player = AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    try {
      await player.setFilePath(path);
    } on PlayerException {
      throw const FormatException('REST couldn’t read this audio file.');
    } finally {
      await player.dispose();
    }
  }

  static bool _isSupported(String name) => _extensions.any(
    (extension) => p.extension(name).toLowerCase() == '.$extension',
  );

  static String _safeName(String original) {
    final stem = p
        .basenameWithoutExtension(original)
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'^[ .]+|[ .]+$'), '');
    final shortened = String.fromCharCodes(stem.runes.take(48));
    final extension = p.extension(original).toLowerCase();
    return '${shortened.isEmpty ? 'Imported audio' : shortened}$extension';
  }

  static Sound _sound(String id, String path) => Sound.imported(
    id: id,
    name: p.basenameWithoutExtension(path),
    path: path,
  );
}
