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
    // Sum base 3-month projections
    final baseIncome =
        forecast.forecast.fold(0.0, (s, p) => s + p.income);
    final baseExpense =
        forecast.forecast.fold(0.0, (s, p) => s + p.expense);

    // Fallback if no forecast data
    final safeIncome = baseIncome <= 0 ? 1.0 : baseIncome;
    final safeExpense = baseExpense <= 0 ? 1.0 : baseExpense;

    final burnRate = math.max(dailyBurnRate, 1.0);

    ScenarioCase make(String name, double incomeFactor, double expenseFactor) {
      final inc = safeIncome * incomeFactor;
      final exp = safeExpense * expenseFactor;
      final net = inc - exp;
      final runway = net >= 0 ? (net / (burnRate * 30)).clamp(0, 999) : 0.0;
      return ScenarioCase(
        name: name,
        income3m: inc,
        expense3m: exp,
        runway: runway,
        color: _colorForName(name),
      );
    }

    final base = make('Base', 1.0, 1.0);
    final best = make('Best', 1.15, 0.85);
    final worst = make('Worst', 0.70, 1.30);

    // Sensitivity: net at revenue ±5/±10/±20
    final sensitivity = <String, double>{
      '-20%': (safeIncome * 0.80 - safeExpense),
      '-10%': (safeIncome * 0.90 - safeExpense),
      '-5%': (safeIncome * 0.95 - safeExpense),
      'Base': (safeIncome - safeExpense),
      '+5%': (safeIncome * 1.05 - safeExpense),
      '+10%': (safeIncome * 1.10 - safeExpense),
      '+20%': (safeIncome * 1.20 - safeExpense),
    };

    return ScenarioResult(
      best: best,
      base: base,
      worst: worst,
      sensitivityNet: sensitivity,
    );
  }

  // Color tags — decoded in the UI without importing flutter here
  // We embed a simple string tag in the name itself
  ScenarioCase _makeWithTag(
      String name, double inc, double exp, double runway) {
    return ScenarioCase(
      name: name,
      income3m: inc,
      expense3m: exp,
      runway: runway,
      color: _colorForName(name),
    );
  }

  // ignore: unused_element
  ScenarioCase _unused(double inc, double exp, double runway, String name) =>
      _makeWithTag(name, inc, exp, runway);

  // We stub color via importing it from Flutter — ScenarioCase takes a Color
  // so we just use a placeholder that the UI layer will override
  dynamic _colorForName(String name) {
    // Actual colors set in the screen, not here (pure service)
    return null;
  }
}
