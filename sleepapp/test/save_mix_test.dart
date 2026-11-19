import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sleepapp/l10n/rest_strings.dart';
import 'package:sleepapp/widgets/mix_name_dialog.dart';

void main() {
  testWidgets('saving a new mix can opt into remembering its timer', (
    tester,
  ) async {
    var remembered = false;
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          RestStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => MixNameDialog(
                    initialName: 'Night mix',
                    onRememberTimerChanged: (value) => remembered = value,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(remembered, isFalse);
    await tester.tap(find.text('Remember timer and fade'));
    await tester.pumpAndSettle();
    expect(remembered, isTrue);
    await tester.tap(find.text('Save mix'));
    await tester.pumpAndSettle();
    expect(result, 'Night mix');
    expect(tester.takeException(), isNull);
  });
  for (final action in ['save', 'submit', 'cancel', 'dismiss']) {
    testWidgets('mix name dialog closes safely with $action', (tester) async {
      String? result;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [
            RestStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        const MixNameDialog(initialName: 'Night mix'),
                  );
                  closed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Night mix'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Evening birds');
      if (action == 'submit') {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else if (action == 'dismiss') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text(action == 'save' ? 'Save mix' : 'Cancel'));
      }
      await tester.pump();
      expect(closed, isTrue);
      expect(
        result,
        action == 'save' || action == 'submit' ? 'Evening birds' : null,
      );
      // The field must stay valid until the closing animation removes it.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(MixNameDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(MixNameDialog), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Night mix'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
