import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/transaction_model.dart';

/// Thin wrapper around the MoneyTrack Flask REST API.
///
/// Update [baseUrl] to point at your deployed backend
/// (e.g. your Render URL) or `http://10.0.2.2:5000` for
/// the Android emulator talking to a local Flask server.
class ApiService {
  ApiService({this.baseUrl = 'http://10.0.2.2:5000'});

  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<TransactionModel>> getTransactions() async {
    final response = await http.get(_uri('/transactions'));
    _ensureOk(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionModel> createTransaction(TransactionModel tx) async {
    final response = await http.post(
      _uri('/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(tx.toRequestJson()),
    );
    _ensureOk(response, expected: 201);
    return TransactionModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(int id) async {
    final response = await http.delete(_uri('/transactions/$id'));
    _ensureOk(response);
  }

  Future<TransactionModel> updateTransaction(TransactionModel tx) async {
    if (tx.id == null) {
      throw ApiException('Transaction id is required for update.', statusCode: 400);
    }
    final response = await http.put(
      _uri('/transactions/${tx.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(tx.toRequestJson()),
    );
    _ensureOk(response);
    return TransactionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<TransactionModel>> searchTransactions(String query) async {
    final response = await http.get(
      _uri('/transactions/search/${Uri.encodeComponent(query.trim())}'),
    );
    _ensureOk(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<double> getTotalIncome() async {
    final response = await http.get(_uri('/total_income'));
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['total_income'] as num).toDouble();
  }

  Future<double> getTotalExpenses() async {
    final response = await http.get(_uri('/total_expenses'));
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['total_expenses'] as num).toDouble();
  }

  Future<double> getNetBalance() async {
    final response = await http.get(_uri('/net_balance'));
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['net_balance'] as num).toDouble();
  }

  Future<double> getTotalIncomeByName(String transactionName) async {
    final response = await http.get(
      _uri('/total_income_by_name/${Uri.encodeComponent(transactionName.trim())}'),
    );
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['total_income'] as num).toDouble();
  }

  Future<double> getTotalExpensesByName(String transactionName) async {
    final response = await http.get(
      _uri('/total_expenses_by_name/${Uri.encodeComponent(transactionName.trim())}'),
    );
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['total_expenses'] as num).toDouble();
  }

  Future<double> getNetBalanceByName(String transactionName) async {
    final response = await http.get(
      _uri('/net_balance_by_name/${Uri.encodeComponent(transactionName.trim())}'),
    );
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['net_balance'] as num).toDouble();
  }

  void _ensureOk(http.Response response, {int expected = 200}) {
    if (response.statusCode != expected) {
      String message = 'Request failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['error'] != null) message = body['error'] as String;
      } catch (_) {
        // response wasn't JSON; keep default message
      }
      throw ApiException(message, statusCode: response.statusCode);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message, {required this.statusCode});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
