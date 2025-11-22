import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../realtime_db_service.dart';

class RealtimeLineChart extends StatefulWidget {
  final Stream<List<TimestampedFlSpot>> dataStream;
  final double Function(TimestampedFlSpot) getMetricValue;
  final String metricUnit;
  final Color? lineColor;
  final bool isPaused;

  const RealtimeLineChart({
    super.key,
    required this.dataStream,
    required this.getMetricValue,
    required this.metricUnit,
    this.lineColor,
    this.isPaused = false,
  });

  @override
  RealtimeLineChartState createState() => RealtimeLineChartState();
}

class RealtimeLineChartState extends State<RealtimeLineChart> {
  List<TimestampedFlSpot> _allSpots = [];
  List<TimestampedFlSpot> _pausedSpots = [];
  Timer? _timer;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _dataSubscription = widget.dataStream.listen((data) {
      if (mounted && !widget.isPaused) {
        setState(() {
          _allSpots = data;
        });
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !widget.isPaused) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(RealtimeLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When paused state changes from false to true, save current data
    if (!oldWidget.isPaused && widget.isPaused) {
      _pausedSpots = List.from(_allSpots);
      debugPrint('[RealtimeLineChart] Chart paused, saved ${_pausedSpots.length} data points');
    }
    // When unpaused, clear the paused snapshot
    if (oldWidget.isPaused && !widget.isPaused) {
      _pausedSpots = [];
      debugPrint('[RealtimeLineChart] Chart resumed');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Add a 5-second buffer to prevent visible data cutoff at the edges
    final sixtyFiveSecondsAgo = now.subtract(const Duration(seconds: 65));
    final sixtySecondsAgo = now.subtract(const Duration(seconds: 60));

    // Chart displays from 60 seconds ago to now (visible window)
    final double minX = 0; // Relative to sixtySecondsAgo
    final double maxX = now.difference(sixtySecondsAgo).inMilliseconds.toDouble();

    // Use paused data snapshot when paused, otherwise use live data
    final dataToDisplay = widget.isPaused ? _pausedSpots : _allSpots;

    // Fetch data from 65 seconds ago (5-second buffer) but only display 60 seconds
    final recentSpots = dataToDisplay.where((spot) {
      return spot.timestamp.isAfter(sixtyFiveSecondsAgo);
    }).toList();

    // Convert TimestampedFlSpot to FlSpot for the chart, using the selected metric as the Y-value
    List<FlSpot> chartSpots = recentSpots.map((tsSpot) {
      final xValue = tsSpot.timestamp.difference(sixtySecondsAgo).inMilliseconds.toDouble();
      // Clamp X values to ensure they stay within chart boundaries
      final clampedX = xValue.clamp(minX, maxX);
      return FlSpot(clampedX, widget.getMetricValue(tsSpot));
    }).toList();

    // Show flat chart immediately if no data in the last 60 seconds
    if (chartSpots.isEmpty) {
      return SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: 0,
            maxY: 10, // Default max Y for flat line visibility
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 15 * 1000, // Every 15 seconds
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max || value == meta.min) {
                      return const Text('');
                    }
                    final dateTime = DateTime.fromMillisecondsSinceEpoch(
                      sixtySecondsAgo.millisecondsSinceEpoch + value.toInt(),
                    );
                    return Text(DateFormat('HH:mm:ss').format(dateTime));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Text('${value.toStringAsFixed(0)} ${widget.metricUnit}');
                  },
                  interval: 2,
                  reservedSize: 60,
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: const FlGridData(show: true, drawVerticalLine: true),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.withAlpha((255 * 0.5).round()), width: 2),
                right: BorderSide(color: Colors.grey.withAlpha((255 * 0.5).round()), width: 2),
                left: BorderSide.none,
                top: BorderSide.none,
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: const [], // Empty - no data
                isCurved: true,
                color: widget.lineColor ?? Theme.of(context).colorScheme.secondary,
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  color: (widget.lineColor ?? Theme.of(context).colorScheme.secondary).withAlpha(100),
                ),
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      );
    }

    // Show data point count when we have some data
    debugPrint('[RealtimeLineChart] Rendering chart with ${chartSpots.length} data points');

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: _getMaxY(chartSpots),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 15 * 1000, // Every 15 seconds
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const Text('');
                  }
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(
                    sixtySecondsAgo.millisecondsSinceEpoch + value.toInt(),
                  );
                  return Text(DateFormat('HH:mm:ss').format(dateTime));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toStringAsFixed(0)} ${widget.metricUnit}');
                },
                interval: _getMaxY(chartSpots) / 5 > 0
                    ? _getMaxY(chartSpots) / 5
                    : 1,
                reservedSize: 60,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: true),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withAlpha((255 * 0.5).round()), width: 2),
              right: BorderSide(color: Colors.grey.withAlpha((255 * 0.5).round()), width: 2),
              left: BorderSide.none,
              top: BorderSide.none,
            ),
          ),
          clipData: const FlClipData.all(), // Clip lines to stay within chart boundaries
          lineBarsData: [
            LineChartBarData(
              spots: chartSpots,
              isCurved: true,
              color: widget.lineColor ?? Theme.of(context).colorScheme.secondary,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: (widget.lineColor ?? Theme.of(context).colorScheme.secondary).withAlpha(100),
              ),
              dotData: const FlDotData(show: false),
              preventCurveOverShooting: true, // Prevent curve from overshooting data points
            ),
          ],
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: widget.lineColor ?? Theme.of(context).colorScheme.secondary,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((LineBarSpot barSpot) {
                  // barSpot.x is relative milliseconds from sixtySecondsAgo
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(
                    sixtySecondsAgo.millisecondsSinceEpoch + barSpot.x.toInt(),
                  );
                  final formattedTime = DateFormat('HH:mm:ss').format(dateTime);

                  return LineTooltipItem(
                    '${barSpot.y.toStringAsFixed(2)} ${widget.metricUnit}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '\n$formattedTime',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  double _getMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return 10; // Default max Y for flat line visibility
    }
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return (maxY * 1.2).clamp(10, double.infinity); // Ensure a minimum maxY
  }
}