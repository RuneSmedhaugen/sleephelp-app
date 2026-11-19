import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sleepapp/l10n/rest_strings.dart';
import 'package:sleepapp/models/sound.dart';
import 'package:sleepapp/models/sound_mix.dart';
import 'package:sleepapp/screens/saved_mixes_view.dart';
import 'package:sleepapp/widgets/mix_editor_sheet.dart';

const _sounds = [
  Sound(
    file: 'birds.mp3',
    name: 'Birds',
    category: 'Nature',
    icon: Icons.forest,
  ),
  Sound(file: 'ocean.mp3', name: 'Ocean', category: 'Water', icon: Icons.waves),
];

SoundMix _mix() => SoundMix(
  id: 'scheduled-mix',
  name: 'Evening',
  sounds: ['birds.mp3'],
  volumes: {'birds.mp3': 0.4},
  updatedAt: DateTime(2026, 11, 18),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find
        .descendant(
          of: find.byType(MixEditorSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditor(
  WidgetTester tester,
  SoundMix mix,
  Future<bool> Function(SoundMix, bool) save, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: RestStrings.supportedLocales,
      localizationsDelegates: [
        RestStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) =>
                  MixEditorSheet(mix: mix, sounds: _sounds, onSave: save),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('remembered timer can be configured and removed', (tester) async {
    SoundMix? saved;
    Future<bool> save(SoundMix draft, bool _) async {
      saved = draft;
      return true;
    }

    await _openEditor(tester, _mix(), save);
    await tester.tap(find.text('Remember timer and fade'));
    await tester.pumpAndSettle();
    final duration = find.byKey(const ValueKey('mix-duration-45'));
    await _scrollTo(tester, duration);
    tester.widget<DropdownButtonFormField<int>>(duration).onChanged!(480);
    await tester.pumpAndSettle();
    final fade = find.byKey(const ValueKey('mix-fade-5'));
    await _scrollTo(tester, fade);
    tester.widget<DropdownButtonFormField<int>>(fade).onChanged!(10);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Update mix'));
    await tester.tap(find.text('Update mix'));
    await tester.pumpAndSettle();
    expect(saved!.timer!.duration, const Duration(hours: 8));
    expect(saved!.timer!.fade, const Duration(minutes: 10));

    final timed = saved!;
    await _openEditor(tester, timed, save);
    await tester.tap(find.text('Remember timer and fade'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Update mix'));
    await tester.tap(find.text('Update mix'));
    await tester.pumpAndSettle();
    expect(saved!.timer, isNull);
    expect(timed.timer!.duration, const Duration(hours: 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving timer off clears a previous fade', (tester) async {
    SoundMix? saved;
    await _openEditor(
      tester,
      _mix().copyWith(
        timer: const MixTimerSettings(
          duration: Duration(minutes: 45),
          fade: Duration(minutes: 10),
        ),
      ),
      (draft, _) async {
        saved = draft;
        return true;
      },
    );
    final duration = find.byKey(const ValueKey('mix-duration-45'));
    await _scrollTo(tester, duration);
    tester.widget<DropdownButtonFormField<int>>(duration).onChanged!(0);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Update mix'));
    await tester.tap(find.text('Update mix'));
    await tester.pumpAndSettle();
    expect(saved!.timer, isNotNull);
    expect(saved!.timer!.duration, isNull);
    expect(saved!.timer!.fade, Duration.zero);
  });

  for (final saveAsNew in [false, true]) {
    testWidgets('edit sounds, name and volume, then save as new = $saveAsNew', (
      tester,
    ) async {
      final original = _mix();
      SoundMix? saved;
      bool? copied;
      await _openEditor(tester, original, (draft, asNew) async {
        saved = draft;
        copied = asNew;
        return true;
      });
      await tester.enterText(find.byType(EditableText), 'Ocean at night');
      await tester.tap(find.byTooltip('Remove Birds'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.text('Add sounds'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Ocean');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocean', findRichText: false).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(0.25);
      await tester.pump();
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);
      final button = find.text(saveAsNew ? 'Save as new mix' : 'Update mix');
      await _scrollTo(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(saved!.id, original.id);
      expect(saved!.name, 'Ocean at night');
      expect(saved!.sounds, ['ocean.mp3']);
      expect(saved!.volumes, {'ocean.mp3': 0.25});
      expect(copied, saveAsNew);
      expect(original.name, 'Evening');
      expect(original.sounds, ['birds.mp3']);
      expect(original.volumes, {'birds.mp3': 0.4});
      expect(find.byType(MixEditorSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancel discards changes and reopening uses the saved mix', (
    tester,
  ) async {
    var writes = 0;
    await _openEditor(tester, _mix(), (_, _) async {
      writes++;
      return true;
    });
    await tester.enterText(find.byType(EditableText), 'Discard this');
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.8);
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Evening'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed saves retain the draft and allow a retry', (
    tester,
  ) async {
    var writes = 0;
    await _openEditor(tester, _mix(), (_, _) async => ++writes > 1);
    await tester.enterText(find.byType(EditableText), 'Retry');
    await tester.pump();
    await _scrollTo(tester, find.text('Update mix'));
    await tester.tap(find.text('Update mix'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.byType(MixEditorSheet), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text(const RestStrings(Locale('en')).text(L.mixSaveError)),
      findsOneWidget,
    );
    await tester.tap(find.text('Update mix'));
    await tester.pumpAndSettle();
    expect(writes, 2);
    expect(find.byType(MixEditorSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty mixes cannot be saved', (tester) async {
    await _openEditor(tester, _mix(), (_, _) async => true);
    await tester.tap(find.byTooltip('Remove Birds'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Update mix'));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Update mix'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Save as new mix'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'unavailable imported sounds are retained until explicitly removed',
    (tester) async {
      SoundMix? saved;
      final mix = _mix().copyWith(
        sounds: ['birds.mp3', 'imported/missing'],
        volumes: {'birds.mp3': 0.4, 'imported/missing': 0.3},
      );
      await _openEditor(tester, mix, (draft, _) async {
        saved = draft;
        return true;
      });
      await tester.enterText(find.byType(EditableText), 'Keep imported layer');
      await tester.pump();
      await _scrollTo(tester, find.text('Update mix'));
      await tester.tap(find.text('Update mix'));
      await tester.pumpAndSettle();
      expect(saved!.sounds, ['birds.mp3', 'imported/missing']);
      expect(saved!.volumes['imported/missing'], 0.3);
    },
  );

  testWidgets('saved mix menu routes each action to the selected mix', (
    tester,
  ) async {
    final mix = _mix();
    final calls = <String>[];
    void record(String action, SoundMix selected) {
      expect(identical(selected, mix), isTrue);
      calls.add(action);
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          RestStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: SavedMixesView(
            mixes: [mix],
            sounds: _sounds,
            onLoad: (mix) => record('load', mix),
            onEdit: (mix) => record('Edit mix', mix),
            onRename: (mix) => record('Rename', mix),
            onDuplicate: (mix) => record('Duplicate', mix),
            onDelete: (mix) => record('Delete', mix),
            onBrowse: () {},
            onRotation: () {},
            rotationSummary: '',
          ),
        ),
      ),
    );
    for (final action in ['Edit mix', 'Rename', 'Duplicate', 'Delete']) {
      await tester.tap(find.byTooltip('Actions for Evening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(calls.last, action);
    }
    expect(calls, ['Edit mix', 'Rename', 'Duplicate', 'Delete']);
    expect(tester.takeException(), isNull);
  });

  for (final locale in RestStrings.supportedLocales) {
    testWidgets('editor fits a small screen in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openEditor(tester, _mix(), (_, _) async => true, locale: locale);
      final strings = RestStrings(locale);
      await _scrollTo(tester, find.text(strings.text(L.saveAsNewMix)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(strings.text(L.cancel)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
