import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/rest_strings.dart';
import '../models/sound.dart';
import '../models/sound_mix.dart';
import '../screens/library_view.dart';
import 'sound_layer_card.dart';
import 'sleep_plan_text.dart';
import 'sleep_timer_sheet.dart';

class MixEditorSheet extends StatefulWidget {
  const MixEditorSheet({
    super.key,
    required this.mix,
    required this.sounds,
    required this.onSave,
    this.suggestedTimer,
    this.onSoundToggle,
    this.onVolumeChanged,
    this.isSavedMix = true,
    this.originalMix,
  });

  final SoundMix mix;
  final List<Sound> sounds;
  final Future<bool> Function(SoundMix draft, bool saveAsNew) onSave;
  final MixTimerSettings? suggestedTimer;
  final Future<bool> Function(Sound)? onSoundToggle;
  final Future<double> Function(String, double)? onVolumeChanged;
  final bool isSavedMix;
  final SoundMix? originalMix;

  @override
  State<MixEditorSheet> createState() => _MixEditorSheetState();
}

class _MixEditorSheetState extends State<MixEditorSheet> {
  late final _name = TextEditingController(text: widget.mix.name);
  late final _selected = widget.mix.sounds.toSet();
  late final _volumes = Map<String, double>.of(widget.mix.volumes);
  late final _initialTimer =
      widget.mix.timer ??
      widget.suggestedTimer ??
      const MixTimerSettings(
        duration: Duration(minutes: 45),
        fade: Duration(minutes: 5),
      );
  late bool _rememberTimer = widget.mix.timer != null;
  late int _timerMinutes = _initialTimer.duration?.inMinutes ?? 0;
  late int _fadeMinutes = _initialTimer.fade.inMinutes;
  bool _saving = false;
  bool _failed = false;
  final Set<String> _changingSounds = {};

  SoundMix get _original => widget.originalMix ?? widget.mix;

  bool get _changed =>
      (!widget.isSavedMix && _selected.isNotEmpty) ||
      _name.text.trim() != _original.name ||
      _rememberTimer != (_original.timer != null) ||
      (_rememberTimer &&
          (_timerMinutes != (_original.timer?.duration?.inMinutes ?? 0) ||
              _fadeMinutes != (_original.timer?.fade.inMinutes ?? 0))) ||
      !setEquals(_selected, _original.sounds.toSet()) ||
      _selected.any(
        (file) => (_volumes[file] ?? 1) != (_original.volumes[file] ?? 1),
      );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _toggleSound(Sound sound) async {
    if (_changingSounds.contains(sound.file)) return;
    setState(() => _changingSounds.add(sound.file));
    final liveToggle = widget.onSoundToggle;
    try {
      if (liveToggle != null) {
        final selected = await liveToggle(sound);
        if (!mounted) return;
        setState(() {
          if (selected) {
            _selected.add(sound.file);
            _volumes.putIfAbsent(sound.file, () => 1);
          } else {
            _selected.remove(sound.file);
          }
        });
        return;
      }
      setState(() {
        if (!_selected.remove(sound.file)) {
          _selected.add(sound.file);
          _volumes.putIfAbsent(sound.file, () => 1);
        }
      });
    } finally {
      if (mounted) setState(() => _changingSounds.remove(sound.file));
    }
  }

  Future<void> _changeVolume(String file, double value) async {
    setState(() => _volumes[file] = value);
    final change = widget.onVolumeChanged;
    if (change == null) return;
    final actual = await change(file, value);
    if (mounted) setState(() => _volumes[file] = actual);
  }

  Future<void> _addSounds() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (pickerContext) => SizedBox(
      height: MediaQuery.sizeOf(pickerContext).height * 0.92,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(pickerContext),
              child: Text(pickerContext.t(L.done)),
            ),
          ),
          Expanded(
            child: StatefulBuilder(
              builder: (context, updatePicker) => LibraryView(
                sounds: widget.sounds,
                selectedSounds: _selected,
                onToggleSound: (sound) async {
                  await _toggleSound(sound);
                  if (context.mounted) updatePicker(() {});
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _save(bool saveAsNew) async {
    if (_saving ||
        _changingSounds.isNotEmpty ||
        _selected.isEmpty ||
        _name.text.trim().isEmpty)
      return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    var saved = false;
    try {
      saved = await widget.onSave(
        widget.mix.copyWith(
          name: _name.text.trim(),
          sounds: _selected.toList(),
          volumes: {for (final file in _selected) file: _volumes[file] ?? 1},
          updatedAt: DateTime.now(),
          timer: _rememberTimer
              ? MixTimerSettings(
                  duration: _timerMinutes == 0
                      ? null
                      : Duration(minutes: _timerMinutes),
                  fade: Duration(minutes: _fadeMinutes),
                )
              : null,
          clearTimer: !_rememberTimer,
        ),
        saveAsNew,
      );
    } catch (error) {
      debugPrint('Could not save edited mix: $error');
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !saved;
    });
    if (saved) Navigator.pop(context);
  }

  Sound _sound(String file) => widget.sounds.firstWhere(
    (sound) => sound.file == file,
    orElse: () => Sound(
      file: file,
      name: context.t(L.unavailableSound),
      category: 'Ambient',
      icon: Icons.audio_file_outlined,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final valid = _selected.isNotEmpty && _name.text.trim().isNotEmpty;
    return PopScope(
      canPop: !_saving,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              8,
              22,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t(L.editMix),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t(
                        widget.onSoundToggle == null ? L.cancel : L.done,
                      ),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.t(L.mixSaveError),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(
                        context.t(
                          widget.onSoundToggle == null
                              ? L.mixEditHint
                              : L.liveMixHint,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        enabled: !_saving,
                        maxLength: 32,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: context.t(L.mixName),
                        ),
                      ),
                      if (_changed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(context.t(L.unsavedChanges)),
                        ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _addSounds,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.t(L.addSounds)),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.t(L.rememberMixTimer)),
                        subtitle: Text(context.t(L.mixTimerHint)),
                        value: _rememberTimer,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _rememberTimer = value),
                      ),
                      if (_rememberTimer) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          key: ValueKey('mix-duration-$_timerMinutes'),
                          initialValue: _timerMinutes,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.t(L.playFor),
                          ),
                          items: [
                            for (final minutes in ({
                              0,
                              ...sleepTimerMinutes,
                              _timerMinutes,
                            }.toList()..sort()))
                              DropdownMenuItem(
                                value: minutes,
                                child: Text(
                                  minutes == 0
                                      ? context.t(L.noSleepTimer)
                                      : formatSleepDuration(
                                          context,
                                          Duration(minutes: minutes),
                                        ),
                                ),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (minutes) => setState(() {
                                  _timerMinutes = minutes!;
                                  _fadeMinutes = _fadeMinutes
                                      .clamp(0, _timerMinutes)
                                      .toInt();
                                }),
                        ),
                        if (_timerMinutes > 0) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey('mix-fade-$_fadeMinutes'),
                            initialValue: _fadeMinutes,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.t(L.fadeOver),
                            ),
                            items: [
                              for (final minutes
                                  in ({...sleepFadeMinutes, _fadeMinutes}
                                      .where((value) => value <= _timerMinutes)
                                      .toList()
                                    ..sort()))
                                DropdownMenuItem(
                                  value: minutes,
                                  child: Text(
                                    minutes == 0
                                        ? context.t(L.noFade)
                                        : formatSleepDuration(
                                            context,
                                            Duration(minutes: minutes),
                                          ),
                                  ),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (minutes) =>
                                      setState(() => _fadeMinutes = minutes!),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (_selected.isEmpty) Text(context.t(L.addBeforeSave)),
                      AbsorbPointer(
                        absorbing: _saving,
                        child: Column(
                          children: [
                            for (final file in _selected)
                              SoundLayerCard(
                                key: ValueKey(file),
                                sound: _sound(file),
                                volume: _volumes[file] ?? 1,
                                onVolumeChanged: (value) =>
                                    _changeVolume(file, value),
                                onRemove: () => _toggleSound(_sound(file)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.isSavedMix)
                        FilledButton(
                          onPressed:
                              !valid ||
                                  _saving ||
                                  _changingSounds.isNotEmpty ||
                                  !_changed
                              ? null
                              : () => _save(false),
                          child: Text(
                            context.t(_saving ? L.saving : L.updateMix),
                          ),
                        ),
                      TextButton(
                        onPressed:
                            !valid || _saving || _changingSounds.isNotEmpty
                            ? null
                            : () => _save(true),
                        child: Text(
                          context.t(
                            widget.isSavedMix ? L.saveAsNewMix : L.saveMix,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
