import 'package:flutter/material.dart';

import '../models/sound.dart';
import '../widgets/sound_icon.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.sounds,
    required this.selectedSounds,
    required this.onToggleSound,
  });

  final List<Sound> sounds;
  final Set<String> selectedSounds;
  final ValueChanged<Sound> onToggleSound;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  static const _categories = ['All', 'Nature', 'Water', 'Warmth', 'Ambient'];
  final _searchController = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Find your calm',
                  style: TextStyle(
                    color: Color(0xFFF1F2F7),
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Layer a few sounds together to make your own.',
                  style: TextStyle(color: Color(0xFF929DB2), fontSize: 13),
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
                    fillColor: const Color(0xFF171D2D),
                    hintStyle: const TextStyle(color: Color(0xFF7F8BA1)),
                    prefixIconColor: const Color(0xFF98A3B8),
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
                          color: selected
                              ? const Color(0xFFEAE7FF)
                              : const Color(0xFF9BA5B8),
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        backgroundColor: const Color(0xFF171D2D),
                        selectedColor: const Color(0xFF34304E),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF7569A9).withValues(alpha: 0.55)
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
                      style: const TextStyle(
                        color: Color(0xFF8792A8),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (widget.selectedSounds.isNotEmpty)
                      Text(
                        '${widget.selectedSounds.length} in your mix',
                        style: const TextStyle(
                          color: Color(0xFFB7ACEF),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visibleSounds.isEmpty
                ? const Center(
                    child: Text(
                      'No sounds match that search.',
                      style: TextStyle(color: Color(0xFF929DB2)),
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
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF171D2D),
    borderRadius: BorderRadius.circular(21),
    child: InkWell(
      borderRadius: BorderRadius.circular(21),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: selected
                ? const Color(0xFF9E91D6).withValues(alpha: 0.52)
                : Colors.white.withValues(alpha: 0.055),
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
                    color: selected
                        ? const Color(0xFFB4A8EC)
                        : const Color(0xFF252D40),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 17,
                    color: selected
                        ? const Color(0xFF151728)
                        : const Color(0xFFB2BACC),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              sound.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF0F2F6),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selected ? 'Added to your mix' : sound.category,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFB7ACEF)
                    : const Color(0xFF929DB2),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
