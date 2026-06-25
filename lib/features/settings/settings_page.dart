import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/pebble_theme.dart';

class SettingsPage extends StatelessWidget {
  final PebbleThemeId themeId;
  final ValueChanged<PebbleThemeId> onThemeChange;
  final Color defaultAccent;
  final ValueChanged<Color> onAccentChange;
  const SettingsPage({
    super.key,
    required this.themeId,
    required this.onThemeChange,
    required this.defaultAccent,
    required this.onAccentChange,
  });

  bool get _showAccentPicker =>
      themeId == PebbleThemeId.defaultTheme ||
      themeId == PebbleThemeId.amoled ||
      themeId == PebbleThemeId.glassmorphic ||
      themeId == PebbleThemeId.liquidGlass ||
      themeId == PebbleThemeId.normal;

  List<PebbleThemeId> get _themes => const [
        PebbleThemeId.defaultTheme,
        PebbleThemeId.amoled,
        PebbleThemeId.glassmorphic,
        PebbleThemeId.liquidGlass,
        PebbleThemeId.normal,
        PebbleThemeId.gruvbox,
        PebbleThemeId.everforest,
        PebbleThemeId.nord,
        PebbleThemeId.tokyoNight,
        PebbleThemeId.catppuccin,
      ];

  String _themeDescription(PebbleThemeId id) {
    return switch (id) {
      PebbleThemeId.defaultTheme => 'Seeded accent + pick your color',
      PebbleThemeId.amoled => 'Pure black + glass panels + pick your color',
      PebbleThemeId.glassmorphic => 'Glass effect with strong borders + pick your color',
      PebbleThemeId.liquidGlass => 'High blur liquid effect + pick your color',
      PebbleThemeId.normal => 'Standard dark theme + pick your color',
      _ => 'Fixed palette',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Colors.primaries;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(),

          const SizedBox(height: 32),

          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          DropdownMenu<PebbleThemeId>(
            initialSelection: themeId,
            onSelected: (v) {
              if (v != null) onThemeChange(v);
            },
            dropdownMenuEntries: _themes
                .map(
                  (t) => DropdownMenuEntry<PebbleThemeId>(
                    value: t,
                    label: t.label,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _themeDescription(themeId),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),

          if (_showAccentPicker) ...[
            const SizedBox(height: 16),
            Text(
              'Accent Color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: colors.map((c) {
                final selected = c.toARGB32() == defaultAccent.toARGB32();
                return GestureDetector(
                  onTap: () => onAccentChange(c),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? accent.withValues(alpha: 0.9)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(radius: 18, backgroundColor: c),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),

          Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pebble',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Minimal calendar-based todo app',
                  style: TextStyle(color: Colors.white54),
                ),

                const SizedBox(height: 16),

                Row(
                  children: const [
                    Icon(Icons.code),
                    SizedBox(width: 8),
                    Text('Source code'),
                  ],
                ),

                const SizedBox(height: 6),
                const Text(
                  'github.com/Grey-007/pebble',
                  style: TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Made by Grey-007',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}
