import 'dart:math' as math;
import '../models/analytics_result.dart';

/// Generates Best / Base / Worst 3-month scenarios from Holt's forecast.
/// Sensitivity table: net at ±5%, ±10%, ±20% revenue.
class ScenarioService {
  const ScenarioService();

  ScenarioResult compute(
    ForecastResult forecast,
    double dailyBurnRate,
  ) {
    final baseIncome = forecast.forecast.fold(0.0, (s, p) => s + p.income);
    final baseExpense = forecast.forecast.fold(0.0, (s, p) => s + p.expense);

    final safeIncome = baseIncome <= 0 ? 1.0 : baseIncome;
    final safeExpense = baseExpense <= 0 ? 1.0 : baseExpense;
    final burnRate = math.max(dailyBurnRate, 1.0);

    ScenarioCase make(
        String name, String tag, double incFactor, double expFactor) {
      final inc = safeIncome * incFactor;
      final exp = safeExpense * expFactor;
      final net = inc - exp;
      final runway = net >= 0 ? (net / (burnRate * 30)).clamp(0.0, 999.0) : 0.0;
      return ScenarioCase(
        name: name,
        income3m: inc,
        expense3m: exp,
        runway: runway,
        colorTag: tag,
      );
    }

    final base = make('Base', 'base', 1.0, 1.0);
    final best = make('Best', 'best', 1.15, 0.85);
    final worst = make('Worst', 'worst', 0.70, 1.30);

    final sensitivity = <String, double>{
      '-20%': safeIncome * 0.80 - safeExpense,
      '-10%': safeIncome * 0.90 - safeExpense,
      '-5%': safeIncome * 0.95 - safeExpense,
      'Base': safeIncome - safeExpense,
      '+5%': safeIncome * 1.05 - safeExpense,
      '+10%': safeIncome * 1.10 - safeExpense,
      '+20%': safeIncome * 1.20 - safeExpense,
    };

    return ScenarioResult(
      best: best,
      base: base,
      worst: worst,
      sensitivityNet: sensitivity,
    );
  }
}
