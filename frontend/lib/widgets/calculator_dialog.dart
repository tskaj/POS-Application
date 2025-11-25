import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _display = '0';
  String _expression = '';
  String _previousValue = '';
  String _operation = '';
  bool _isNewValue = true;
  late FocusNode _focusNode;

  void _onNumberPressed(String number) {
    setState(() {
      if (_isNewValue) {
        _display = number;
        _isNewValue = false;
      } else {
        if (_display == '0') {
          _display = number;
        } else {
          _display += number;
        }
      }
      _updateExpression();
    });
  }

  void _onOperationPressed(String operation) {
    setState(() {
      if (_previousValue.isNotEmpty && !_isNewValue) {
        _calculate();
      }
      _previousValue = _display;
      _operation = operation;
      _isNewValue = true;
      _updateExpression();
    });
  }

  void _updateExpression() {
    if (_previousValue.isNotEmpty && _operation.isNotEmpty && !_isNewValue) {
      _expression = '$_previousValue $_operation $_display';
    } else if (_previousValue.isNotEmpty &&
        _operation.isNotEmpty &&
        _isNewValue) {
      _expression = '$_previousValue $_operation';
    } else {
      _expression = _display;
    }
  }

  void _calculate() {
    double result = 0;
    double prev = double.tryParse(_previousValue) ?? 0;
    double current = double.tryParse(_display) ?? 0;

    switch (_operation) {
      case '+':
        result = prev + current;
        break;
      case '-':
        result = prev - current;
        break;
      case '×':
        result = prev * current;
        break;
      case '÷':
        if (current != 0) {
          result = prev / current;
        } else {
          _display = 'Error';
          _expression = 'Error';
          return;
        }
        break;
    }

    _display = _formatResult(result);
    _expression = _display;
    _previousValue = '';
    _operation = '';
  }

  String _formatResult(double result) {
    if (result == result.toInt()) {
      return result.toInt().toString();
    } else {
      return result.toStringAsFixed(2);
    }
  }

  void _onEqualsPressed() {
    setState(() {
      if (_previousValue.isNotEmpty && _operation.isNotEmpty) {
        _calculate();
        _isNewValue = true;
      }
    });
  }

  void _onClearPressed() {
    setState(() {
      _display = '0';
      _expression = '';
      _previousValue = '';
      _operation = '';
      _isNewValue = true;
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
        _isNewValue = true;
      }
      _updateExpression();
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (_isNewValue) {
        _display = '0.';
        _isNewValue = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
      _updateExpression();
    });
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;

      // Enter / Numpad Enter -> equals
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _onEqualsPressed();
        return;
      }

      // Backspace -> backspace
      if (key == LogicalKeyboardKey.backspace) {
        _onBackspacePressed();
        return;
      }

      // Delete -> clear
      if (key == LogicalKeyboardKey.delete) {
        _onClearPressed();
        return;
      }

      // Numpad digits
      if (key == LogicalKeyboardKey.numpad0) {
        _onNumberPressed('0');
        return;
      }
      if (key == LogicalKeyboardKey.numpad1) {
        _onNumberPressed('1');
        return;
      }
      if (key == LogicalKeyboardKey.numpad2) {
        _onNumberPressed('2');
        return;
      }
      if (key == LogicalKeyboardKey.numpad3) {
        _onNumberPressed('3');
        return;
      }
      if (key == LogicalKeyboardKey.numpad4) {
        _onNumberPressed('4');
        return;
      }
      if (key == LogicalKeyboardKey.numpad5) {
        _onNumberPressed('5');
        return;
      }
      if (key == LogicalKeyboardKey.numpad6) {
        _onNumberPressed('6');
        return;
      }
      if (key == LogicalKeyboardKey.numpad7) {
        _onNumberPressed('7');
        return;
      }
      if (key == LogicalKeyboardKey.numpad8) {
        _onNumberPressed('8');
        return;
      }
      if (key == LogicalKeyboardKey.numpad9) {
        _onNumberPressed('9');
        return;
      }

      // Numpad decimal
      if (key == LogicalKeyboardKey.numpadDecimal) {
        _onDecimalPressed();
        return;
      }

      // Numpad operations
      if (key == LogicalKeyboardKey.numpadAdd) {
        _onOperationPressed('+');
        return;
      }
      if (key == LogicalKeyboardKey.numpadSubtract) {
        _onOperationPressed('-');
        return;
      }
      if (key == LogicalKeyboardKey.numpadMultiply) {
        _onOperationPressed('×');
        return;
      }
      if (key == LogicalKeyboardKey.numpadDivide) {
        _onOperationPressed('÷');
        return;
      }

      // Fallback: regular keys (top row)
      final label = key.keyLabel;
      if (label.isEmpty) return;

      // Digits: take first trimmed char and check if it's numeric
      final trimmed = label.trim();
      if (trimmed.isNotEmpty) {
        final ch = trimmed[0];
        if (int.tryParse(ch) != null) {
          _onNumberPressed(ch);
          return;
        }
      }

      // Decimal point
      if (label == '.' || label == ',') {
        _onDecimalPressed();
        return;
      }

      // Operations (top row)
      if (label == '+') {
        _onOperationPressed('+');
        return;
      }
      if (label == '-') {
        _onOperationPressed('-');
        return;
      }
      if (label == '*') {
        _onOperationPressed('×');
        return;
      }
      if (label == '/') {
        _onOperationPressed('÷');
        return;
      }
    }
  }

  Widget _buildButton(String text, {Color? color, VoidCallback? onPressed}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF0D1845),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: RawKeyboardListener(
          focusNode: _focusNode,
          onKey: _handleKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.calculate, color: Color(0xFF0D1845)),
                  const SizedBox(width: 8),
                  const Text(
                    'Calculator',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D1845),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _expression.isNotEmpty ? _expression : _display,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1845),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              const SizedBox(height: 16),

              // Buttons
              Column(
                children: [
                  // Row 1: Clear, Backspace, ÷
                  Row(
                    children: [
                      _buildButton(
                        'C',
                        color: Colors.red,
                        onPressed: _onClearPressed,
                      ),
                      _buildButton(
                        '⌫',
                        color: Colors.orange,
                        onPressed: _onBackspacePressed,
                      ),
                      _buildButton(
                        '÷',
                        color: Colors.teal,
                        onPressed: () => _onOperationPressed('÷'),
                      ),
                    ],
                  ),

                  // Row 2: 7, 8, 9, ×
                  Row(
                    children: [
                      _buildButton('7', onPressed: () => _onNumberPressed('7')),
                      _buildButton('8', onPressed: () => _onNumberPressed('8')),
                      _buildButton('9', onPressed: () => _onNumberPressed('9')),
                      _buildButton(
                        '×',
                        color: Colors.teal,
                        onPressed: () => _onOperationPressed('×'),
                      ),
                    ],
                  ),

                  // Row 3: 4, 5, 6, -
                  Row(
                    children: [
                      _buildButton('4', onPressed: () => _onNumberPressed('4')),
                      _buildButton('5', onPressed: () => _onNumberPressed('5')),
                      _buildButton('6', onPressed: () => _onNumberPressed('6')),
                      _buildButton(
                        '-',
                        color: Colors.teal,
                        onPressed: () => _onOperationPressed('-'),
                      ),
                    ],
                  ),

                  // Row 4: 1, 2, 3, +
                  Row(
                    children: [
                      _buildButton('1', onPressed: () => _onNumberPressed('1')),
                      _buildButton('2', onPressed: () => _onNumberPressed('2')),
                      _buildButton('3', onPressed: () => _onNumberPressed('3')),
                      _buildButton(
                        '+',
                        color: Colors.teal,
                        onPressed: () => _onOperationPressed('+'),
                      ),
                    ],
                  ),

                  // Row 5: 0, ., =
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          child: ElevatedButton(
                            onPressed: () => _onNumberPressed('0'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D1845),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(16),
                            ),
                            child: const Text(
                              '0',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildButton('.', onPressed: _onDecimalPressed),
                      _buildButton(
                        '=',
                        color: Colors.green,
                        onPressed: _onEqualsPressed,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (mounted) _focusNode.requestFocus();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
