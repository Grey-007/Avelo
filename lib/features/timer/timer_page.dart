import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/todo_db.dart';
import '../../services/notification_service.dart';

final ValueNotifier<bool> focusModeNotifier = ValueNotifier(false);

enum _TimerMode { work, breakTime }

class _TimerEngine extends ChangeNotifier {
  _TimerEngine._();
  static final _TimerEngine instance = _TimerEngine._();

  Timer? _ticker;
  _TimerMode mode = _TimerMode.work;
  bool running = false;
  bool autoCycle = true;
  int workMinutes = 25;
  int breakMinutes = 5;
  int remainingSeconds = 25 * 60;
  int _activeSessionSeconds = 25 * 60;
  int statsRevision = 0;
  bool _transitioning = false;
  int? linkedTaskId;

  void linkTask(int? taskId) {
    linkedTaskId = taskId;
    notifyListeners();
  }

  int get currentSessionTotalSeconds => _activeSessionSeconds;
  int get currentSessionElapsedSeconds =>
      (currentSessionTotalSeconds - remainingSeconds)
          .clamp(0, currentSessionTotalSeconds);
  bool get isWorkMode => mode == _TimerMode.work;
  bool get isBreakMode => mode == _TimerMode.breakTime;

  int _durationFor(_TimerMode m) =>
      (m == _TimerMode.work ? workMinutes : breakMinutes) * 60;
  String _dateKey(DateTime d) => d.toIso8601String().split('T')[0];

  void _spawnTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_transitioning || !running) return;
      if (remainingSeconds == 0) {
        NotificationService.show(
          'Timer Finished', 
          'Your ${mode == _TimerMode.work ? "Focus" : "Break"} session has completed.'
        );
        await _handleSessionFinished();
      } else {
        remainingSeconds -= 1;
        notifyListeners();
      }
    });
  }

  void start() {
    if (running) return;
    running = true;
    notifyListeners();
    _spawnTicker();
  }

  void pause() {
    running = false;
    _ticker?.cancel();
    notifyListeners();
  }

  void resetCurrent() {
    running = false;
    _ticker?.cancel();
    remainingSeconds = _durationFor(mode);
    _activeSessionSeconds = remainingSeconds;
    notifyListeners();
  }

  void switchMode(_TimerMode m) {
    running = false;
    _ticker?.cancel();
    mode = m;
    remainingSeconds = _durationFor(m);
    _activeSessionSeconds = remainingSeconds;
    notifyListeners();
  }

  void setAutoCycle(bool value) {
    autoCycle = value;
    notifyListeners();
  }

  void applySetup({required int work, required int brk}) {
    workMinutes = work <= 0 ? 25 : work;
    breakMinutes = brk <= 0 ? 5 : brk;
    resetCurrent();
  }

  Future<void> _sendSystemNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (Platform.isLinux) {
        await Process.run('notify-send', [title, body]);
        return;
      }
      if (Platform.isMacOS) {
        await Process.run('osascript', [
          '-e',
          'display notification "$body" with title "$title"',
        ]);
      }
    } catch (_) {}
  }

  Future<void> _handleSessionFinished() async {
    if (_transitioning) return;
    _transitioning = true;
    _ticker?.cancel();

    final finishedMode = mode;
    final finishedSeconds = _activeSessionSeconds;

    await TodoDB.instance.addTimerLog(
      date: _dateKey(DateTime.now()),
      type: finishedMode == _TimerMode.work ? 'work' : 'break',
      seconds: finishedSeconds,
      taskId: finishedMode == _TimerMode.work ? linkedTaskId : null,
    );
    statsRevision += 1;

    if (finishedMode == _TimerMode.work) {
      unawaited(
        _sendSystemNotification(
          title: 'Work session complete',
          body: autoCycle ? 'Break started.' : 'Start your break when ready.',
        ),
      );
    } else {
      unawaited(
        _sendSystemNotification(
          title: 'Break complete',
          body: autoCycle
              ? 'Work session started.'
              : 'Start your next session.',
        ),
      );
    }

    if (autoCycle) {
      mode = finishedMode == _TimerMode.work
          ? _TimerMode.breakTime
          : _TimerMode.work;
      remainingSeconds = _durationFor(mode);
      _activeSessionSeconds = remainingSeconds;
      running = true;
      _transitioning = false;
      notifyListeners();
      _spawnTicker();
      return;
    }

    running = false;
    remainingSeconds = _durationFor(finishedMode);
    _activeSessionSeconds = remainingSeconds;
    _transitioning = false;
    notifyListeners();
  }
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final _engine = _TimerEngine.instance;
  late final TextEditingController _workCtrl;
  late final TextEditingController _breakCtrl;
  int _lastStatsRevision = -1;
  late final ScrollController _scrollCtrl;
  final _statsKey = GlobalKey();
  bool _floatingStats = false;

  Map<String, int> _todayTotals = {'work': 0, 'break': 0, 'total': 0};
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _todayTasks = [];

  @override
  void initState() {
    super.initState();
    _workCtrl = TextEditingController(text: _engine.workMinutes.toString());
    _breakCtrl = TextEditingController(text: _engine.breakMinutes.toString());
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _engine.addListener(_onEngineTick);
    _loadStats();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final tasks = await TodoDB.instance.getTodos(today);
    if (!mounted) return;
    setState(() => _todayTasks = tasks);
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    _engine.removeListener(_onEngineTick);
    _workCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  void _onEngineTick() {
    if (!mounted) return;
    if (_engine.statsRevision != _lastStatsRevision) {
      _lastStatsRevision = _engine.statsRevision;
      unawaited(_loadStats());
    }
    setState(() {});
  }

  void _onScroll() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _statsKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) return;
      final dy = box.localToGlobal(Offset.zero).dy;
      final shouldFloat = dy <= 18;
      if (shouldFloat != _floatingStats) {
        setState(() => _floatingStats = shouldFloat);
      }
    });
  }

  int _safeMinutes(TextEditingController ctrl, int fallback) {
    final parsed = int.tryParse(ctrl.text.trim());
    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }

  String _formatClock(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    if (hrs == 0) return '${mins}m';
    return '${hrs}h ${mins}m';
  }

  String _displayDate(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    return '${parts[1]}/${parts[2]}';
  }

  String _modeLabel(_TimerMode mode) =>
      mode == _TimerMode.work ? 'Work/Study' : 'Break';

  Future<void> _loadStats() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final totals = await TodoDB.instance.getTimerTotalsForDate(today);
    final daily = await TodoDB.instance.getTimerDailyStats(limit: 14);
    if (!mounted) return;
    setState(() {
      _todayTotals = totals;
      _dailyStats = daily;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  Widget _timerHero({
    required Color accent,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Work/Study'),
                      selected: _engine.mode == _TimerMode.work,
                      onSelected: (_) => _engine.switchMode(_TimerMode.work),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Break'),
                      selected: _engine.mode == _TimerMode.breakTime,
                      onSelected: (_) =>
                          _engine.switchMode(_TimerMode.breakTime),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ValueListenableBuilder<bool>(
                valueListenable: focusModeNotifier,
                builder: (context, focus, _) {
                  return IconButton(
                    icon: Icon(focus ? Icons.fullscreen_exit : Icons.fullscreen),
                    color: Colors.white70,
                    tooltip: 'Focus Mode',
                    onPressed: () => focusModeNotifier.value = !focus,
                  );
                },
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: focusModeNotifier,
                    builder: (context, focus, _) {
                      return Text(
                        _formatClock(_engine.remainingSeconds),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: focus ? 180 : 116,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 0.8,
                          height: 0.9,
                        ),
                      ).animate(target: focus ? 1 : 0).scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.1, 1.1),
                        duration: 600.ms,
                        curve: Curves.easeInOutCubic,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _modeLabel(_engine.mode),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      letterSpacing: 0.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _workCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minutes',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _breakCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Break',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        iconSize: 40,
                        icon: Icon(
                          _engine.running ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: _engine.running ? _engine.pause : _engine.start,
                      ),
                      IconButton(
                        iconSize: 38,
                        icon: const Icon(Icons.refresh),
                        onPressed: _engine.resetCurrent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      _engine.applySetup(
                        work: _safeMinutes(_workCtrl, 25),
                        brk: _safeMinutes(_breakCtrl, 5),
                      );
                    },
                    child: const Text('Apply'),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto cycle'),
                      value: _engine.autoCycle,
                      onChanged: _engine.setAutoCycle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_todayTasks.isNotEmpty)
                    DropdownMenu<int?>(
                      initialSelection: _engine.linkedTaskId,
                      hintText: 'Link to task',
                      width: 240,
                      onSelected: (v) {
                        _engine.linkTask(v);
                        setState(() {});
                      },
                      dropdownMenuEntries: [
                        const DropdownMenuEntry<int?>(value: null, label: 'None'),
                        ..._todayTasks.map((t) => DropdownMenuEntry<int?>(
                          value: t['id'] as int,
                          label: t['text'].toString(),
                        )),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingStatsCard({
    required Color accent,
    required int workSeconds,
    required int breakSeconds,
    required double workPct,
  }) {
    const radius = 18.0;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Today Stats',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(Icons.insights, size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Worked',
                  value: _formatDuration(workSeconds),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Break',
                  value: _formatDuration(breakSeconds),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Focus',
                  value: '${workPct.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 12),
          Text(
            _formatClock(_engine.remainingSeconds),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.8,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _modeLabel(_engine.mode),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final dbWorkSeconds = _todayTotals['work'] ?? 0;
    final dbBreakSeconds = _todayTotals['break'] ?? 0;

    final liveSessionSeconds =
        _engine.currentSessionElapsedSeconds;
    final liveWorkSeconds =
        dbWorkSeconds + (_engine.isWorkMode ? liveSessionSeconds : 0);
    final liveBreakSeconds =
        dbBreakSeconds + (_engine.isBreakMode ? liveSessionSeconds : 0);
    final liveTotalSeconds = liveWorkSeconds + liveBreakSeconds;
    final workPct =
        liveTotalSeconds == 0 ? 0.0 : (liveWorkSeconds / liveTotalSeconds) * 100;

    return ValueListenableBuilder<bool>(
      valueListenable: focusModeNotifier,
      builder: (context, focusMode, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final heroHeight = focusMode
                ? constraints.maxHeight
                : (constraints.maxHeight - 20).clamp(480.0, 1400.0);

            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollCtrl,
                  physics: focusMode ? const NeverScrollableScrollPhysics() : null,
                  padding: EdgeInsets.fromLTRB(24, 8, 24, focusMode ? 0 : 18),
                  child: Column(
                    children: [
                      _timerHero(accent: accent, height: heroHeight),
                      if (!focusMode)
                        SizedBox(
                          key: _statsKey,
                    child: IgnorePointer(
                      ignoring: _floatingStats,
                      child: AnimatedOpacity(
                        opacity: _floatingStats ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today Stats',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Worked/Studied',
                                      value: _formatDuration(liveWorkSeconds),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Break',
                                      value: _formatDuration(liveBreakSeconds),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Focus %',
                                      value:
                                          '${workPct.toStringAsFixed(1)}%',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Date-wise Entries',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              if (_dailyStats.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Text(
                                      'No timer entries yet',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  itemCount: _dailyStats.length,
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, i) {
                                    final row = _dailyStats[i];
                                    final date = row['date']?.toString() ?? '';
                                    final ws = (row['work_seconds'] as num?)
                                            ?.toInt() ??
                                        0;
                                    final bs = (row['break_seconds'] as num?)
                                            ?.toInt() ??
                                        0;
                                    final total = ws + bs;
                                    final pct = total == 0
                                        ? 0.0
                                        : (ws / total) * 100;
                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.04,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 64,
                                            child: Text(
                                              _displayDate(date),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Work ${_formatDuration(ws)} • Break ${_formatDuration(bs)}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          Text('${pct.toStringAsFixed(0)}%'),
                                        ],
                                      ),
                                    ).animate().fadeIn(
                                      delay: Duration(milliseconds: 60 * i),
                                      duration: 220.ms,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 24,
              right: 24,
              child: IgnorePointer(
                ignoring: !_floatingStats,
                child: AnimatedOpacity(
                  opacity: _floatingStats ? 1 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: _floatingStats
                        ? Offset.zero
                        : const Offset(0, -0.08),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: _floatingStatsCard(
                      accent: accent,
                      workSeconds: liveWorkSeconds,
                      breakSeconds: liveBreakSeconds,
                      workPct: workPct,
                    ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
