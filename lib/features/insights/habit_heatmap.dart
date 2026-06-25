import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HabitHeatmap extends StatelessWidget {
  final Map<DateTime, int> data;
  final Color accent;

  const HabitHeatmap({
    super.key,
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    // Calculate the number of weeks that can fit in the viewport
    // A typical mobile view might fit around 18-20 weeks
    const cols = 22;
    
    final currentWeekday = todayNormalized.weekday;
    final totalDaysToSubtract = (cols - 1) * 7 + (currentWeekday - 1);
    final startDate = todayNormalized.subtract(Duration(days: totalDaysToSubtract));

    int maxCount = 4; // Ensures a smooth gradient even on low-activity days
    for (final count in data.values) {
      if (count > maxCount) maxCount = count;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Habit Heatmap',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDayLabel('Mon'),
                  const SizedBox(height: 4),
                  _buildDayLabel('Tue'),
                  const SizedBox(height: 4),
                  _buildDayLabel('Wed'),
                  const SizedBox(height: 4),
                  _buildDayLabel('Thu'),
                  const SizedBox(height: 4),
                  _buildDayLabel('Fri'),
                  const SizedBox(height: 4),
                  _buildDayLabel('Sat'),
                  const SizedBox(height: 4),
                  _buildDayLabel('Sun'),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true, // Always scroll to the rightmost (today)
                      child: Row(
                        children: List.generate(cols, (colIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Column(
                              children: List.generate(7, (rowIndex) {
                                final dayOffset = (colIndex * 7) + rowIndex;
                                final currentDate = startDate.add(Duration(days: dayOffset));
                                
                                if (currentDate.isAfter(todayNormalized)) {
                                  return const Padding(
                                    padding: EdgeInsets.only(bottom: 4.0),
                                    child: SizedBox(width: 16, height: 16),
                                  );
                                }

                                final count = data[currentDate] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: _buildSquare(count, maxCount, accent),
                                );
                              }),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOutCubic).slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Less', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 8),
            _buildSquare(0, maxCount, accent),
            const SizedBox(width: 4),
            _buildSquare(0, maxCount, accent, isLegend: true, legendIntensity: 0.35),
            const SizedBox(width: 4),
            _buildSquare(0, maxCount, accent, isLegend: true, legendIntensity: 0.55),
            const SizedBox(width: 4),
            _buildSquare(0, maxCount, accent, isLegend: true, legendIntensity: 0.75),
            const SizedBox(width: 4),
            _buildSquare(0, maxCount, accent, isLegend: true, legendIntensity: 1.0),
            const SizedBox(width: 8),
            const Text('More', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildDayLabel(String label) {
    return SizedBox(
      height: 16,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSquare(int count, int maxCount, Color accent, {bool isLegend = false, double? legendIntensity}) {
    Color color;
    if (isLegend && legendIntensity != null) {
      color = accent.withValues(alpha: legendIntensity);
    } else if (count == 0) {
      color = Colors.white.withValues(alpha: 0.05);
    } else {
      final intensity = (count / maxCount).clamp(0.2, 1.0);
      color = accent.withValues(alpha: intensity);
    }

    return Tooltip(
      message: isLegend ? '' : count > 0 ? '$count task${count == 1 ? '' : 's'} completed' : 'No tasks',
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: (count == 0 && !isLegend) ? Colors.white.withValues(alpha: 0.05) : accent.withValues(alpha: 0.1),
            width: 1,
          )
        ),
      ),
    );
  }
}
