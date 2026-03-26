import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/services/result_formatter.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/services/sharing_service.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';

/// Shows evaluation history with a score trend chart and session list.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final EvaluationHistoryRepository _repo;
  List<EvaluationResult> _results = [];
  String? _styleFilter;
  String? _referenceFilter;

  @override
  void initState() {
    super.initState();
    _repo = ServiceLocator.instance.get<EvaluationHistoryRepository>();
    _results = _repo.listAll();
  }

  List<EvaluationResult> get _filteredResults {
    var results = _results;
    if (_styleFilter != null) {
      results = results.where((r) => r.style.name == _styleFilter).toList();
    }
    if (_referenceFilter != null) {
      results = results
          .where((r) => r.referenceName == _referenceFilter)
          .toList();
    }
    return results;
  }

  Future<void> _exportHistory() async {
    final json = ResultFormatter.exportAllAsJson(_results);
    try {
      final sharing = ServiceLocator.instance.get<SharingService>();
      await sharing.saveJsonFile(json, 'dance_evaluation_history.json');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export not available')),
        );
      }
    }
  }

  Future<void> _importHistory() async {
    try {
      final sharing = ServiceLocator.instance.get<SharingService>();
      final jsonStr = await sharing.pickJsonFile();
      if (jsonStr == null) return;

      final results = ResultFormatter.parseImportJson(jsonStr);
      final imported = _repo.importAll(results);

      setState(() {
        _results = _repo.listAll();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $imported result(s)')),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid file: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import not available')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import',
            onPressed: _importHistory,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export All',
            onPressed: _results.isEmpty ? null : _exportHistory,
          ),
        ],
      ),
      body: _results.isEmpty
          ? Center(

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: theme.colorScheme.secondary.withValues(alpha:0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete a dance evaluation to see your progress',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_results.length >= 2) ...[
                  _buildChart(theme),
                  const SizedBox(height: 8),
                  _buildStats(theme),
                  const SizedBox(height: 24),
                ],
                _buildFilters(theme),
                const SizedBox(height: 12),
                Text(
                  'Sessions (${_filteredResults.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                ..._filteredResults.map((r) => _buildSessionCard(r, theme)),
              ],
            ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    // Collect unique styles and reference names from results.
    final styles = _results.map((r) => r.style.name).toSet().toList()..sort();
    final refNames = _results
        .where((r) => r.referenceName != null)
        .map((r) => r.referenceName!)
        .toSet()
        .toList()
      ..sort();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        DropdownButton<String?>(
          value: _styleFilter,
          hint: const Text('All Styles', style: TextStyle(color: Colors.white54)),
          underline: const SizedBox.shrink(),
          dropdownColor: const Color(0xFF1E1E2C),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Styles')),
            ...styles.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s),
                )),
          ],
          onChanged: (v) => setState(() => _styleFilter = v),
        ),
        if (refNames.length > 1)
          DropdownButton<String?>(
            value: _referenceFilter,
            hint: const Text('All References', style: TextStyle(color: Colors.white54)),
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF1E1E2C),
            items: [
              const DropdownMenuItem(value: null, child: Text('All References')),
              ...refNames.map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(n, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _referenceFilter = v),
          ),
      ],
    );
  }

  Widget _buildChart(ThemeData theme) {
    // Show up to 20 most recent results, oldest first for the chart.
    final chartData = _results.length > 20
        ? _results.sublist(0, 20).reversed.toList()
        : _results.reversed.toList();

    final spots = <FlSpot>[];
    for (var i = 0; i < chartData.length; i++) {
      spots.add(FlSpot(i.toDouble(), chartData[i].overallScore));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Colors.white10,
              strokeWidth: 1,
            ),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: chartData.length <= 10,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: theme.colorScheme.primary,
                  strokeColor: Colors.white24,
                  strokeWidth: 1,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha:0.15),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      s.y.toStringAsFixed(1),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(ThemeData theme) {
    final scores = _results.map((r) => r.overallScore).toList();
    final best = scores.reduce((a, b) => a > b ? a : b);
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final latest = scores.first;

    // Trend: compare last 3 average to previous 3 average.
    String trend = '--';
    if (_results.length >= 4) {
      final recentAvg = scores.take(3).reduce((a, b) => a + b) / 3;
      final olderAvg = scores.skip(3).take(3).reduce((a, b) => a + b) /
          scores.skip(3).take(3).length;
      final diff = recentAvg - olderAvg;
      if (diff > 2) {
        trend = '+${diff.toStringAsFixed(1)}';
      } else if (diff < -2) {
        trend = diff.toStringAsFixed(1);
      } else {
        trend = 'Steady';
      }
    }

    return Row(
      children: [
        _StatTile(label: 'Best', value: best.toStringAsFixed(0), theme: theme),
        _StatTile(label: 'Avg', value: avg.toStringAsFixed(0), theme: theme),
        _StatTile(
          label: 'Latest',
          value: latest.toStringAsFixed(0),
          theme: theme,
        ),
        _StatTile(label: 'Trend', value: trend, theme: theme),
      ],
    );
  }

  Widget _buildSessionCard(EvaluationResult result, ThemeData theme) {
    final date = result.createdAt;
    final dateStr =
        '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    final scoreColor = result.overallScore >= 70
        ? Colors.greenAccent
        : result.overallScore >= 40
            ? Colors.amberAccent
            : Colors.redAccent;

    return Card(
      color: theme.colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(result.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.redAccent,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) {
          _repo.delete(result.id);
          setState(() {
            _results = _repo.listAll();
          });
        },
        child: ListTile(
          onTap: () => context.push('/history/${result.id}'),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha:0.15),
            ),
            child: Center(
              child: Text(
                result.overallScore.toStringAsFixed(0),
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            result.sessionName ?? result.referenceName ?? result.style.name,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: Text(
            dateStr,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...result.dimensions.take(4).map((d) {
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _DimensionDot(score: d.score),
                );
              }),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionDot extends StatelessWidget {
  const _DimensionDot({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? Colors.greenAccent
        : score >= 40
            ? Colors.amberAccent
            : Colors.redAccent;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
