import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/bill.dart';
import '../models/transaction.dart' as model;
import '../models/category.dart';
import '../models/frequency.dart';

class CloudRestoreCancelledException implements Exception {
  const CloudRestoreCancelledException();

  @override
  String toString() => 'Cloud restore cancelled by user';
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _firestoreSyncTimeout = Duration(seconds: 8);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'PatoTrack.db');
    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        type TEXT NOT NULL DEFAULT 'expense',
        iconCodePoint INTEGER,
        colorValue INTEGER,
        userId TEXT NOT NULL,
        UNIQUE(name, userId, type)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        category_id INTEGER,
        userId TEXT NOT NULL,
        tag TEXT NOT NULL DEFAULT 'business',
        source TEXT NOT NULL DEFAULT 'manual',
        confidence REAL DEFAULT 1.0,
        is_reviewed INTEGER NOT NULL DEFAULT 1,
        balance_after REAL,
        receipt_image_url TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE bills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        userId TEXT NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrenceType TEXT,
        recurrenceValue INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS frequencies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        value INTEGER NOT NULL,
        displayName TEXT NOT NULL,
        userId TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_corrections(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        description TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE categories ADD COLUMN userId TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN userId TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE bills ADD COLUMN userId TEXT');
    }
    if (oldVersion < 4) {
      await db
          .execute('ALTER TABLE categories ADD COLUMN iconCodePoint INTEGER');
      await db.execute('ALTER TABLE categories ADD COLUMN colorValue INTEGER');
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE bills ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE bills ADD COLUMN recurrenceType TEXT');
      await db.execute('ALTER TABLE bills ADD COLUMN recurrenceValue INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN tag TEXT NOT NULL DEFAULT 'business'");
    }
    if (oldVersion < 7) {
      await db.execute(
          "ALTER TABLE categories ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'");
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS frequencies(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          value INTEGER NOT NULL,
          displayName TEXT NOT NULL,
          userId TEXT NOT NULL
        )
      ''');
      // Insert default frequencies for all users
      await _insertDefaultFrequencies(db);
    }
    if (oldVersion < 9) {
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'");
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN confidence REAL DEFAULT 1.0");
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN is_reviewed INTEGER NOT NULL DEFAULT 1");
      await db
          .execute("ALTER TABLE transactions ADD COLUMN balance_after REAL");
    }
    if (oldVersion < 10) {
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN receipt_image_url TEXT");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_corrections(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT NOT NULL,
          description TEXT NOT NULL,
          category_id INTEGER NOT NULL,
          category_name TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _insertDefaultFrequencies(Database db) async {
    final defaultFrequencies = [
      {'name': 'Weekly', 'type': 'weekly', 'value': 7, 'displayName': 'Weekly'},
      {
        'name': 'Bi-weekly',
        'type': 'biweekly',
        'value': 14,
        'displayName': 'Bi-weekly'
      },
      {
        'name': 'Monthly',
        'type': 'monthly',
        'value': 30,
        'displayName': 'Monthly'
      },
      {
        'name': 'Quarterly',
        'type': 'quarterly',
        'value': 90,
        'displayName': 'Quarterly'
      },
      {
        'name': 'Yearly',
        'type': 'yearly',
        'value': 365,
        'displayName': 'Yearly'
      },
    ];

    // Get all unique user IDs from transactions
    final userMaps =
        await db.query('transactions', columns: ['userId'], distinct: true);
    final userIds = userMaps.map((map) => map['userId'] as String).toSet();

    // Add default frequencies for each user
    for (final userId in userIds) {
      for (final freq in defaultFrequencies) {
        await db.insert('frequencies', {
          ...freq,
          'userId': userId,
        });
      }
    }
  }

  // --- Transaction Functions ---
  Future<int> addTransaction(
      model.Transaction transaction, String userId) async {
    final db = await database;
    final map = transaction.toMap()..['userId'] = userId;
    map.remove('id'); // Let autoincrement handle it
    final newId = await db.insert('transactions', map);
    final docData = transaction.toMap()
      ..['id'] = newId
      ..['userId'] = userId;
    _enqueueFirestoreSync('addTransaction', () async {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(newId.toString())
          .set(docData);
    });
    return newId;
  }

  Future<List<model.Transaction>> getTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
    return List.generate(
        maps.length, (i) => model.Transaction.fromMap(maps[i]));
  }

  Future<List<model.Transaction>> getUnreviewedTransactions(
      String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions',
        where: 'userId = ? AND is_reviewed = 0',
        whereArgs: [userId],
        orderBy: 'date DESC');
    return List.generate(
        maps.length, (i) => model.Transaction.fromMap(maps[i]));
  }

  /// Returns existing SMS transaction within [windowHours] to detect duplicates.
  Future<model.Transaction?> getDuplicateSmsTransaction(
      String userId, double amount, String type,
      {int windowHours = 24}) async {
    final db = await database;
    final since =
        DateTime.now().subtract(Duration(hours: windowHours)).toIso8601String();
    final maps = await db.query(
      'transactions',
      where:
          'userId = ? AND source = ? AND amount = ? AND type = ? AND date >= ?',
      whereArgs: [userId, 'sms', amount, type, since],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return model.Transaction.fromMap(maps.first);
  }

  Future<List<model.Transaction>> getSmsTransactionsSince(
      String userId, DateTime since) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'userId = ? AND source = ? AND date >= ?',
      whereArgs: [userId, 'sms', since.toIso8601String()],
      orderBy: 'date DESC',
    );
    return List.generate(
        maps.length, (i) => model.Transaction.fromMap(maps[i]));
  }

  Future<int> markAsReviewed(int transactionId, String userId) async {
    final db = await database;
    final result = await db.update(
      'transactions',
      {'is_reviewed': 1},
      where: 'id = ? AND userId = ?',
      whereArgs: [transactionId, userId],
    );
    if (result == 0) {
      return result;
    }
    _enqueueFirestoreSync('markAsReviewed', () async {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId.toString())
          .update({'is_reviewed': 1});
    });
    return result;
  }

  // NEW: Function to update a transaction in both local DB and Firestore
  Future<int> updateTransaction(
      model.Transaction transaction, String userId) async {
    final db = await database;
    final result = await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [transaction.id, userId],
    );
    if (result == 0) {
      return result;
    }
    _enqueueFirestoreSync('updateTransaction', () async {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transaction.id.toString())
          .update(transaction.toMap());
    });
    return result;
  }

  Future<int> deleteTransaction(int id, String userId) async {
    final db = await database;
    final result = await db.delete('transactions',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    if (result == 0) {
      return result;
    }
    _enqueueFirestoreSync('deleteTransaction', () async {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(id.toString())
          .delete();
    });
    return result;
  }

  // --- Category Functions ---
  Future<int> addCategory(Category category, String userId) async {
    final db = await database;
    final map = category.toMap()..['userId'] = userId;
    final newId = await db.insert('categories', map,
        conflictAlgorithm: ConflictAlgorithm.ignore);
    if (newId != 0) {
      try {
        final docData = category.toMap()
          ..['id'] = newId
          ..['userId'] = userId;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(newId.toString())
            .set(docData);
      } catch (e) {
        developer.log('Firestore sync failed for addCategory: $e');
      }
    }
    return newId;
  }

  Future<int> updateCategory(Category category, String userId) async {
    final db = await database;
    final result = await db.update('categories', category.toMap(),
        where: 'id = ? AND userId = ?', whereArgs: [category.id, userId]);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(category.id.toString())
          .update(category.toMap());
    } catch (e) {
      developer.log('Firestore sync failed for updateCategory: $e');
    }
    return result;
  }

  Future<List<Category>> getCategories(String userId, {String? type}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (type != null) {
      maps = await db.query('categories',
          where: 'userId = ? AND type = ?',
          whereArgs: [userId, type],
          orderBy: 'name');
    } else {
      maps = await db.query('categories',
          where: 'userId = ?', whereArgs: [userId], orderBy: 'name');
    }
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> deleteCategory(int id, String userId) async {
    final db = await database;
    final result = await db.delete('categories',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(id.toString())
          .delete();
    } catch (e) {
      developer.log('Firestore sync failed for deleteCategory: $e');
    }
    return result;
  }

  Future<Category?> getCategoryByName(
      String name, String userId, String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories',
        where: 'name = ? AND userId = ? AND type = ?',
        whereArgs: [name, userId, type]);
    if (maps.isNotEmpty) return Category.fromMap(maps.first);
    return null;
  }

  Future<int> getOrCreateCategory(String name, String userId,
      {String type = 'expense'}) async {
    final existingCategory = await getCategoryByName(name, userId, type);
    if (existingCategory != null && existingCategory.id != null) {
      return existingCategory.id!;
    } else {
      final newCategory = Category(name: name, type: type);
      final newId = await addCategory(newCategory, userId);
      if (newId == 0) {
        final finalCategory = await getCategoryByName(name, userId, type);
        return finalCategory?.id ?? 0;
      }
      return newId;
    }
  }

  // --- Bill Functions ---
  Future<int> addBill(Bill bill, String userId) async {
    final db = await database;
    final newId = await db.insert('bills', bill.toMap()..['userId'] = userId);
    try {
      final docData = bill.toMap()
        ..['id'] = newId
        ..['userId'] = userId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .doc(newId.toString())
          .set(docData);
    } catch (e) {
      developer.log('Firestore sync failed for addBill: $e');
    }
    return newId;
  }

  Future<List<Bill>> getBills(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bills',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'dueDate ASC');
    return List.generate(maps.length, (i) => Bill.fromMap(maps[i]));
  }

  Future<int> deleteBill(int id, String userId) async {
    final db = await database;
    final result = await db.delete('bills',
        where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .doc(id.toString())
          .delete();
    } catch (e) {
      developer.log('Firestore sync failed for deleteBill: $e');
    }
    return result;
  }

  Future<int> updateBill(Bill bill, String userId) async {
    final db = await database;
    final billMap = bill.toMap()
      ..['userId'] = userId; // Ensure userId is included
    final result = await db.update('bills', billMap,
        where: 'id = ? AND userId = ?', whereArgs: [bill.id, userId]);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .doc(bill.id.toString())
          .update(billMap);
    } catch (e) {
      developer.log('Firestore sync failed for updateBill: $e');
    }
    return result;
  }

  Future<void> restoreFromFirestore(
    String userId, {
    bool Function()? shouldCancel,
  }) async {
    final db = await database;
    final userRef = _firestore.collection('users').doc(userId);

    if (shouldCancel?.call() == true) {
      throw const CloudRestoreCancelledException();
    }

    // Download remote data first so we never wipe local data on a fetch failure.
    final transactionSnap = await userRef.collection('transactions').get();
    if (shouldCancel?.call() == true) {
      throw const CloudRestoreCancelledException();
    }
    final categorySnap = await userRef.collection('categories').get();
    if (shouldCancel?.call() == true) {
      throw const CloudRestoreCancelledException();
    }
    final billSnap = await userRef.collection('bills').get();
    if (shouldCancel?.call() == true) {
      throw const CloudRestoreCancelledException();
    }
    final frequencySnap = await userRef.collection('frequencies').get();

    await db.transaction((txn) async {
      if (shouldCancel?.call() == true) {
        throw const CloudRestoreCancelledException();
      }
      // Replace local data only after all remote collections are available.
      await txn
          .delete('transactions', where: 'userId = ?', whereArgs: [userId]);
      await txn.delete('categories', where: 'userId = ?', whereArgs: [userId]);
      await txn.delete('bills', where: 'userId = ?', whereArgs: [userId]);
      await txn.delete('frequencies', where: 'userId = ?', whereArgs: [userId]);

      for (final doc in transactionSnap.docs) {
        if (shouldCancel?.call() == true) {
          throw const CloudRestoreCancelledException();
        }
        await txn.insert(
          'transactions',
          _normalizeFirestoreDoc(doc, userId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final doc in categorySnap.docs) {
        if (shouldCancel?.call() == true) {
          throw const CloudRestoreCancelledException();
        }
        await txn.insert(
          'categories',
          _normalizeFirestoreDoc(doc, userId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final doc in billSnap.docs) {
        if (shouldCancel?.call() == true) {
          throw const CloudRestoreCancelledException();
        }
        await txn.insert(
          'bills',
          _normalizeFirestoreDoc(doc, userId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final doc in frequencySnap.docs) {
        if (shouldCancel?.call() == true) {
          throw const CloudRestoreCancelledException();
        }
        await txn.insert(
          'frequencies',
          _normalizeFirestoreDoc(doc, userId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteUserDataFromFirestore(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    await _deleteCollectionDocs(userRef.collection('transactions'));
    await _deleteCollectionDocs(userRef.collection('categories'));
    await _deleteCollectionDocs(userRef.collection('bills'));
    await _deleteCollectionDocs(userRef.collection('frequencies'));
  }

  Future<void> deleteAllUserData(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn
          .delete('transactions', where: 'userId = ?', whereArgs: [userId]);
      await txn.delete('categories', where: 'userId = ?', whereArgs: [userId]);
      await txn.delete('bills', where: 'userId = ?', whereArgs: [userId]);
      await txn.delete('frequencies', where: 'userId = ?', whereArgs: [userId]);
    });
  }

  Map<String, dynamic> _normalizeFirestoreDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String userId,
  ) {
    final data = Map<String, dynamic>.from(doc.data());
    data['userId'] = userId;
    data['id'] ??= int.tryParse(doc.id);
    return data;
  }

  Future<void> _deleteCollectionDocs(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    const chunkSize = 400;
    for (var i = 0; i < snapshot.docs.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = (i + chunkSize > snapshot.docs.length)
          ? snapshot.docs.length
          : i + chunkSize;
      for (final doc in snapshot.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // --- Frequency Functions ---
  Future<List<Frequency>> getFrequencies(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'frequencies',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'value ASC',
    );

    // If no frequencies found, create default ones
    if (maps.isEmpty) {
      await _initializeDefaultFrequencies(userId);
      // Query again after initialization
      final List<Map<String, dynamic>> updatedMaps = await db.query(
        'frequencies',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'value ASC',
      );
      return List.generate(
          updatedMaps.length, (i) => Frequency.fromMap(updatedMaps[i]));
    }

    return List.generate(maps.length, (i) => Frequency.fromMap(maps[i]));
  }

  Future<void> _initializeDefaultFrequencies(String userId) async {
    final defaultFrequencies = [
      {'name': 'Weekly', 'type': 'weekly', 'value': 7, 'displayName': 'Weekly'},
      {
        'name': 'Bi-weekly',
        'type': 'biweekly',
        'value': 14,
        'displayName': 'Bi-weekly'
      },
      {
        'name': 'Monthly',
        'type': 'monthly',
        'value': 30,
        'displayName': 'Monthly'
      },
      {
        'name': 'Quarterly',
        'type': 'quarterly',
        'value': 90,
        'displayName': 'Quarterly'
      },
      {
        'name': 'Yearly',
        'type': 'yearly',
        'value': 365,
        'displayName': 'Yearly'
      },
    ];

    for (final freq in defaultFrequencies) {
      final freqObj = Frequency(
        name: freq['name'] as String,
        type: freq['type'] as String,
        value: freq['value'] as int,
        displayName: freq['displayName'] as String,
        userId: userId,
      );
      await addFrequency(freqObj, userId);
    }
  }

  Future<int> addFrequency(Frequency frequency, String userId) async {
    final db = await database;
    final newId =
        await db.insert('frequencies', frequency.toMap()..['userId'] = userId);
    try {
      final docData = frequency.toMap()
        ..['id'] = newId
        ..['userId'] = userId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('frequencies')
          .doc(newId.toString())
          .set(docData);
    } catch (e) {
      developer.log('Firestore sync failed for addFrequency: $e');
    }
    return newId;
  }

  Future<int> updateFrequency(Frequency frequency, String userId) async {
    final db = await database;
    final result = await db.update(
      'frequencies',
      frequency.toMap()..['userId'] = userId,
      where: 'id = ? AND userId = ?',
      whereArgs: [frequency.id, userId],
    );
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('frequencies')
          .doc(frequency.id.toString())
          .update(frequency.toMap());
    } catch (e) {
      developer.log('Firestore sync failed for updateFrequency: $e');
    }
    return result;
  }

  Future<int> deleteFrequency(int id, String userId) async {
    final db = await database;
    final result = await db.delete(
      'frequencies',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('frequencies')
          .doc(id.toString())
          .delete();
    } catch (e) {
      developer.log('Firestore sync failed for deleteFrequency: $e');
    }
    return result;
  }

  // --- Category Correction Functions (Tier 2 Learning) ---
  Future<void> addUserCategoryCorrection({
    required String userId,
    required String description,
    required int categoryId,
    required String categoryName,
  }) async {
    final db = await database;
    await db.insert('category_corrections', {
      'userId': userId,
      'description': description.toLowerCase().trim(),
      'category_id': categoryId,
      'category_name': categoryName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUserCategoryCorrections(
      String userId) async {
    final db = await database;
    return db.query(
      'category_corrections',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }

  void _enqueueFirestoreSync(
    String operation,
    Future<void> Function() task,
  ) {
    unawaited(_runFirestoreSync(operation, task));
  }

  Future<void> _runFirestoreSync(
    String operation,
    Future<void> Function() task,
  ) async {
    try {
      await task().timeout(_firestoreSyncTimeout);
    } catch (e, stackTrace) {
      developer.log(
        'Firestore sync failed for $operation',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
