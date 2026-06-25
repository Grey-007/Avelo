import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../data/todo_db.dart';

class CalendarPage extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const CalendarPage({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const double blur = 24;
  List<Map<String, dynamic>> todos = [];
  Set<String> daysWithTasks = {};
  late DateTime focusedMonth;

  String get dateKey =>
      widget.selectedDate.toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    focusedMonth = widget.selectedDate;
    loadTodos();
    loadTasksForMonth(focusedMonth);
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      loadTodos();
    }
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      focusedMonth = widget.selectedDate;
      loadTasksForMonth(focusedMonth);
    }
  }

  Future<void> loadTodos() async {
    final data = await TodoDB.instance.getTodos(dateKey);
    if (mounted) setState(() => todos = data);
  }

  String _dateKeyFor(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> loadTasksForMonth(DateTime month) async {
    final keys = <String>{};
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final k = _dateKeyFor(d);
      final items = await TodoDB.instance.getTodos(k);
      if (items.isNotEmpty) keys.add(k);
    }
    if (mounted) setState(() => daysWithTasks = keys);
  }

  String _tagLabel(String raw) {
    if (!raw.contains('|')) return '';
    final parts = raw.split('|');
    if (parts.isEmpty) return '';
    return parts[0];
  }

  Color _tagColor(String raw) {
    if (!raw.contains('|')) return Colors.grey;
    final parts = raw.split('|');
    if (parts.length != 2) return Colors.grey;
    return Color(int.tryParse(parts[1]) ?? Colors.grey.toARGB32());
  }

  Future<void> _showEditTaskDialog(Map<String, dynamic> todo) async {
    final textCtrl = TextEditingController(text: todo['text']?.toString() ?? '');
    final raw = todo['tag']?.toString() ?? '';
    final tagCtrl = TextEditingController(text: _tagLabel(raw));
    Color selectedTagColor = raw.isEmpty ? Theme.of(context).colorScheme.primary : _tagColor(raw);

    final uniqueTags = await TodoDB.instance.getUniqueTags();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget colorDot(Color c) {
              final selected = selectedTagColor.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => setLocal(() => selectedTagColor = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.all(selected ? 3.5 : 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? c : c.withValues(alpha: 0.85),
                      width: selected ? 3 : 2,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Task',
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: textCtrl,
                        autofocus: true,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Task',
                          hintStyle: TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(ctx).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tag (optional)',
                          hintStyle: TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in [
                            Theme.of(ctx).colorScheme.primary,
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.red,
                          ])
                            colorDot(c),
                        ],
                      ),
                      if (uniqueTags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Recent Tags:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: uniqueTags.map((tagRaw) {
                            final tName = _tagLabel(tagRaw);
                            final tColor = _tagColor(tagRaw);
                            return GestureDetector(
                              onTap: () {
                                tagCtrl.text = tName;
                                setLocal(() => selectedTagColor = tColor);
                              },
                              child: Chip(
                                backgroundColor: tColor.withValues(alpha: 0.1),
                                side: BorderSide(color: tColor.withValues(alpha: 0.3)),
                                label: Text(tName, style: TextStyle(color: tColor, fontSize: 12)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final text = textCtrl.text.trim();
                                final tagName = tagCtrl.text.trim();
                                final tagString = tagName.isNotEmpty
                                    ? '$tagName|${selectedTagColor.toARGB32()}'
                                    : '';
                                if (text.isEmpty) return;
                                await TodoDB.instance.updateTodo(
                                  id: todo['id'] as int,
                                  text: text,
                                  tag: tagString,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Save',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    textCtrl.dispose();
    tagCtrl.dispose();
    await loadTodos();
    await loadTasksForMonth(focusedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.utc(2020),
                      lastDay: DateTime.utc(2035),
                      focusedDay: focusedMonth,
                      onPageChanged: (newFocused) {
                        setState(() => focusedMonth = newFocused);
                        loadTasksForMonth(focusedMonth);
                      },
                      selectedDayPredicate: (d) =>
                          isSameDay(d, widget.selectedDate),
                      onDaySelected: (d, _) =>
                      widget.onDateSelected(d),
                  headerStyle: const HeaderStyle(
                    titleCentered: false,
                    formatButtonVisible: false,
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, curve: Curves.easeInOutCubic)
                    .slideY(begin: -0.1, duration: 400.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: 12),

                const SizedBox(height: 12),

                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: todos.length,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (BuildContext context, Widget? child) {
                          final double animValue = Curves.easeInOut.transform(animation.value);
                          final double scale = lerpDouble(1, 1.02, animValue)!;
                          return Transform.scale(
                            scale: scale,
                            child: Card(
                              elevation: 8 * animValue,
                              color: Colors.transparent,
                              margin: EdgeInsets.zero,
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    onReorder: (oldIndex, newIndex) async {
                      if (oldIndex < newIndex) newIndex -= 1;
                      setState(() {
                        final item = todos.removeAt(oldIndex);
                        todos.insert(newIndex, item);
                      });
                      
                      for (int i = 0; i < todos.length; i++) {
                        await TodoDB.instance.reorder(todos[i]['id'] as int, i);
                      }
                    },
                    itemBuilder: (context, i) {
                      final t = todos[i];
                      final raw = t['tag']?.toString() ?? '';
                      final tag = _tagLabel(raw);
                      final tagColor = _tagColor(raw);

                      final isDone = (t['done'] as int) == 1;

                      return GestureDetector(
                        key: ValueKey(t['id']),
                        onTap: () => _showEditTaskDialog(t),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDone
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                width: 4,
                                color: isDone ? accent.withValues(alpha: 0.3) : accent,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              GestureDetector(
                                onTap: () async {
                                  await TodoDB.instance.toggleDone(
                                    t['id'] as int,
                                    !isDone,
                                  );
                                  await loadTodos();
                                },
                                child: Icon(
                                  isDone ? Icons.check_circle : Icons.circle_outlined,
                                  size: 20,
                                  color: isDone ? accent : Colors.white54,
                                )
                                    .animate()
                                    .scale(curve: Curves.easeInOutCubic),
                              ),
                              const SizedBox(width: 10),
                              // Task text
                              Expanded(
                                child: Text(
                                  t['text'],
                                  style: TextStyle(
                                    color: isDone ? Colors.white54 : Colors.white,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    decorationColor:
                                        isDone ? Colors.white54 : null,
                                  ),
                                ),
                              ),
                              // Tag if exists
                              if (tag.isNotEmpty)
                                Chip(
                                  avatar: Icon(Icons.tag,
                                      size: 14, color: tagColor),
                                  label: Text(tag),
                                ),
                              const SizedBox(width: 8),
                              // Delete button
                              GestureDetector(
                                onTap: () async {
                                  await TodoDB.instance.deleteTodo(
                                    t['id'] as int,
                                  );
                                  await loadTodos();
                                },
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent.withValues(alpha: 0.7),
                                )
                                    .animate()
                                    .scale(curve: Curves.easeInOutCubic),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 100 + (i * 50)), duration: 300.ms, curve: Curves.easeInOutCubic)
                          .slideY(begin: 0.2, delay: Duration(milliseconds: 100 + (i * 50)), duration: 300.ms, curve: Curves.easeOutCubic);
                    },
                  ),
                ),
              ],
            ),
          ),
              // Floating Action Button with Spring Animation
              Positioned(
                bottom: 20,
                right: 20,
                child: _AnimatedAddButton(
                  accent: accent,
                  selectedDate: widget.selectedDate,
                  onAddTask: (payload) async {
                    final text = payload['text'] as String? ?? '';
                    final tag = payload['tag'] as String? ?? '';
                    if (text.trim().isEmpty) return;
                    await TodoDB.instance.addTodo(dateKey, text, tag);
                    await loadTodos();
                    await loadTasksForMonth(focusedMonth);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated Add Button with Spring Animation and Task Dialog
class _AnimatedAddButton extends StatefulWidget {
  final Color accent;
  final DateTime selectedDate;
  final ValueChanged<Map<String, dynamic>> onAddTask;

  const _AnimatedAddButton({
    required this.accent,
    required this.selectedDate,
    required this.onAddTask,
  });

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() async {
    final tags = await TodoDB.instance.getUniqueTags();
    // Spring press animation - bounce effect
    _controller.reverse(from: 1.0).then((_) {
      _controller.forward();
      // Show add task dialog
      _showAddTaskDialog(tags);
    });
  }

  void _showAddTaskDialog(List<String> uniqueTags) {
    final TextEditingController taskCtrl = TextEditingController();
    final TextEditingController tagCtrl = TextEditingController();
    Color selectedTagColor = widget.accent;
    final dateFormatter = widget.selectedDate.toString().split(' ')[0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget colorDot(Color c) {
            final selected = selectedTagColor.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => setLocal(() => selectedTagColor = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.all(selected ? 3.5 : 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? c : c.withValues(alpha: 0.85),
                    width: selected ? 3 : 2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: c.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Add Task',
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms, curve: Curves.easeInOutCubic)
                        .slideX(
                          begin: -0.1,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 8),

                    // Date info
                    Text(
                      'Selected Date: $dateFormatter',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                    )
                        .animate()
                        .fadeIn(
                          delay: 50.ms,
                          duration: 300.ms,
                          curve: Curves.easeInOutCubic,
                        )
                        .slideX(
                          begin: -0.1,
                          delay: 50.ms,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 20),

                    // Input field
                    TextField(
                      controller: taskCtrl,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What do you want to do?',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: widget.accent,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(
                          delay: 100.ms,
                          duration: 300.ms,
                          curve: Curves.easeInOutCubic,
                        )
                        .slideY(
                          begin: 0.1,
                          delay: 100.ms,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 12),

                    // Tag input + color picker
                    TextField(
                      controller: tagCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tag (optional)',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in [
                          widget.accent,
                          Colors.blue,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                          Colors.red,
                        ])
                          colorDot(c),
                      ],
                    ),

                    if (uniqueTags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Recent Tags:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: uniqueTags.map((tagRaw) {
                          if (!tagRaw.contains('|')) return const SizedBox.shrink();
                          final parts = tagRaw.split('|');
                          final tName = parts[0];
                          final tColor = Color(int.tryParse(parts[1]) ?? Colors.grey.toARGB32());
                          return GestureDetector(
                            onTap: () {
                              tagCtrl.text = tName;
                              setLocal(() => selectedTagColor = tColor);
                            },
                            child: Chip(
                              backgroundColor: tColor.withValues(alpha: 0.1),
                              side: BorderSide(color: tColor.withValues(alpha: 0.3)),
                              label: Text(tName, style: TextStyle(color: tColor, fontSize: 12)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                delay: 150.ms,
                                duration: 300.ms,
                                curve: Curves.easeInOutCubic,
                              )
                              .slideY(
                                begin: 0.1,
                                delay: 150.ms,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final text = taskCtrl.text.trim();
                              final tagName = tagCtrl.text.trim();
                              final tagString = tagName.isNotEmpty
                                  ? '$tagName|${selectedTagColor.toARGB32()}'
                                  : '';
                              if (text.isNotEmpty) {
                                widget.onAddTask({
                                  'text': text,
                                  'tag': tagString,
                                });
                                Navigator.pop(ctx);
                              }
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: widget.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Add Task',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                delay: 150.ms,
                                duration: 300.ms,
                                curve: Curves.easeInOutCubic,
                              )
                              .slideY(
                                begin: 0.1,
                                delay: 150.ms,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      taskCtrl.dispose();
      tagCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: MouseRegion(
        onEnter: (_) {
          if (_controller.isCompleted) {
            _controller.forward(from: 0.9);
          }
        },
        child: GestureDetector(
          onTap: _handlePress,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent,
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(
                        alpha: 0.4 + (_controller.value * 0.2),
                      ),
                      blurRadius: 12 + (_controller.value * 4),
                      spreadRadius: 2 + (_controller.value * 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(14 + (_controller.value * 2)),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
