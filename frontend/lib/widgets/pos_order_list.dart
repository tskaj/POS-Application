import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PosOrderList extends StatefulWidget {
  final List<Map<String, Object>> orderItems;
  final Function(String) onRemoveItem;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onSelectCustomer;
  final Function(double) onTotalChanged;
  final Function(double, double, double) onTaxDiscountChanged;
  final List<Map<String, dynamic>> salesmen;
  final Map<String, dynamic>? selectedSalesman;
  final Function(Map<String, dynamic>?) onSelectSalesman;
  final Function(String) onDescriptionChanged;
  final String? description;
  final double? advanceAmount;
  final Function(double)? onAdvanceChanged;
  final String? dueDate;
  final Function(String)? onDueDateChanged;
  // Optional initial tab: 0 = Regular, 1 = Custom
  final int? initialActiveTab;
  // When true, prevent switching between Regular/Custom tabs (used when
  // POS is opened specifically to edit an existing invoice). This ensures
  // the user cannot change the order type while editing a saved invoice.
  final bool? disableTabSwitching;
  // Callback when active tab changes. Sends the new active tab index (0 or 1).
  final Function(int)? onActiveTabChanged;

  const PosOrderList({
    super.key,
    required this.orderItems,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onSelectCustomer,
    required this.onTotalChanged,
    required this.onTaxDiscountChanged,
    required this.salesmen,
    this.selectedSalesman,
    required this.onSelectSalesman,
    required this.onDescriptionChanged,
    this.description,
    this.advanceAmount,
    this.onAdvanceChanged,
    this.dueDate,
    this.onDueDateChanged,
    this.initialActiveTab,
    this.disableTabSwitching,
    this.onActiveTabChanged,
  });

  // Note: customize-by-editing-title/price preserved previously. New add-on
  // workflow uses _showAddOnDialog which attaches extras to the parent item.

  @override
  State<PosOrderList> createState() => _PosOrderListState();
}

class _PosOrderListState extends State<PosOrderList> {
  String _orderId =
      'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  double _discountAmount = 0.0;
  double _discountPercentage = 0.0;
  double _taxAmount = 0.0;
  double _taxPercentage = 0.0;

  final TextEditingController _discountPkrController = TextEditingController();
  final TextEditingController _discountPercentController =
      TextEditingController();
  final TextEditingController _taxPkrController = TextEditingController();
  final TextEditingController _taxPercentController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final TextEditingController _advanceController;

  int _activeTabIndex = 0;
  double _advanceAmountLocal = 0.0;
  String? _dueDateLocal;

  @override
  void initState() {
    super.initState();
    // Initialize description controller from the parent-provided value
    _descriptionController.text = widget.description ?? '';
    _advanceAmountLocal = widget.advanceAmount ?? 0.0;
    _dueDateLocal = widget.dueDate;
    _activeTabIndex = widget.initialActiveTab ?? 0;
    _advanceController = TextEditingController(
      text: _advanceAmountLocal > 0
          ? _advanceAmountLocal.toStringAsFixed(2)
          : '',
    );
    _advanceController.addListener(() {
      // Keep local and parent state in sync when user edits the advance field
      _updateAdvance(_advanceController.text);
    });
  }

  void _updateAdvance(String value) {
    final pkr = double.tryParse(value) ?? 0.0;
    setState(() {
      _advanceAmountLocal = pkr;
    });
    if (widget.onAdvanceChanged != null) widget.onAdvanceChanged!(pkr);
  }

  void _updateDueDate(String value) {
    setState(() {
      _dueDateLocal = value;
    });
    if (widget.onDueDateChanged != null) widget.onDueDateChanged!(value);
  }

  Widget _buildSmallTab(String label, int index) {
    final bool active = _activeTabIndex == index;
    final bool disabled = widget.disableTabSwitching == true;

    return GestureDetector(
      onTap: () {
        if (disabled) return; // Prevent switching while editing an invoice
        setState(() {
          _activeTabIndex = index;
        });
        // Notify parent about tab change
        if (widget.onActiveTabChanged != null) {
          try {
            widget.onActiveTabChanged!(_activeTabIndex);
          } catch (_) {}
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF0D1845)
              : (disabled ? Colors.grey[200] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? const Color(0xFF0D1845)
                : (disabled ? Colors.grey[300]! : Colors.grey[200]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (disabled ? Colors.grey[600] : Colors.black87),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant PosOrderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent cleared or changed the description externally, update the
    // controller so the text field reflects the current value.
    final newDesc = widget.description ?? '';
    if (newDesc != _descriptionController.text) {
      _descriptionController.text = newDesc;
    }
    // If parent changed advance from above, update controller text to reflect it
    final newAdvance = widget.advanceAmount ?? 0.0;
    if (newAdvance != _advanceAmountLocal) {
      _advanceAmountLocal = newAdvance;
      _advanceController.text = _advanceAmountLocal > 0
          ? _advanceAmountLocal.toStringAsFixed(2)
          : '';
    }
    // If parent changed due date from above, update local state to reflect it
    final newDueDate = widget.dueDate;
    if (newDueDate != _dueDateLocal) {
      _dueDateLocal = newDueDate;
    }
  }

  @override
  void dispose() {
    _discountPkrController.dispose();
    _discountPercentController.dispose();
    _taxPkrController.dispose();
    _taxPercentController.dispose();
    _descriptionController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  void _updateDiscountFromPkr(String value) {
    final pkr = double.tryParse(value) ?? 0.0;
    setState(() {
      _discountAmount = pkr;
      if (_subtotal > 0) {
        _discountPercentage = (pkr / _subtotal) * 100;
        _discountPercentController.text = _discountPercentage.toStringAsFixed(
          2,
        );
      }
    });
  }

  void _updateDiscountFromPercent(String value) {
    final percent = double.tryParse(value) ?? 0.0;
    setState(() {
      _discountPercentage = percent;
      _discountAmount = (_subtotal * percent) / 100;
      _discountPkrController.text = _discountAmount.toStringAsFixed(2);
    });
  }

  void _updateTaxFromPkr(String value) {
    final pkr = double.tryParse(value) ?? 0.0;
    setState(() {
      _taxAmount = pkr;
      if (_subtotal > 0) {
        _taxPercentage = (pkr / _subtotal) * 100;
        _taxPercentController.text = _taxPercentage.toStringAsFixed(2);
      }
    });
  }

  void _updateTaxFromPercent(String value) {
    final percent = double.tryParse(value) ?? 0.0;
    setState(() {
      _taxPercentage = percent;
      _taxAmount = (_subtotal * percent) / 100;
      _taxPkrController.text = _taxAmount.toStringAsFixed(2);
    });
  }

  // Product-level discount dialog
  void _showProductDiscountDialog(Map<String, dynamic> item) {
    final productId = (item['id'] as Object?)?.toString() ?? '';
    final price =
        double.tryParse((item['price'] as Object?)?.toString() ?? '0.0') ?? 0.0;
    final quantity = (item['quantity'] as int?) ?? 1;
    final itemSubtotal = price * quantity;

    // Get current discount values
    final currentDiscountPercent =
        double.tryParse(
          (item['discountPercent'] as Object?)?.toString() ?? '0.0',
        ) ??
        0.0;
    final currentDiscountAmount =
        double.tryParse(
          (item['discountAmount'] as Object?)?.toString() ?? '0.0',
        ) ??
        0.0;

    final discountPercentController = TextEditingController(
      text: currentDiscountPercent > 0
          ? currentDiscountPercent.toStringAsFixed(2)
          : '',
    );
    final discountPkrController = TextEditingController(
      text: currentDiscountAmount > 0
          ? currentDiscountAmount.toStringAsFixed(2)
          : '',
    );

    void updateDiscountFromPercent(String value, StateSetter dialogSetState) {
      final percent = double.tryParse(value) ?? 0.0;
      if (percent < 0 || percent > 100) return;

      final discountAmount = (itemSubtotal * percent) / 100;
      discountPkrController.text = discountAmount.toStringAsFixed(2);
      dialogSetState(() {});
    }

    void updateDiscountFromPkr(String value, StateSetter dialogSetState) {
      final amount = double.tryParse(value) ?? 0.0;
      if (amount < 0 || amount > itemSubtotal) return;

      final percent = itemSubtotal > 0 ? (amount / itemSubtotal) * 100 : 0.0;
      discountPercentController.text = percent.toStringAsFixed(2);
      dialogSetState(() {});
    }

    void applyDiscount() {
      final percent = double.tryParse(discountPercentController.text) ?? 0.0;
      final amount = double.tryParse(discountPkrController.text) ?? 0.0;

      // Update the item with discount
      setState(() {
        final itemIndex = widget.orderItems.indexWhere(
          (i) => i['id']?.toString() == productId,
        );
        if (itemIndex != -1) {
          widget.orderItems[itemIndex]['discountPercent'] = percent;
          widget.orderItems[itemIndex]['discountAmount'] = amount;

          // Notify parent of total change
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onTotalChanged(_roundedTotal);
            widget.onTaxDiscountChanged(_taxAmount, _discountAmount, 0.0);
          });
        }
      });

      Navigator.of(context).pop();
    }

    void clearDiscount() {
      setState(() {
        final itemIndex = widget.orderItems.indexWhere(
          (i) => i['id']?.toString() == productId,
        );
        if (itemIndex != -1) {
          widget.orderItems[itemIndex]['discountPercent'] = 0.0;
          widget.orderItems[itemIndex]['discountAmount'] = 0.0;

          // Notify parent of total change
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onTotalChanged(_roundedTotal);
            widget.onTaxDiscountChanged(_taxAmount, _discountAmount, 0.0);
          });
        }
      });
      Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.local_offer, color: Colors.purple[600]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Product Discount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['name'] as String?) ?? 'Unknown Product',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quantity: $quantity × Rs${_formatCurrency(price)} = Rs${_formatCurrency(itemSubtotal)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Discount Percentage
                    TextField(
                      controller: discountPercentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Discount %',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.percent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) =>
                          updateDiscountFromPercent(value, setState),
                    ),
                    const SizedBox(height: 12),

                    // Discount PKR
                    TextField(
                      controller: discountPkrController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Discount PKR',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.money_off),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) =>
                          updateDiscountFromPkr(value, setState),
                    ),
                    const SizedBox(height: 16),

                    // Final Price Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Final Price:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[800],
                            ),
                          ),
                          Text(
                            'Rs${_formatCurrency(itemSubtotal - (double.tryParse(discountPkrController.text) ?? 0.0))}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (currentDiscountAmount > 0)
                  TextButton.icon(
                    onPressed: clearDiscount,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear Discount'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[600],
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: applyDiscount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      discountPercentController.dispose();
      discountPkrController.dispose();
    });
  }

  // Show dialog to add one or more custom add-ons to a given product item.
  // Add-ons are stored under the item's 'extras' key as a list of maps
  // with keys: 'title' and 'amount'. This preserves the parent product_id
  // and ensures the payment builder will include extras in the bridals payload.
  void _showAddOnDialog(Map<String, dynamic> item) {
    final titleController = TextEditingController();
    final priceController = TextEditingController();

    // Ensure extras list exists on the item
    if (item['extras'] == null || item['extras'] is! List) {
      item['extras'] = <Map<String, dynamic>>[];
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final extras = (item['extras'] as List)
                .cast<Map<String, dynamic>>();

            void addAddon() {
              final title = titleController.text.trim();
              final priceStr = priceController.text.trim();

              // Normalize and parse for validation while preserving the
              // original user-entered string for storage.
              final normalized = priceStr.replaceAll(',', '');
              final price = double.tryParse(normalized) ?? 0.0;
              if (title.isEmpty || price <= 0) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid title and price'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              setState(() {
                extras.add({'title': title, 'amount': priceStr});
                // Also mark parent item as custom so order is treated as custom
                item['isCustom'] = true;
              });

              // Clear input fields so user can add more quickly
              titleController.clear();
              priceController.clear();

              // Notify parent that totals changed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onTotalChanged(_roundedTotal);
                widget.onTaxDiscountChanged(_taxAmount, _discountAmount, 0.0);
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Add / Edit Custom Items')),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Existing extras list (editable)
                    if (extras.isNotEmpty) ...[
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: extras.length,
                          itemBuilder: (context, idx) {
                            final e = extras[idx];
                            final titleVal = e['title']?.toString() ?? '';
                            final amountVal = (e['amount'] is num)
                                ? (e['amount'] as num).toString()
                                : (e['amount']?.toString() ?? '');

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: TextField(
                                      key: ValueKey('extra_title_\$idx'),
                                      controller:
                                          TextEditingController.fromValue(
                                            TextEditingValue(
                                              text: titleVal,
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: titleVal.length,
                                                  ),
                                            ),
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Title',
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          extras[idx]['title'] = val;
                                          item['isCustom'] = true;
                                        });
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              widget.onTotalChanged(
                                                _roundedTotal,
                                              );
                                            });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      key: ValueKey('extra_price_\$idx'),
                                      controller:
                                          TextEditingController.fromValue(
                                            TextEditingValue(
                                              text: amountVal,
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: amountVal.length,
                                                  ),
                                            ),
                                          ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Price',
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          // Preserve exact user-entered string.
                                          extras[idx]['amount'] = val;
                                          item['isCustom'] = true;
                                        });
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              widget.onTotalChanged(
                                                _roundedTotal,
                                              );
                                            });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        extras.removeAt(idx);
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            widget.onTotalChanged(
                                              _roundedTotal,
                                            );
                                          });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Input fields for new addon
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price (PKR)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: addAddon,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      priceController.dispose();
    });
  }

  double get _subtotal {
    return widget.orderItems.fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final productDiscount =
          double.tryParse(item['discountAmount']?.toString() ?? '0.0') ?? 0.0;
      // Sum extras (if any) for this item
      double extrasTotal = 0.0;
      try {
        final extras = item['extras'];
        if (extras is List) {
          for (final e in extras) {
            extrasTotal +=
                double.tryParse(e['amount']?.toString() ?? '') ?? 0.0;
          }
        }
      } catch (_) {}

      // Calculate item total: (price * quantity) + extras - product discount
      final itemTotal = (price * quantity) + extrasTotal - productDiscount;
      return sum + itemTotal;
    });
  }

  double get _tax => _taxAmount;
  double get _discount => _discountAmount;

  double get _total => _subtotal + _tax - _discount;
  double get _roundedTotal => _total.roundToDouble();

  // Helper method to format currency with commas
  String _formatCurrency(double amount, {bool roundOff = false}) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    if (roundOff) {
      return formatter.format(amount.roundToDouble());
    }
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    // Reset tax and discount when cart is empty
    if (widget.orderItems.isEmpty &&
        (_taxAmount != 0 || _discountAmount != 0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _taxAmount = 0.0;
          _taxPercentage = 0.0;
          _discountAmount = 0.0;
          _discountPercentage = 0.0;
          _taxPkrController.clear();
          _taxPercentController.clear();
          _discountPkrController.clear();
          _discountPercentController.clear();
        });
      });
    }

    // Notify parent of total and tax/discount changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTotalChanged(_roundedTotal);
      widget.onTaxDiscountChanged(_taxAmount, _discountAmount, 0.0);
    });

    return Container(
      width: double.infinity, // Use full available width
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Order List Title (Compact Design)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[50]!.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[100]!, width: 1),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    size: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Order Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.teal.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${widget.orderItems.length} items',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Order ID, Tabs and Total (Combined and Compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Row with Tabs and Order ID side by side
                Row(
                  children: [
                    _buildSmallTab('Regular', 0),
                    const SizedBox(width: 6),
                    _buildSmallTab('Custom', 1),
                    const SizedBox(width: 12),
                    Text(
                      'ID:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _orderId,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Total Amount (more compact)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.teal.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Rs${_formatCurrency(_total, roundOff: true)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order Items List (Clean White)
          if (widget.orderItems.isEmpty)
            Container(
              height: 200,
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[50]!.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[100]!, width: 2),
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add items from the menu to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              constraints: BoxConstraints(maxHeight: 350),
              color: Colors.white,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: widget.orderItems.length,
                itemBuilder: (context, index) {
                  final item = widget.orderItems[index];
                  return _buildEnhancedOrderItem(item);
                },
              ),
            ),

          // Salesman Selection (More Compact)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Salesman:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: OutlinedButton(
                      onPressed: _showSalesmanSearchDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.selectedSalesman != null
                                  ? widget.selectedSalesman!['name'] ??
                                        'Select Salesman'
                                  : 'Select Salesman',
                              style: TextStyle(
                                color: widget.selectedSalesman != null
                                    ? Colors.black87
                                    : Colors.grey[700],
                                fontSize: 11,
                                fontWeight: widget.selectedSalesman != null
                                    ? FontWeight.w400
                                    : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Payment Summary Section (More Compact)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[100]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment Summary Header (More Compact)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, size: 13, color: Colors.grey[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Payment Summary',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tax and Discount Fields (All in one row for efficiency)
                Row(
                  children: [
                    Expanded(
                      child: _buildCleanInputField(
                        'Tax %',
                        '%',
                        Icons.percent,
                        Colors.orange[600]!,
                        _updateTaxFromPercent,
                        controller: _taxPercentController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCleanInputField(
                        'Tax (PKR)',
                        'PKR',
                        Icons.account_balance,
                        Colors.orange[600]!,
                        _updateTaxFromPkr,
                        controller: _taxPkrController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCleanInputField(
                        'Disc %',
                        '%',
                        Icons.percent,
                        Colors.purple[600]!,
                        _updateDiscountFromPercent,
                        controller: _discountPercentController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCleanInputField(
                        'Disc (PKR)',
                        'PKR',
                        Icons.local_offer,
                        Colors.purple[600]!,
                        _updateDiscountFromPkr,
                        controller: _discountPkrController,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Advance / Balance / Due Date (Shown for Custom Order tab - Compact Row)
                if (_activeTabIndex == 1) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCleanInputField(
                          'Advance',
                          'PKR',
                          Icons.payments,
                          Colors.blue,
                          (v) => _updateAdvance(v),
                          controller: _advanceController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[100]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs${_formatCurrency(_total - _advanceAmountLocal, roundOff: true)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dueDateLocal != null
                                  ? DateTime.tryParse(_dueDateLocal!) ??
                                        DateTime.now()
                                  : DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );
                            if (picked != null) {
                              final formatted = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked);
                              _updateDueDate(formatted);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.date_range,
                                  color: Colors.grey[700],
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _dueDateLocal ?? 'Due date',
                                    style: TextStyle(
                                      color: _dueDateLocal != null
                                          ? Colors.black87
                                          : Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Summary Rows - Single Compact Row (No duplicate total)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50]!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[100]!, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCompactSummaryItem(
                        'Subtotal',
                        _subtotal,
                        Icons.shopping_bag,
                        Colors.grey[700]!,
                      ),
                      _buildCompactSummaryItem(
                        'Tax',
                        _tax,
                        Icons.account_balance_wallet,
                        Colors.orange[600]!,
                      ),
                      if (_discount > 0)
                        _buildCompactSummaryItem(
                          'Disc',
                          -_discount,
                          Icons.discount,
                          Colors.red[600]!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description Section (Compact)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[100]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description Header (Compact)
                Row(
                  children: [
                    Icon(Icons.description, size: 13, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Order Description',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Description Text Field (Compact)
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Order description (optional)...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: const Color(0xFF0D1845).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50]!.withOpacity(0.3),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    widget.onDescriptionChanged(value);
                  },
                ),
              ],
            ),
          ),

          // Select Payment Section (Compact)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[100]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Select Payment Header (Compact)
                Row(
                  children: [
                    Icon(Icons.credit_card, size: 13, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Select Payment Method',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Payment methods will be handled by PosPaymentMethods widget
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedOrderItem(Map<String, dynamic> item) {
    final price =
        double.tryParse((item['price'] as Object?)?.toString() ?? '0.0') ?? 0.0;
    final quantity = (item['quantity'] as int?) ?? 1;

    // Get product-level discount
    final productDiscountPercent =
        double.tryParse(
          (item['discountPercent'] as Object?)?.toString() ?? '0.0',
        ) ??
        0.0;
    final productDiscountAmount =
        double.tryParse(
          (item['discountAmount'] as Object?)?.toString() ?? '0.0',
        ) ??
        0.0;

    // Calculate item total with discount and extras
    final itemSubtotal = price * quantity;
    double extrasTotal = 0.0;
    try {
      final extras = item['extras'];
      if (extras is List) {
        for (final e in extras) {
          extrasTotal += double.tryParse(e['amount']?.toString() ?? '') ?? 0.0;
        }
      }
    } catch (_) {}

    final itemTotal = itemSubtotal + extrasTotal - productDiscountAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Name and Price (compact layout)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['name'] as String?) ?? 'Unknown Product',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1845),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatCurrency(price),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.teal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '× $quantity',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // If there are add-ons, replace the old subtotal display
                        // with an add-on message in the old price position and
                        // show the new final price below it. Do not show the
                        // original base subtotal when extras exist.
                        if (extrasTotal > 0) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue[100]!),
                                ),
                                child: Text(
                                  '+ Rs${_formatCurrency(extrasTotal)} add-ons',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Rs${_formatCurrency(itemTotal)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ] else ...[
                          // No extras: show normal subtotal and optionally final price
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Rs${_formatCurrency(itemSubtotal)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: productDiscountAmount > 0
                                        ? Colors.grey[500]
                                        : Colors.teal,
                                    decoration: productDiscountAmount > 0
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (productDiscountAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Rs${_formatCurrency(itemTotal)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ],
                    ),
                    if (productDiscountAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            'Discount: ${productDiscountPercent > 0 ? "${productDiscountPercent.toStringAsFixed(1)}% - " : ""}Rs${_formatCurrency(productDiscountAmount)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Quantity Controls
              Container(
                margin: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (quantity > 1) {
                          widget.onUpdateQuantity(
                            (item['id'] as Object?)?.toString() ?? '',
                            quantity - 1,
                          );
                        }
                      },
                      icon: Icon(
                        Icons.remove,
                        size: 16,
                        color: quantity > 1
                            ? Colors.red[600]
                            : Colors.grey[400],
                      ),
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1845),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        widget.onUpdateQuantity(
                          (item['id'] as Object?)?.toString() ?? '',
                          quantity + 1,
                        );
                      },
                      icon: Icon(Icons.add, size: 16, color: Colors.green[600]),
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // Customize Button (available only in Custom Order tab)
              if (_activeTabIndex == 1)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: 'Add / Edit Custom Items',
                    child: IconButton(
                      onPressed: () => _showAddOnDialog(item),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: Colors.blue,
                      ),
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ),

              // Discount Button
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: IconButton(
                  onPressed: () => _showProductDiscountDialog(item),
                  icon: Icon(
                    Icons.local_offer,
                    size: 20,
                    color: productDiscountAmount > 0
                        ? Colors.purple[600]
                        : Colors.grey[500],
                  ),
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'Apply Discount',
                ),
              ),

              // Remove Button
              Container(
                child: IconButton(
                  onPressed: () => widget.onRemoveItem(
                    (item['id'] as Object?)?.toString() ?? '',
                  ),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red[600],
                  ),
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Compact summary item for horizontal layout
  Widget _buildCompactSummaryItem(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            'Rs${_formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanInputField(
    String label,
    String hint,
    IconData icon,
    Color color,
    Function(String) onChanged, {
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 3),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          height: 34,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: color.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showSalesmanSearchDialog() {
    // Initialize filtered salesmen with all salesmen
    List<Map<String, dynamic>> filteredSalesmen = List.from(widget.salesmen);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterSalesmen(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredSalesmen = List.from(widget.salesmen);
                } else {
                  filteredSalesmen = widget.salesmen.where((salesman) {
                    final name =
                        salesman['name']?.toString().toLowerCase() ?? '';
                    final email =
                        salesman['email']?.toString().toLowerCase() ?? '';
                    final searchQuery = query.toLowerCase();
                    return name.contains(searchQuery) ||
                        email.contains(searchQuery);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1845).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Salesman',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: _filterSalesmen,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Salesmen List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: filteredSalesmen.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No salesmen found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredSalesmen.length,
                                itemBuilder: (context, index) {
                                  final salesman = filteredSalesmen[index];
                                  final isSelected =
                                      salesman['id'] ==
                                      widget.selectedSalesman?['id'];

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        widget.onSelectSalesman(salesman);
                                      });
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1)
                                            : Colors.transparent,
                                        border:
                                            index < filteredSalesmen.length - 1
                                            ? Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade100,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  salesman['name'] ?? '',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF0D1845,
                                                              )
                                                            : Colors.black87,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  salesman['email'] ?? '',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF0D1845),
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF28A745),
                            const Color(0xFF20B545),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF28A745).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
