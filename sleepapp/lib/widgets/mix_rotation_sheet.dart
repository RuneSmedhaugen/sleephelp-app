import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/mix_rotation.dart';
import '../models/sound_mix.dart';

class MixRotationSheet extends StatefulWidget {
  const MixRotationSheet({
    super.key,
    required this.rotation,
    required this.mixes,
  });

  final MixRotation rotation;
  final List<SoundMix> mixes;

  @override
  State<MixRotationSheet> createState() => _MixRotationSheetState();
}

class _MixRotationSheetState extends State<MixRotationSheet> {
  static const _weekdays = [
    L.monday,
    L.tuesday,
    L.wednesday,
    L.thursday,
    L.friday,
    L.saturday,
    L.sunday,
  ];
  late MixRotation _draft = widget.rotation;

  void _changeSlot(int index, String? id) {
    final daily = _draft.mode == MixRotationMode.daily;
    final slots = [...(daily ? _draft.days : _draft.weeks)]..[index] = id;
    setState(() {
      _draft = daily
          ? _draft.copyWith(days: slots)
          : _draft.copyWith(weeks: slots);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daily = _draft.mode == MixRotationMode.daily;
    final weekly = _draft.mode == MixRotationMode.weekly;
    final slots = daily ? _draft.days : _draft.weeks;
    final currentSlot = daily ? now.weekday - 1 : _draft.weekIndex(now);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t(L.mixRotation),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<MixRotationMode>(
                segments: [
                  for (final mode in MixRotationMode.values)
                    ButtonSegment(
                      value: mode,
                      label: Text(
                        context.t(switch (mode) {
                          MixRotationMode.off => L.off,
                          MixRotationMode.daily => L.daily,
                          MixRotationMode.weekly => L.weekly,
                        }),
                      ),
                    ),
                ],
                selected: {_draft.mode},
                showSelectedIcon: false,
                onSelectionChanged: (selected) => setState(
                  () => _draft = _draft.copyWith(mode: selected.single),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    Text(switch (_draft.mode) {
                      MixRotationMode.off => context.t(L.rotationOff),
                      MixRotationMode.daily => context.t(L.rotationDaily),
                      MixRotationMode.weekly => context.t(L.rotationWeekly),
                    }),
                    if (daily || weekly) ...[
                      const SizedBox(height: 6),
                      Text(context.t(L.rotationEmpty)),
                      const SizedBox(height: 12),
                      for (var index = 0; index < slots.length; index++)
                        _slot(
                          context,
                          index,
                          daily
                              ? context.t(_weekdays[index])
                              : context.t(L.week, [index + 1]),
                          slots[index],
                          current: index == currentSlot,
                          removable: weekly && slots.length > 1,
                        ),
                    ],
                    if (weekly)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _draft = _draft.copyWith(
                              weeks: [...slots, null],
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(context.t(L.addWeek)),
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () {
                  final rotation = weekly && _draft.firstMonday == null
                      ? _draft.copyWith(
                          firstMonday: MixRotation.mondayOf(DateTime.now()),
                        )
                      : _draft;
                  Navigator.pop(context, rotation);
                },
                child: Text(context.t(L.saveRotation)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(
    BuildContext context,
    int index,
    String label,
    String? id, {
    required bool current,
    required bool removable,
  }) {
    final mixExists = widget.mixes.any((mix) => mix.id == id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: current ? context.t(L.currentSlot, [label]) : label,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: mixExists ? id : '',
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.t(L.unassigned)),
                    ),
                    for (final mix in widget.mixes)
                      DropdownMenuItem(
                        value: mix.id,
                        child: Text(
                          mix.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      _changeSlot(index, value == '' ? null : value),
                ),
              ),
            ),
          ),
          if (removable)
            IconButton(
              tooltip: context.t(L.removeNamed, [label]),
              onPressed: () => setState(
                () => _draft = _draft.copyWith(
                  weeks: [..._draft.weeks]..removeAt(index),
                ),
              ),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
        ],
      ),
    );
  }
}
