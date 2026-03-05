import 'dart:math' as math;
import '../models/advice_models.dart';

/// Pure financial modeling — no I/O.
/// All 4 what-if scenarios use the user's current monthly averages as base.
class WhatIfService {
  const WhatIfService();

  // ── Public API: compute for a specific type + parameter ──────────────────

  WhatIfResult compute({
    required WhatIfType type,
    required double paramValue,
    required double monthlyIncome,
    required double monthlyExpense,
    required double burnRate,        // per day
    required double currentBalance,  // income - expense YTD
  }) {
    final baseRunway = burnRate > 0
        ? (currentBalance / burnRate).clamp(0.0, 9999.0)
        : 999.0;

    switch (type) {
      case WhatIfType.hireStaff:
        return _hireStaff(paramValue, monthlyIncome, monthlyExpense,
            burnRate, currentBalance, baseRunway);
      case WhatIfType.priceChange:
        return _priceChange(paramValue, monthlyIncome, monthlyExpense,
            burnRate, currentBalance, baseRunway);
      case WhatIfType.loanProceeds:
        return _loanProceeds(paramValue, monthlyIncome, monthlyExpense,
            burnRate, currentBalance, baseRunway);
      case WhatIfType.majorClient:
        return _majorClient(paramValue, monthlyIncome, monthlyExpense,
            burnRate, currentBalance, baseRunway);
    }
  }

  // ── Hire Staff ──────────────────────────────────────────────────────────

  WhatIfResult _hireStaff(
    double salary,
    double income,
    double expense,
    double burnRate,
    double balance,
    double baseRunway,
  ) {
    // Extra expense over 3 months
    const months = 3;
    final extraExpense3m = salary * months;
    final newExpense3m = (expense + salary) * months;
    final newIncome3m = income * months;
    final newNet = newIncome3m - newExpense3m;

    // New burn rate
    final newBurnRate = math.max((expense + salary) / 30, 1.0);
    final newBalance = balance + newNet - (income * months - expense * months);
    final newRunway = newBurnRate > 0
        ? (newBalance / newBurnRate).clamp(0.0, 9999.0)
        : baseRunway;

    // Break-even: how many months of extra sales needed to cover salary
    final breakEvenMonths = income > 0
        ? (salary / (income * 0.2)).ceil() // assume 20% margin on incremental
        : 0;

    return WhatIfResult(
      type: WhatIfType.hireStaff,
      paramValue: salary,
      deltaIncome3m: 0,
      deltaExpense3m: extraExpense3m,
      baseRunway: baseRunway,
      newRunway: newRunway,
      summary: 'Adding a ${_fmt(salary)}/mo employee increases your 3-month '
          'costs by ${_fmt(extraExpense3m)} and brings runway from '
          '${baseRunway.toInt()}d to ${newRunway.toInt()}d.',
      breakEvenNote: 'At a 20% margin, you need ~$breakEvenMonths months of '
          'incremental revenue to cover this hire.',
    );
  }

  // ── Price Change ────────────────────────────────────────────────────────

  WhatIfResult _priceChange(
    double pctChange,   // e.g. 10 means +10%
    double income,
    double expense,
    double burnRate,
    double balance,
    double baseRunway,
  ) {
    final factor = 1 + pctChange / 100;
    final newMonthlyIncome = income * factor;
    final deltaIncome3m = (newMonthlyIncome - income) * 3;

    final newBalance = balance + deltaIncome3m;
    final newRunway = burnRate > 0
        ? (newBalance / burnRate).clamp(0.0, 9999.0)
        : baseRunway;

    final direction = pctChange >= 0 ? 'raise' : 'cut';
    final sign = pctChange >= 0 ? '+' : '';

    return WhatIfResult(
      type: WhatIfType.priceChange,
      paramValue: pctChange,
      deltaIncome3m: deltaIncome3m,
      deltaExpense3m: 0,
      baseRunway: baseRunway,
      newRunway: newRunway,
      summary: 'A $sign${pctChange.toStringAsFixed(0)}% price $direction '
          'yields ${_fmt(deltaIncome3m.abs())} '
          '${pctChange >= 0 ? 'extra' : 'less'} income over 3 months, '
          'moving runway to ${newRunway.toInt()}d.',
      breakEvenNote: income > 0 && pctChange > 0
          ? 'Assumes same sales volume. A 5% drop in volume would offset a '
              '${(5 * income * 0.01 / (income * pctChange / 100) * 100).toStringAsFixed(0)}% price increase.'
          : null,
    );
  }

  // ── Loan Proceeds ───────────────────────────────────────────────────────

  WhatIfResult _loanProceeds(
    double loanAmount,
    double income,
    double expense,
    double burnRate,
    double balance,
    double baseRunway,
  ) {
    // Assume 12-month repayment at 15% annual flat rate
    const months = 12;
    const annualRate = 0.15;
    final totalRepayable = loanAmount * (1 + annualRate);
    final monthlyRepayment = totalRepayable / months;

    // 3-month window: income +loanAmount (upfront injection), then repayments
    final deltaIncome3m = loanAmount; // cash injection in month 1
    final deltaExpense3m = monthlyRepayment * 3;

    final newBalance = balance + loanAmount - monthlyRepayment * 3;
    final newBurnRate = math.max((expense + monthlyRepayment) / 30, 1.0);
    final newRunway = newBurnRate > 0
        ? (newBalance / newBurnRate).clamp(0.0, 9999.0)
        : baseRunway;

    return WhatIfResult(
      type: WhatIfType.loanProceeds,
      paramValue: loanAmount,
      deltaIncome3m: deltaIncome3m,
      deltaExpense3m: deltaExpense3m,
      baseRunway: baseRunway,
      newRunway: newRunway,
      summary: 'A ${_fmt(loanAmount)} loan (15% flat, 12-month repayment) '
          'injects cash now but costs ${_fmt(monthlyRepayment)}/mo. '
          'Net runway change: ${baseRunway.toInt()}d → ${newRunway.toInt()}d.',
      breakEvenNote:
          'Total repayable: ${_fmt(totalRepayable)} (${_fmt(monthlyRepayment)}/mo × 12).',
    );
  }

  // ── Major Client ────────────────────────────────────────────────────────

  WhatIfResult _majorClient(
    double monthlyRevenue,
    double income,
    double expense,
    double burnRate,
    double balance,
    double baseRunway,
  ) {
    final deltaIncome3m = monthlyRevenue * 3;
    final newBalance = balance + deltaIncome3m;
    final newRunway = burnRate > 0
        ? (newBalance / burnRate).clamp(0.0, 9999.0)
        : baseRunway;

    // Revenue concentration: what % of income does this client represent?
    final concentrationPct = income > 0
        ? (monthlyRevenue / (income + monthlyRevenue) * 100).toStringAsFixed(0)
        : '100';

    return WhatIfResult(
      type: WhatIfType.majorClient,
      paramValue: monthlyRevenue,
      deltaIncome3m: deltaIncome3m,
      deltaExpense3m: 0,
      baseRunway: baseRunway,
      newRunway: newRunway,
      summary: 'Landing a client worth ${_fmt(monthlyRevenue)}/mo adds '
          '${_fmt(deltaIncome3m)} over 3 months and extends runway to '
          '${newRunway.toInt()}d.',
      breakEvenNote: 'This client would represent ~$concentrationPct% of '
          'total income — review concentration risk if >50%.',
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }
}
