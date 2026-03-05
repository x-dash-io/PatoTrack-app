import 'package:flutter/foundation.dart';

import '../../../helpers/database_helper.dart';
import '../models/compliance_result.dart';
import '../services/compliance_service.dart';

class ComplianceController extends ChangeNotifier {
  ComplianceController({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  final DatabaseHelper _dbHelper;
  final _service = const ComplianceService();

  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;
  ComplianceResult? _result;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ComplianceResult? get result => _result;

  Future<void> initialize(String userId) async {
    if (_initialized) return;
    _initialized = true;
    await refresh(userId);
  }

  Future<void> refresh(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final txns = await _dbHelper.getTransactions(userId);
      // Use 90-day window
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final filtered = txns.where((t) {
        try {
          return DateTime.parse(t.date).isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();

      _result = _service.compute(filtered, 90);
    } catch (e) {
      _errorMessage = 'Could not compute compliance score.';
      debugPrint('ComplianceController error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
