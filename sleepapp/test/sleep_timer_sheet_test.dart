import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sleepapp/l10n/rest_strings.dart';
import 'package:sleepapp/models/wake_playback.dart';
import 'package:sleepapp/widgets/sleep_timer_sheet.dart';

void main() {
  for (final (duration, fade) in [(480, 10), (80, 17)]) {
    testWidgets(
      'opening the timer preserves $duration minutes and $fade minutes of fade',
      (tester) async {
        Duration? savedDuration;
        Duration? savedFade;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: [
              RestStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: SleepTimerSheet(
                regularDuration: Duration(minutes: duration),
                regularFade: Duration(minutes: fade),
                preview: (duration, fade) => SleepPlan(
                  stopAt: DateTime.now().add(duration),
                  playFor: duration,
                  fade: fade,
                ),
                onStart: (duration, fade) async {
                  savedDuration = duration;
                  savedFade = fade;
                },
                onCancel: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Set sleep timer'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set sleep timer'));
        await tester.pumpAndSettle();
        expect(savedDuration, Duration(minutes: duration));
        expect(savedFade, Duration(minutes: fade));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
