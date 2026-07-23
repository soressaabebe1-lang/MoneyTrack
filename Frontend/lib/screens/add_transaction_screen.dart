import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.apiService,
    required this.isIncome,
    this.transaction,
  });

  final ApiService apiService;
  final bool isIncome;
  final TransactionModel? transaction;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _occurredAt = DateTime.now();
  bool _submitting = false;
  String? _errorMessage;
  String _calculatorExpression = '';

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _nameController.text = tx.name;
      _reasonController.text = tx.reason;
      _amountController.text = tx.isIncome
          ? tx.income.toStringAsFixed(2)
          : tx.expenses.toStringAsFixed(2);
      _occurredAt = tx.occurredAt;
      _calculatorExpression = _amountController.text;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final amount = double.parse(_amountController.text.trim());
    final tx = TransactionModel(
      id: widget.transaction?.id,
      name: _nameController.text.trim(),
      reason: _reasonController.text.trim(),
      income: widget.isIncome ? amount : 0.0,
      expenses: widget.isIncome ? 0.0 : amount,
      occurredAt: _occurredAt,
    );

    try {
      if (_isEdit) {
        await widget.apiService.updateTransaction(tx);
      } else {
        await widget.apiService.createTransaction(tx);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _submitting = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null) return;
    setState(() {
      _occurredAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (selectedTime == null) return;
    setState(() {
      _occurredAt = DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _delete() async {
    if (!_isEdit || widget.transaction?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expenseRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.deleteTransaction(widget.transaction!.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _submitting = false;
      });
    }
  }

  /// Evaluates mathematical expressions including implicit multiplication e.g. 5(2) -> 5*2
  double? _calculateExpression(String expression) {
    if (expression.trim().isEmpty) return null;
    final sanitized = expression.replaceAll('×', '*').replaceAll('÷', '/');

    final regExp = RegExp(r'(\d*\.?\d+|[+\-*/()])');
    final rawTokens = regExp
        .allMatches(sanitized)
        .map((m) => m.group(0)!)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) return null;

    // Preprocess tokens to insert implicit '*' operators
    final tokens = <String>[];
    for (int i = 0; i < rawTokens.length; i++) {
      final current = rawTokens[i];
      tokens.add(current);

      if (i < rawTokens.length - 1) {
        final next = rawTokens[i + 1];

        final isCurrentNumOrClose =
            double.tryParse(current) != null || current == ')';
        final isNextNumOrOpen =
            double.tryParse(next) != null || next == '(';

        // Pattern 1: Number or ')' followed by '(' -> 5(2) => 5*(2) or (2)(3) => (2)*(3)
        // Pattern 2: ')' followed by a Number -> (2)5 => (2)*5
        if ((isCurrentNumOrClose && next == '(') ||
            (current == ')' && isNextNumOrOpen)) {
          tokens.add('*');
        }
      }
    }

    try {
      final parser = _CalculatorParser(tokens);
      final total = parser.parseExpression();
      return total.isFinite ? total : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openCalculatorSheet() async {
    final accentColor =
        widget.isIncome ? AppColors.incomeGreen : AppColors.expenseRed;
    var expression = _calculatorExpression;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          void updateExpression(String value) {
            if (value == 'C') {
              expression = '';
            } else if (value == '⌫') {
              if (expression.isNotEmpty) {
                expression = expression.substring(0, expression.length - 1);
              }
            } else {
              expression += value;
            }
            setModalState(() {});
          }

          void evaluate() {
            final result = _calculateExpression(expression);
            if (result != null) {
              expression = result.toStringAsFixed(2);
              if (expression.endsWith('.00')) {
                expression = expression.substring(0, expression.length - 3);
              }
              _amountController.text = expression;
              _calculatorExpression = expression;
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid mathematical expression'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }

          Widget buildKey(String key, {bool isAccent = false, int flex = 1}) {
            return Expanded(
              flex: flex,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (key == '=') {
                      evaluate();
                    } else {
                      updateExpression(key);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isAccent ? accentColor : Colors.transparent,
                    foregroundColor: isAccent
                        ? Colors.white
                        : Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white24
                          : Colors.black26,
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      expression.isEmpty ? '0' : expression,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  buildKey('C'),
                  buildKey('('),
                  buildKey(')'),
                  buildKey('÷'),
                ]),
                Row(children: [
                  buildKey('7'),
                  buildKey('8'),
                  buildKey('9'),
                  buildKey('×'),
                ]),
                Row(children: [
                  buildKey('4'),
                  buildKey('5'),
                  buildKey('6'),
                  buildKey('-'),
                ]),
                Row(children: [
                  buildKey('1'),
                  buildKey('2'),
                  buildKey('3'),
                  buildKey('+'),
                ]),
                Row(children: [
                  buildKey('0'),
                  buildKey('.'),
                  buildKey('⌫'),
                  buildKey('=', isAccent: true),
                ]),
                const SizedBox(height: 12),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor =
        widget.isIncome ? AppColors.incomeGreen : AppColors.expenseRed;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? 'Edit ${widget.isIncome ? 'Income' : 'Expense'}'
            : widget.isIncome
                ? 'Add Income'
                : 'Add Expense'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.expenseRed,
              tooltip: 'Delete transaction',
              onPressed: _submitting ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    widget.isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: accentColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Freelance client, Grocery store',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reasonController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Category',
                    hintText: 'e.g. Salary, Groceries, Rent',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Reason is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  readOnly: true,
                  onTap: _openCalculatorSheet,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                    hintText: 'Tap to open calculator',
                    suffixIcon: Icon(Icons.calculate_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid positive amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: Text(DateFormat('MMM d, yyyy').format(_occurredAt)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: Text(DateFormat('h:mm a').format(_occurredAt)),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.expenseRed),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isIncome ? 'Save Income' : 'Save Expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalculatorParser {
  final List<String> tokens;
  int index = 0;

  _CalculatorParser(this.tokens);

  double parseExpression() {
    double result = parseTerm();
    while (index < tokens.length) {
      final op = tokens[index];
      if (op == '+' || op == '-') {
        index++;
        final nextTerm = parseTerm();
        if (op == '+') result += nextTerm;
        if (op == '-') result -= nextTerm;
      } else {
        break;
      }
    }
    return result;
  }

  double parseTerm() {
    double result = parseFactor();
    while (index < tokens.length) {
      final op = tokens[index];
      if (op == '*' || op == '/') {
        index++;
        final nextFactor = parseFactor();
        if (op == '*') result *= nextFactor;
        if (op == '/') {
          if (nextFactor == 0) throw Exception('Division by zero');
          result /= nextFactor;
        }
      } else {
        break;
      }
    }
    return result;
  }

  double parseFactor() {
    if (index >= tokens.length) throw Exception('Unexpected end');
    final token = tokens[index];

    if (token == '-') {
      index++;
      return -parseFactor();
    } else if (token == '+') {
      index++;
      return parseFactor();
    }

    if (token == '(') {
      index++;
      final result = parseExpression();
      if (index < tokens.length && tokens[index] == ')') {
        index++;
      }
      return result;
    }

    final val = double.tryParse(token);
    if (val == null) throw Exception('Invalid token: $token');
    index++;
    return val;
  }
}