import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';
import '../models/sound.dart';
import '../widgets/sound_icon.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.sounds,
    required this.selectedSounds,
    required this.onToggleSound,
    required this.onImport,
  });

  final List<Sound> sounds;
  final Set<String> selectedSounds;
  final ValueChanged<Sound> onToggleSound;
  final Future<bool> Function() onImport;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  static const _categories = [
    'All',
    if (!kIsWeb) Sound.importedCategory,
    'Nature',
    'Water',
    'Warmth',
    'Ambient',
  ];
  final _searchController = TextEditingController();
  String _category = 'All';
  bool _importing = false;

  Future<void> _importSound() async {
    setState(() => _importing = true);
    try {
      if (await widget.onImport() && mounted) {
        _searchController.clear();
        setState(() => _category = Sound.importedCategory);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final visibleSounds = widget.sounds.where((sound) {
      final matchesCategory = _category == 'All' || sound.category == _category;
      final matchesQuery =
          query.isEmpty || sound.name.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Find your calm',
                        style: TextStyle(
                          color: style.text,
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                    if (!kIsWeb)
                      TextButton.icon(
                        onPressed: _importing ? null : _importSound,
                        icon: _importing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('Import'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Layer a few sounds together to make your own.',
                  style: TextStyle(color: style.quaternary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search sounds',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: style.panel,
                    hintStyle: TextStyle(color: style.quaternary),
                    prefixIconColor: style.quaternary,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 37,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final selected = _category == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = category),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: selected ? style.text : style.quaternary,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        backgroundColor: style.panel,
                        selectedColor: style.tint(style.primary, 0.22),
                        side: BorderSide(
                          color: selected
                              ? style.primary.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.045),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${visibleSounds.length} sounds',
                      style: TextStyle(color: style.quaternary, fontSize: 12),
                    ),
                    const Spacer(),
                    if (widget.selectedSounds.isNotEmpty)
                      Text(
                        '${widget.selectedSounds.length} in your mix',
                        style: TextStyle(color: style.primary, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visibleSounds.isEmpty
                ? Center(
                    child: Text(
                      _category == Sound.importedCategory && query.isEmpty
                          ? 'Use Import to add your own sounds.'
                          : 'No sounds match that search.',
                      style: TextStyle(color: style.quaternary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 170,
                        ),
                    itemCount: visibleSounds.length,
                    itemBuilder: (context, index) {
                      final sound = visibleSounds[index];
                      final selected = widget.selectedSounds.contains(
                        sound.file,
                      );
                      return _SoundCard(
                        sound: sound,
                        selected: selected,
                        onTap: () => widget.onToggleSound(sound),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.sound,
    required this.selected,
    required this.onTap,
  });

  final Sound sound;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = RestStyle.of(context);
    final accent = style.layerAccent(sound.category);
    return Material(
      color: style.panel,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [style.tint(accent, selected ? 0.20 : 0.11), style.panel],
            ),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.55) : style.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SoundIcon(sound: sound, size: 52),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? accent : style.raised,
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.add_rounded,
                      size: 17,
                      color: selected ? style.onAccent : style.text,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                sound.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: style.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selected ? 'Added to your mix' : sound.category,
                style: TextStyle(
                  color: selected ? accent : style.quaternary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
