import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:window_manager/window_manager.dart';

import 'data/todo_db.dart';
import 'features/calendar/calendar_page.dart';
import 'features/timer/timer_page.dart';
import 'features/timeline/timeline_page.dart';
import 'features/kanban/kanban_page.dart';
import 'features/insights/insights_page.dart';
import 'features/settings/settings_page.dart';
import 'services/notification_service.dart';
import 'theme/avelo_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureWindow();
  await TodoDB.instance.init();

  final savedTheme = await TodoDB.instance.getSetting('theme');
  final savedAccent = await TodoDB.instance.getSetting('accent');

  final themeId = savedTheme == null
      ? AveloThemeId.defaultTheme
      : AveloThemeId.fromId(savedTheme);

  final accent = savedAccent == null
      ? const Color(0xFF1DB954)
      : Color(int.tryParse(savedAccent) ?? 0xFF1DB954);

  runApp(AveloApp(initialThemeId: themeId, initialAccent: accent));
}

Future<void> _configureWindow() async {
  if (kIsWeb) return;
  if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return;

  await windowManager.ensureInitialized();
  const options = WindowOptions(titleBarStyle: TitleBarStyle.hidden);
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

class AveloApp extends StatefulWidget {
  final AveloThemeId initialThemeId;
  final Color initialAccent;
  const AveloApp({
    super.key,
    required this.initialThemeId,
    required this.initialAccent,
  });

  @override
  State<AveloApp> createState() => _AveloAppState();
}

class _AveloAppState extends State<AveloApp> {
  late Color accent;
  late AveloThemeId themeId;
  Timer? _reminderTimer;
  final Set<int> _notifiedTodoIds = {};

  @override
  void initState() {
    super.initState();
    accent = widget.initialAccent;
    themeId = widget.initialThemeId;
    _startReminderService();
  }

  void _startReminderService() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final now = DateTime.now();
      final dateStr = now.toIso8601String().split('T')[0];
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final todos = await TodoDB.instance.getTodos(dateStr);
      for (final todo in todos) {
        final rTime = todo['reminder_time'] as String?;
        final isDone = (todo['done'] as int) == 1;
        final id = todo['id'] as int;
        
        if (!isDone && rTime == timeStr && !_notifiedTodoIds.contains(id)) {
          _notifiedTodoIds.add(id);
          await NotificationService.show(
            'Reminder: ${todo['text']}',
            'It is time for your scheduled task!',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AveloThemes.build(themeId: themeId, defaultAccent: accent),
      home: AppShell(
        themeId: themeId,
        onThemeChange: (t) {
          setState(() => themeId = t);
          unawaited(TodoDB.instance.setSetting('theme', t.id));
        },
        defaultAccent: accent,
        onAccentChange: (c) {
          setState(() => accent = c);
          unawaited(TodoDB.instance.setSetting('accent', c.toARGB32().toString()));
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final AveloThemeId themeId;
  final ValueChanged<AveloThemeId> onThemeChange;
  final Color defaultAccent;
  final ValueChanged<Color> onAccentChange;
  const AppShell({
    super.key,
    required this.themeId,
    required this.onThemeChange,
    required this.defaultAccent,
    required this.onAccentChange,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final pages = [
      CalendarPage(
        selectedDate: selectedDate,
        onDateSelected: (d) => setState(() => selectedDate = d),
      ),
      const _ContentShell(child: TimerPage()),
      const _ContentShell(child: TimelinePage()),
      const _ContentShell(child: KanbanPage()),
      const _ContentShell(child: InsightsPage()),
      _ContentShell(
        child: SettingsPage(
          themeId: widget.themeId,
          onThemeChange: widget.onThemeChange,
          defaultAccent: widget.defaultAccent,
          onAccentChange: widget.onAccentChange,
        ),
      ),
    ];

    final glass = AveloTheme.of(context).glass;

    return Scaffold(
      body: Stack(
        children: [
          if (glass)
            _AmoledBackdrop(accent: Theme.of(context).colorScheme.primary),
          Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: focusModeNotifier,
                builder: (context, focus, child) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                    width: focus ? 0 : 72,
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: 72,
                      alignment: Alignment.centerLeft,
                      child: child,
                    ),
                  );
                },
                child: _SideNav(
                  selectedIndex: index,
                  onSelect: (i) => setState(() => index = i),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: pages[index],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmoledBackdrop extends StatelessWidget {
  final Color accent;
  const _AmoledBackdrop({required this.accent});

  @override
  Widget build(BuildContext context) {
    final c1 = accent.withValues(alpha: 0.16);
    final c2 = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          gradient: RadialGradient(
            center: const Alignment(-0.55, -0.6),
            radius: 1.2,
            colors: [c1, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.75, 0.7),
              radius: 1.3,
              colors: [c2, Colors.transparent],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Custom left sidebar with smooth animations
/// ─────────────────────────────────────────────
class _SideNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _SideNav({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final glass = AveloTheme.of(context).glass;

    final icons = [
      Icons.calendar_month, // Calendar
      Icons.timer, // Timer
      Icons.view_agenda, // Timeline
      Icons.view_kanban_outlined, // Kanban
      Icons.bar_chart, // Insights
      Icons.settings, // Settings
    ];

    const itemGap = 18.0;
    final items = <Widget>[];
    for (int i = 0; i < icons.length; i++) {
      items.add(
        _NavIcon(
          icon: icons[i],
          selected: selectedIndex == i,
          accent: accent,
          onTap: () => onSelect(i),
        ),
      );
      if (i != icons.length - 1) items.add(const SizedBox(height: itemGap));
    }

    final content = SizedBox(
      width: 72,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items,
        ),
      ),
    );

    final outerPadding = const EdgeInsets.fromLTRB(12, 12, 0, 18);

    if (glass) {
      return Padding(
        padding: outerPadding,
        child: AveloPanel(
          borderRadius: BorderRadius.circular(22),
          child: content,
        ),
      );
    }

    return Padding(
      padding: outerPadding,
      child: Container(
        width: 72,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15)),
        child: content,
      ),
    );
  }
}

class _NavIcon extends StatefulWidget {
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon>
    with SingleTickerProviderStateMixin {
  bool hover = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.forward();
    } else if (!widget.selected && oldWidget.selected) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? widget.accent
        : hover
        ? Colors.white
        : Colors.white54;

    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? widget.accent.withValues(alpha: 0.15)
                  : hover
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(widget.icon, size: 28, color: color),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Content wrapper with smooth animations
/// ─────────────────────────────────────────────
class _ContentShell extends StatelessWidget {
  final Widget child;
  const _ContentShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 18, 18),
          child: AveloPanel(child: child),
        )
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeInOutCubic)
        .slideX(begin: 0.03, duration: 600.ms, curve: Curves.easeInOutCubic);
  }
}
