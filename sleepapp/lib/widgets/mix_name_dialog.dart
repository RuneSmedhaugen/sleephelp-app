import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';

class MixNameDialog extends StatefulWidget {
  const MixNameDialog({
    super.key,
    required this.initialName,
    this.title = L.nameMix,
    this.confirmLabel = L.saveMix,
    this.onRememberTimerChanged,
  });

  final String initialName;
  final L title;
  final L confirmLabel;
  final ValueChanged<bool>? onRememberTimerChanged;

  @override
  State<MixNameDialog> createState() => _MixNameDialogState();
}

class _MixNameDialogState extends State<MixNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  bool _rememberTimer = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.t(widget.title)),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 32,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: context.t(L.nameHint)),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          if (widget.onRememberTimerChanged != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t(L.rememberMixTimer)),
              subtitle: Text(context.t(L.saveMixTimerHint)),
              value: _rememberTimer,
              onChanged: (value) {
                setState(() => _rememberTimer = value);
                widget.onRememberTimerChanged!(value);
              },
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t(L.cancel)),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(context.t(widget.confirmLabel)),
      ),
    ],
  );
}
