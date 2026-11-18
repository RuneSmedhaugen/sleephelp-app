import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t(L.nightSounds))),
      body: Center(
        child: Text(context.t(L.settleIn), style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
