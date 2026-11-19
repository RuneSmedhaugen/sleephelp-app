import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleepapp/models/mix_rotation.dart';
import 'package:sleepapp/models/sound_mix.dart';
import 'package:sleepapp/services/mix_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late MixStorage storage;
  final original = SoundMix(
    id: 'scheduled',
    name: 'Original',
    sounds: ['birds.mp3'],
    volumes: {'birds.mp3': 0.4},
    updatedAt: DateTime(2026, 11, 18),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rest_mix_storage_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => directory.path);
    storage = MixStorage();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    for (final name in ['saved_mixes.json', 'saved_mixes.json.tmp']) {
      final path = '${directory.path}/$name';
      if (await File(path).exists()) await File(path).delete();
      if (await Directory(path).exists()) await Directory(path).delete();
    }
    await directory.delete();
  });

  test('updates retain scheduled IDs and duplicates are independent', () async {
    final rotation = MixRotation(
      mode: MixRotationMode.daily,
      days: List.filled(7, original.id),
      weeks: [original.id],
    );
    final updated = original.copyWith(
      name: 'Updated',
      volumes: {'birds.mp3': 0.7},
    );
    final duplicate = updated.copyWith(id: 'copy', name: 'Copy');
    await storage.save([updated, duplicate]);
    final loaded = await MixStorage().load();
    expect(loaded.map((mix) => mix.name), ['Updated', 'Copy']);
    expect(loaded.first.id, rotation.assignedMixId(DateTime(2026, 11, 18)));
    expect(rotation.weeks.single, loaded.first.id);
    expect(loaded.last.id, isNot(loaded.first.id));
    expect(identical(updated.sounds, duplicate.sounds), isFalse);
    expect(identical(updated.volumes, duplicate.volumes), isFalse);
    expect(original.volumes['birds.mp3'], 0.4);
  });

  test(
    'overlapping writes finish in order and capture their contents',
    () async {
      final mixes = [original];
      final first = storage.save(mixes);
      mixes.add(original.copyWith(id: 'copy'));
      final second = storage.save(mixes);
      await Future.wait([first, second]);
      expect((await storage.load()).map((mix) => mix.id), [
        'scheduled',
        'copy',
      ]);
    },
  );

  test('failed writes preserve the previous file and allow retries', () async {
    await storage.save([original]);
    final blocked = Directory('${directory.path}/saved_mixes.json.tmp');
    await blocked.create();
    await expectLater(
      storage.save([original.copyWith(name: 'Updated')]),
      throwsA(isA<FileSystemException>()),
    );
    expect((await storage.load()).single.name, 'Original');
    await blocked.delete();
    await storage.save([original.copyWith(name: 'Updated')]);
    expect((await storage.load()).single.name, 'Updated');
  });

  test(
    'timers survive restart, rename and duplication, and can be removed',
    () async {
      final timed = original.copyWith(
        timer: const MixTimerSettings(
          duration: Duration(hours: 8),
          fade: Duration(minutes: 10),
        ),
      );
      final renamed = timed.copyWith(name: 'Overnight');
      final duplicate = renamed.copyWith(id: 'copy');
      final defaultTimer = timed.copyWith(id: 'default', clearTimer: true);
      final timerOff = original.copyWith(
        id: 'off',
        timer: const MixTimerSettings(),
      );
      await storage.save([renamed, duplicate, defaultTimer, timerOff]);
      final loaded = await MixStorage().load();
      expect(loaded[0].timer!.duration, const Duration(hours: 8));
      expect(loaded[1].timer!.fade, const Duration(minutes: 10));
      expect(loaded[2].timer, isNull);
      expect(loaded[3].timer, isNotNull);
      expect(loaded[3].timer!.duration, isNull);
    },
  );

  test('older and malformed optional timer fields fall back without losing the mix', () {
    expect(SoundMix.fromJson(original.toJson()).timer, isNull);
    for (final timer in [
      'invalid',
      {'durationMilliseconds': -1, 'fadeMilliseconds': 0},
      {'durationMilliseconds': 60000, 'fadeMilliseconds': 120000},
      {'durationMilliseconds': null, 'fadeMilliseconds': 1000},
    ]) {
      final loaded = SoundMix.fromJson({...original.toJson(), 'timer': timer});
      expect(loaded.id, original.id);
      expect(loaded.sounds, original.sounds);
      expect(loaded.timer, isNull);
    }
  });
}
