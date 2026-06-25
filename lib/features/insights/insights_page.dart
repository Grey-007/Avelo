import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/todo_db.dart';
import 'habit_heatmap.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _tagStats = [];
  Map<DateTime, int> _heatmapData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final daily = await TodoDB.instance.getTimerDailyStats(limit: 7);
    final tag = await TodoDB.instance.getTimeSpentPerTag(7);
    final heatmap = await TodoDB.instance.getHeatmapStats();
    if (!mounted) return;
    setState(() {
      // reverse daily stats so the oldest is first in the chart (left to right)
      _dailyStats = daily.reversed.toList();
      _tagStats = tag;
      _heatmapData = heatmap;
      _loading = false;
    });
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0m';
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

  Color _tagColor(String raw) {
    if (!raw.contains('|')) return Colors.grey;
    final parts = raw.split('|');
    if (parts.length != 2) return Colors.grey;
    return Color(int.tryParse(parts[1]) ?? Colors.grey.toARGB32());
  }

  String _tagLabel(String raw) {
    if (!raw.contains('|')) return raw;
    return raw.split('|')[0];
  }

  Widget _buildBarChart(Color accent) {
    if (_dailyStats.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No timer data for the past 7 days', style: TextStyle(color: Colors.white54))),
      );
    }

    final maxSeconds = _dailyStats.fold<int>(
      0,
      (maxVal, row) {
        final w = (row['work_seconds'] as num?)?.toInt() ?? 0;
        final b = (row['break_seconds'] as num?)?.toInt() ?? 0;
        return max(maxVal, w + b);
      },
    );

    return SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = (constraints.maxWidth / 7) * 0.5;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _dailyStats.map((row) {
              final date = row['date']?.toString() ?? '';
              final ws = (row['work_seconds'] as num?)?.toInt() ?? 0;
              final bs = (row['break_seconds'] as num?)?.toInt() ?? 0;
              final total = ws + bs;
              
              final heightPct = maxSeconds == 0 ? 0.0 : total / maxSeconds;
              final maxBarHeight = constraints.maxHeight - 40; // leave room for text
              final barHeight = maxBarHeight * heightPct;
              
              final workPct = total == 0 ? 0.0 : ws / total;
              final breakPct = total == 0 ? 0.0 : bs / total;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Tooltip/Value
                  Text(
                    total == 0 ? '' : _formatDuration(total),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  // The bar
                  Container(
                    width: barWidth.clamp(10.0, 40.0),
                    height: max(4.0, barHeight),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (breakPct > 0)
                          Expanded(
                            flex: (breakPct * 100).toInt(),
                            child: Container(color: Colors.blueAccent.withValues(alpha: 0.8)),
                          ),
                        if (workPct > 0)
                          Expanded(
                            flex: (workPct * 100).toInt(),
                            child: Container(color: accent),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Label
                  Text(
                    _displayDate(date),
                    style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTagStats(Color accent) {
    if (_tagStats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('No task-linked timer logs found in the last 7 days.', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final maxTagSeconds = _tagStats.fold<int>(
      0,
      (m, row) => max(m, (row['total_seconds'] as num?)?.toInt() ?? 0),
    );

    return Column(
      children: _tagStats.map((row) {
        final raw = row['tag']?.toString() ?? '';
        final total = (row['total_seconds'] as num?)?.toInt() ?? 0;
        final tColor = _tagColor(raw);
        final tLabel = _tagLabel(raw);
        final pct = maxTagSeconds == 0 ? 0.0 : total / maxTagSeconds;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tag, color: tColor, size: 16),
                  const SizedBox(width: 6),
                  Text(tLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Text(_formatDuration(total), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: 800.ms,
                    curve: Curves.easeOutCubic,
                    height: 8,
                    width: MediaQuery.of(context).size.width * pct * 0.8, // Approximation for progress
                    decoration: BoxDecoration(
                      color: tColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(color: tColor.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Insights & Analytics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadData,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Icon(Icons.refresh, color: accent, size: 20),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: -0.1),
          
          const SizedBox(height: 12),
          
          HabitHeatmap(data: _heatmapData, accent: accent),
          
          const SizedBox(height: 32),
          
          const Text('Last 7 Days (Timer)', style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 16),

          // Chart Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('Work', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 16),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.8), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('Break', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildBarChart(accent),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          // Tag Breakdown Section
          const Text(
            'Time Spent by Tag',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: _buildTagStats(accent),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }
}
