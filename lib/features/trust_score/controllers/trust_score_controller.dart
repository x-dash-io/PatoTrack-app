import 'package:flutter/foundation.dart';
import '../../../helpers/database_helper.dart';
import '../../../models/transaction.dart' as model;
import '../models/trust_score_result.dart';
import '../services/trust_score_service.dart';

class TrustScoreController extends ChangeNotifier {
  TrustScoreController({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  final DatabaseHelper _dbHelper;
  final TrustScoreService _service = const TrustScoreService();

  bool _isLoading = true;
  bool _isInitialized = false;
  String? _errorMessage;
  TrustScoreResult? _result;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TrustScoreResult? get result => _result;

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh(userId);
  }

  Future<void> refresh(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<model.Transaction> transactions =
          await _dbHelper.getTransactions(userId);
      _result = _service.compute(transactions);
    } catch (e) {
      _errorMessage = 'Could not compute Trust Score. Pull down to retry.';
      debugPrint('TrustScoreController error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
