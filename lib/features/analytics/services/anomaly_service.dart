import 'dart:math' as math;
import '../../../models/transaction.dart' as model;
import '../models/analytics_result.dart';

/// Anomaly detection using Z-score + IQR hybrid.
/// Z-score: flags absolute outliers (assumes ~normal distribution).
/// IQR:     flags outliers in skewed distributions.
/// Union of both passes — deduplication by transaction id.
class AnomalyService {
  const AnomalyService();

  static const double _zThreshold = 2.5;
  static const double _iqrMultiplier = 1.5;

  List<AnomalyFlag> detect(List<model.Transaction> transactions) {
    if (transactions.length < 4) return [];

    final amounts = transactions.map((t) => t.amount).toList();

    // ── Z-score pass ──────────────────────────────────────────────────────
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final variance =
        amounts.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) /
            amounts.length;
    final stddev = math.sqrt(variance);

    final Set<String> flaggedIds = {};
    final List<AnomalyFlag> flags = [];

    if (stddev > 0) {
      for (final t in transactions) {
        final z = (t.amount - mean) / stddev;
        if (z.abs() > _zThreshold) {
          final id = '${t.id}-${t.date}';
          if (flaggedIds.add(id)) {
            flags.add(AnomalyFlag(
              transaction: t,
              zScore: z,
              reason:
                  z > 0 ? AnomalyReason.highAmount : AnomalyReason.lowAmount,
            ));
          }
        }
      }
    }

    // ── IQR pass ──────────────────────────────────────────────────────────
    final sorted = List<double>.from(amounts)..sort();
    final q1 = _percentile(sorted, 25);
    final q3 = _percentile(sorted, 75);
    final iqr = q3 - q1;
    final lowerFence = q1 - _iqrMultiplier * iqr;
    final upperFence = q3 + _iqrMultiplier * iqr;

    for (final t in transactions) {
      if (t.amount > upperFence || t.amount < lowerFence) {
        final id = '${t.id}-${t.date}';
        if (flaggedIds.add(id)) {
          final z = stddev > 0 ? (t.amount - mean) / stddev : 0.0;
          flags.add(AnomalyFlag(
            transaction: t,
            zScore: z.toDouble(),
            reason: t.amount > upperFence
                ? AnomalyReason.highAmount
                : AnomalyReason.lowAmount,
          ));
        }
      }
    }

    // ── Temporal: daily transaction count spike ────────────────────────────
    final Map<String, List<model.Transaction>> byDay = {};
    for (final t in transactions) {
      final dt = _parseDate(t.date);
      final key = '${dt.year}-${dt.month}-${dt.day}';
      byDay.putIfAbsent(key, () => []).add(t);
    }
    final dailyCounts = byDay.values.map((list) => list.length).toList();
    if (dailyCounts.length >= 3) {
      final medianCount =
          _median(dailyCounts.map((c) => c.toDouble()).toList());
      for (final entry in byDay.entries) {
        if (entry.value.length > medianCount * 3) {
          for (final t in entry.value) {
            final id = '${t.id}-${t.date}';
            if (flaggedIds.add(id)) {
              flags.add(AnomalyFlag(
                transaction: t,
                zScore: 0,
                reason: AnomalyReason.dailySpike,
              ));
            }
          }
        }
      }
    }

    // Return top 10 by absolute z-score
    flags.sort((a, b) => b.zScore.abs().compareTo(a.zScore.abs()));
    return flags.take(10).toList();
  }

  double _percentile(List<double> sorted, int pct) {
    final idx = (pct / 100) * (sorted.length - 1);
    final lower = sorted[idx.floor()];
    final upper = sorted[idx.ceil()];
    return lower + (upper - lower) * (idx - idx.floor());
  }

  double _median(List<double> sorted) {
    final n = sorted.length;
    if (n == 0) return 0;
    final s = List<double>.from(sorted)..sort();
    if (n.isOdd) return s[n ~/ 2];
    return (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  DateTime _parseDate(String iso) {
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return DateTime.now();
    }
  }
}
