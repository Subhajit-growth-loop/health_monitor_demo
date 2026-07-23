import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';

/// A trend chart. Sum-based metrics (steps, active energy) render as bars;
/// continuous metrics as a line.
///
/// Bar charts: tapping a bar highlights it and shows a data panel **below**
/// the chart (always fully visible). Tap the same bar or outside to dismiss.
///
/// Line charts: tapping a data point shows a persistent tooltip until the
/// user taps the same point or elsewhere.
///
/// Set [bottomSubLabelFormatter] to get a two-line x-axis label (e.g. "Mon\n14").
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.type,
    required this.points,
    this.bottomLabelFormatter,
    this.bottomSubLabelFormatter,
    this.secondaryPoints,
    this.secondaryType,
  });

  final HealthMetricType type;
  final List<DailyPoint> points;
  final String Function(DateTime)? bottomLabelFormatter;
  final String Function(DateTime)? bottomSubLabelFormatter;
  final List<DailyPoint>? secondaryPoints;
  final HealthMetricType? secondaryType;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _selectedBarIndex;
  int? _selectedLineIndex;
  // Newest data lives at the highest x index (right edge), so open scrolled to
  // the end. Shared by the bar and line scroll views (only one is ever mounted).
  final ScrollController _scrollController = ScrollController();

  bool get _isBar =>
      widget.type.aggregation == Aggregation.sum &&
      widget.secondaryPoints == null;
  bool get _needsScroll => widget.points.length > 9;
  bool get _hasTwoLines =>
      widget.secondaryPoints != null && widget.secondaryType != null;

  @override
  void initState() {
    super.initState();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _selectedBarIndex = null;
      _selectedLineIndex = null;
      // Switching period (week/month/year) swaps the point set — re-pin to the
      // most recent data on the right.
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Jump the horizontal scroll view to its far right after the next layout,
  /// so the latest readings are visible when the chart first appears.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  String _bottomLabel(DateTime day) => widget.bottomLabelFormatter != null
      ? widget.bottomLabelFormatter!(day)
      : Fmt.dayShort(day);

  double get _barWidth =>
      _needsScroll ? 14.w : (widget.points.length <= 7 ? 16.w : 12.w);

  double get _labelInterval {
    // When scrolling, every point gets ~32px of width — enough room to label
    // each one, so show all x-axis labels (month, year, …).
    if (_needsScroll) return 1;
    if (widget.points.length <= 7) return 1;
    if (widget.points.length <= 14) return 2;
    return 5;
  }

  double get _bottomReservedSize =>
      widget.bottomSubLabelFormatter != null ? 42.h : 28.h;

  /// Y-axis bounds and tick interval. Health metrics never go negative, so the
  /// axis is anchored at 0 and the top rounded up to a "nice" number, split into
  /// 5 steps → 6 evenly spaced gridlines (0 … max), each label a round value.
  ({double min, double max, double interval}) get _yAxis {
    // Menstruation flow is a fixed 0–3 categorical scale (—/L/M/H).
    if (widget.type == HealthMetricType.menstruationFlow) {
      return (min: 0, max: 3, interval: 1);
    }
    final maxData = [
      ...widget.points.map((p) => p.value),
      ...(widget.secondaryPoints?.map((p) => p.value) ?? const <double>[]),
    ].fold<double>(0, (a, b) => a > b ? a : b);

    final integer = widget.type.decimals == 0;
    if (maxData <= 0) return (min: 0, max: 5, interval: 1);

    var interval = _niceCeil(maxData / 5, integer: integer);
    if (integer && interval < 1) interval = 1;
    return (min: 0, max: interval * 5, interval: interval);
  }

  /// Smallest "nice" number (1, 2, 2.5, 5, 10 × 10ⁿ) that is ≥ [v]. When
  /// [integer] is set, 2.5-style steps are skipped so ticks stay whole numbers.
  double _niceCeil(double v, {required bool integer}) {
    if (v <= 0) return 1;
    final mults = integer
        ? const [1.0, 2.0, 5.0, 10.0]
        : const [1.0, 2.0, 2.5, 5.0, 10.0];
    final base = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in mults) {
      final step = m * base;
      if (step >= v - 1e-9) return step;
    }
    return 10 * base;
  }

  /// Grid lines at exactly min/max are skipped by fl_chart (it iterates the
  /// axis with min/max excluded), so add them explicitly — same dashed style as
  /// the auto gridlines — otherwise the top and bottom lines are missing.
  ExtraLinesData get _boundaryLines {
    HorizontalLine boundary(double y) => HorizontalLine(
          y: y,
          color: Colors.blueGrey,
          strokeWidth: 0.4,
          dashArray: const [8, 4],
        );
    return ExtraLinesData(
      horizontalLines: [boundary(_yAxis.min), boundary(_yAxis.max)],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return SizedBox(
          height: 200.h, child: const Center(child: Text('No data yet')));
    }

    if (_isBar) {
      // Bar chart: chart (195.h) + always-reserved info panel (36.h) = 231.h.
      // The extra 10.h vs the original compensates for the top reserved size
      // added to _titles() so both the top Y label and the tallest bar fit.
      // Info panel sits outside fl_chart's canvas, so it is never clipped.
      // TapRegion clears the selection when the user taps outside the widget.
      return TapRegion(
        onTapOutside: (_) {
          if (_selectedBarIndex != null) {
            setState(() => _selectedBarIndex = null);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 195.h,
              child: LayoutBuilder(builder: (context, constraints) {
                if (!_needsScroll) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: _buildBars(context),
                  );
                }
                return _scrollableWithPinnedAxis(
                  context,
                  _buildBars(context, showLeftTitles: false),
                  (widget.points.length * 32.0).w,
                );
              }),
            ),
            _buildBarInfoPanel(context),
          ],
        ),
      );
    }

    // Line chart.
    return TapRegion(
      onTapOutside: (_) {
        if (_selectedLineIndex != null) {
          setState(() => _selectedLineIndex = null);
        }
      },
      child: SizedBox(
        height: 220.h,
        child: LayoutBuilder(builder: (context, constraints) {
          if (!_needsScroll) {
            return SizedBox(
              width: constraints.maxWidth,
              child: _buildLine(context),
            );
          }
          return _scrollableWithPinnedAxis(
            context,
            _buildLine(context, showLeftTitles: false),
            (widget.points.length * 32.0).w,
            leftInset: 12.w,
          );
        }),
      ),
    );
  }

  // ── Bar info panel ─────────────────────────────────────────────────────────

  Widget _buildBarInfoPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Height is always reserved so the chart doesn't shift on selection change.
    return SizedBox(
      height: 36.h,
      child: Padding(
        padding: EdgeInsets.only(left: 40.w, top: 4.h),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _selectedBarIndex != null
              ? Container(
                  key: ValueKey(_selectedBarIndex),
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: scheme.inverseSurface,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Fmt.dateShort(
                            widget.points[_selectedBarIndex!].day),
                        style: TextStyle(
                          color: scheme.onInverseSurface,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${Fmt.metricValue(widget.type, widget.points[_selectedBarIndex!].value)}'
                        ' ${widget.type.unit}',
                        style: TextStyle(
                          color: widget.type.color,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ── Shared axis titles ─────────────────────────────────────────────────────

  Widget _bottomTitle(BuildContext context, double value) {
    final i = value.toInt();
    if (i < 0 || i >= widget.points.length) return const SizedBox.shrink();
    final day = widget.points[i].day;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_bottomLabel(day),
              style: TextStyle(fontSize: 11.sp, color: color)),
          if (widget.bottomSubLabelFormatter != null)
            Text(
              widget.bottomSubLabelFormatter!(day),
              style: TextStyle(
                  fontSize: 10.sp, color: color.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }

  /// Width reserved for the Y-axis labels. Shared by the pinned axis strip and
  /// the (label-less) scrolling plot so the two stay vertically aligned.
  double get _leftAxisWidth => 46.w;

  /// [showLeftTitles]/[showBottomTitles] let the scrolling layout split the
  /// chart into a fixed Y-axis strip (left titles only) and a scrolling plot
  /// (bottom titles only). Reserved sizes are kept identical on both so their
  /// plot rectangles — and therefore gridlines and labels — line up.
  FlTitlesData _titles(
    BuildContext context, {
    bool showLeftTitles = true,
    bool showBottomTitles = true,
  }) =>
      FlTitlesData(
        // showTitles must be true for reservedSize to be respected by fl_chart;
        // returning SizedBox.shrink() keeps the space empty but visible.
        topTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 14.h,
            getTitlesWidget: (_, __) => const SizedBox.shrink(),
          ),
        ),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: showLeftTitles
            ? AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _leftAxisWidth,
                  interval: _yAxis.interval,
                  getTitlesWidget: (v, _) => Text(
                    Fmt.yAxisLabel(widget.type, v),
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            // showTitles:false reserves no space, so the plot fills the scroll
            // width and its leftmost bar sits flush against the pinned strip.
            : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _labelInterval,
            reservedSize: _bottomReservedSize,
            getTitlesWidget: showBottomTitles
                ? (v, _) => _bottomTitle(context, v)
                : (_, __) => const SizedBox.shrink(),
          ),
        ),
      );

  // ── Pinned Y-axis strip ──────────────────────────────────────────────────
  //
  // A data-less chart drawing only the left titles, placed left of the
  // horizontally-scrolling plot so the Y labels stay fixed while the bars/line
  // scroll. Same minY/maxY/interval and top/bottom reserved sizes as the plot,
  // so its labels align with the plot's gridlines. OverflowBox gives the chart
  // a small positive plot width (fl_chart needs > 0) while the strip stays
  // exactly [_leftAxisWidth] wide; the empty overflow is clipped away.
  Widget _buildAxisStrip(BuildContext context) => SizedBox(
        width: _leftAxisWidth,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: _leftAxisWidth + 16.w,
            maxWidth: _leftAxisWidth + 16.w,
            child: BarChart(
              BarChartData(
                maxY: _yAxis.max,
                minY: _yAxis.min,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: _titles(context, showBottomTitles: false),
                barGroups: const [],
              ),
            ),
          ),
        ),
      );

  /// Wraps a label-less [plot] of width [chartWidth] in a horizontal scroll
  /// view with the pinned Y-axis strip fixed to its left.
  ///
  /// [leftInset] pads the scroll content on the left so edge-pinned content
  /// (the line chart pins its first point/label to minX) isn't clipped by the
  /// viewport edge — mirrors the trailing 16.w pad. Bar charts leave it at 0
  /// since BarChartAlignment.spaceAround already insets the first bar.
  Widget _scrollableWithPinnedAxis(
    BuildContext context,
    Widget plot,
    double chartWidth, {
    double leftInset = 0,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAxisStrip(context),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: leftInset, right: 16.w),
              child: SizedBox(width: chartWidth, child: plot),
            ),
          ),
        ],
      );

  // ── Bar chart ──────────────────────────────────────────────────────────────

  Widget _buildBars(BuildContext context, {bool showLeftTitles = true}) {
    return BarChart(
      BarChartData(
        maxY: _yAxis.max,
        minY: _yAxis.min,
        extraLinesData: _boundaryLines,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _yAxis.interval,
        ),
        titlesData: _titles(context, showLeftTitles: showLeftTitles),
        barTouchData: BarTouchData(
          handleBuiltInTouches: true,
          // Suppress fl_chart's built-in floating tooltip; we render the info
          // panel below the chart instead (always fully visible).
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
          ),
          touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
            if (event is! FlTapUpEvent) return;
            final tapped = response?.spot?.touchedBarGroupIndex;
            setState(() {
              _selectedBarIndex =
                  (tapped != null && tapped != _selectedBarIndex)
                      ? tapped
                      : null;
            });
          },
        ),
        barGroups: [
          for (var i = 0; i < widget.points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: widget.points[i].value,
                  // Highlight selected bar; dim the rest for contrast.
                  color: i == _selectedBarIndex
                      ? widget.type.color
                      : widget.type.color.withValues(alpha: 0.55),
                  width: _barWidth,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Line chart ─────────────────────────────────────────────────────────────

  Widget _buildLine(BuildContext context, {bool showLeftTitles = true}) {
    final scheme = Theme.of(context).colorScheme;

    // Build bar data first so they can be referenced in showingTooltipIndicators.
    final primaryBar = _lineBar(widget.points, widget.type.color);
    final secondaryBar = _hasTwoLines
        ? _lineBar(widget.secondaryPoints!, widget.secondaryType!.color,
            dashed: true)
        : null;
    final lineBarsData = [
      primaryBar,
      if (secondaryBar != null) secondaryBar,
    ];

    // Persistent tooltip: show indicator at the selected x index.
    List<ShowingTooltipIndicators> tooltipIndicators = const [];
    if (_selectedLineIndex != null) {
      final xi = _selectedLineIndex!;
      final spots = <LineBarSpot>[];
      // Skip gap days (nullSpot) — there's no value to show a tooltip for.
      if (xi < primaryBar.spots.length &&
          primaryBar.spots[xi] != FlSpot.nullSpot) {
        spots.add(LineBarSpot(primaryBar, 0, primaryBar.spots[xi]));
      }
      if (secondaryBar != null &&
          xi < secondaryBar.spots.length &&
          secondaryBar.spots[xi] != FlSpot.nullSpot) {
        spots.add(LineBarSpot(secondaryBar, 1, secondaryBar.spots[xi]));
      }
      if (spots.isNotEmpty) {
        tooltipIndicators = [ShowingTooltipIndicators(spots)];
      }
    }

    return LineChart(
      LineChartData(
        // No clipping: dots on the left/right/bottom edge would otherwise have
        // their circles sliced off by the plot rectangle. Curve overshoot
        // (which clipping used to hide) is prevented on the bars themselves.
        clipData: const FlClipData.none(),
        showingTooltipIndicators: tooltipIndicators,
        maxY: _yAxis.max,
        minY: _yAxis.min,
        // Pin the x-range to the full window so every day's label shows even
        // when trailing days have no data (gaps). Without this, fl_chart
        // derives maxX from the last non-null spot and the axis stops early.
        minX: 0,
        maxX: (widget.points.length - 1).toDouble(),
        extraLinesData: _boundaryLines,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _yAxis.interval,
        ),
        titlesData: _titles(context, showLeftTitles: showLeftTitles),
        lineTouchData: LineTouchData(
          // Built-in touches disabled; we drive tooltip visibility via
          // showingTooltipIndicators so it persists after the finger lifts.
          handleBuiltInTouches: false,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            tooltipPadding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            tooltipRoundedRadius: 10.r,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final i = spot.x.toInt();
                final isSecondary = spot.barIndex == 1;
                final t = isSecondary ? widget.secondaryType! : widget.type;
                final day = widget.points[
                        i < widget.points.length
                            ? i
                            : widget.points.length - 1]
                    .day;
                return LineTooltipItem(
                  isSecondary ? '' : Fmt.dateShort(day),
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    TextSpan(
                      text: '\n${Fmt.metricValue(t, spot.y)} ${t.unit}',
                      style: TextStyle(
                        color: t.color,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is! FlTapUpEvent) return;
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) {
              setState(() => _selectedLineIndex = null);
              return;
            }
            final tappedX = spots.first.x.toInt();
            setState(() {
              _selectedLineIndex =
                  tappedX == _selectedLineIndex ? null : tappedX;
            });
          },
        ),
        lineBarsData: lineBarsData,
      ),
    );
  }

  LineChartBarData _lineBar(
    List<DailyPoint> pts,
    Color color, {
    bool dashed = false,
  }) =>
      LineChartBarData(
        spots: [
          // Days with no reading aggregate to 0; render them as gaps (nullSpot)
          // rather than plotting a point at y=0 that dives off the chart. The
          // list stays one-entry-per-day so x indices align with the labels.
          for (var i = 0; i < pts.length; i++)
            pts[i].value > 0
                ? FlSpot(i.toDouble(), pts[i].value)
                : FlSpot.nullSpot,
        ],
        isCurved: true,
        // Keep the spline from shooting past the first/last point (the steep
        // dive below the axis) now that clipping no longer hides it.
        preventCurveOverShooting: true,
        color: color,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
            radius: 3.r,
            color: color,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          ),
        ),
        dashArray: dashed ? [6, 4] : null,
        belowBarData: dashed
            ? BarAreaData(show: false)
            : BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.10),
              ),
      );
}