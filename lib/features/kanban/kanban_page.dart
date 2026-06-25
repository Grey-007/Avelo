import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/todo_db.dart';
import '../../theme/avelo_theme.dart';
import 'dart:ui';

class KanbanPage extends StatefulWidget {
  const KanbanPage({super.key});

  @override
  State<KanbanPage> createState() => _KanbanPageState();
}

class _KanbanPageState extends State<KanbanPage> {
  List<Map<String, dynamic>> _todos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final todos = await TodoDB.instance.getTodosForKanban();
    setState(() {
      _todos = todos;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    await TodoDB.instance.updateTodoStatus(id, newStatus);
    await _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final todoList = _todos.where((t) => t['status'] == 'todo').toList();
    final inProgressList = _todos.where((t) => t['status'] == 'in_progress').toList();
    final doneList = _todos.where((t) => t['status'] == 'done').toList();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Board',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ).animate().fadeIn().slideX(begin: -0.2),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _KanbanColumn(
                  title: 'To Do',
                  status: 'todo',
                  todos: todoList,
                  onTaskDropped: _updateStatus,
                ),
                const SizedBox(width: 24),
                _KanbanColumn(
                  title: 'In Progress',
                  status: 'in_progress',
                  todos: inProgressList,
                  onTaskDropped: _updateStatus,
                ),
                const SizedBox(width: 24),
                _KanbanColumn(
                  title: 'Done',
                  status: 'done',
                  todos: doneList,
                  onTaskDropped: _updateStatus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final String status;
  final List<Map<String, dynamic>> todos;
  final Function(int, String) onTaskDropped;

  const _KanbanColumn({
    required this.title,
    required this.status,
    required this.todos,
    required this.onTaskDropped,
  });

  @override
  Widget build(BuildContext context) {
    final glass = AveloTheme.of(context).glass;
    final accent = Theme.of(context).colorScheme.primary;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        onTaskDropped(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 300,
          decoration: BoxDecoration(
            color: isHovering 
                ? accent.withValues(alpha: 0.15) 
                : Colors.white.withValues(alpha: glass ? 0.03 : 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovering 
                  ? accent.withValues(alpha: 0.5) 
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: glass ? 12 : 0, sigmaY: glass ? 12 : 0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${todos.length}',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: todos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final todo = todos[index];
                          return _KanbanCard(todo: todo);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate(target: isHovering ? 1 : 0).scaleXY(end: 1.02, curve: Curves.easeInOutCubic);
      },
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final Map<String, dynamic> todo;

  const _KanbanCard({required this.todo});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todo['tag'] != null && todo['tag'] != '')
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  todo['tag'],
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Text(
            todo['text'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (todo['subtask_count'] > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    '${todo["subtask_done_count"]} / ${todo["subtask_count"]}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Draggable<int>(
      data: todo['id'] as int,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 268, // Width of column minus padding
          child: Opacity(
            opacity: 0.9,
            child: card,
          ),
        ),
      ).animate().scaleXY(begin: 1.0, end: 1.05, duration: 200.ms, curve: Curves.easeOutBack),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: card,
      ),
      child: card,
    ).animate().fadeIn().scaleXY(begin: 0.95);
  }
}
