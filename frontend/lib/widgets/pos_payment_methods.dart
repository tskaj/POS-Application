import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/sales_service.dart';
import '../services/credit_customer_service.dart';
import '../services/city_service.dart';
import '../pages/peoples/credit_customer_page.dart';
import '../services/bank_services.dart';
import '../providers/providers.dart';
import 'thermal_invoice_widget.dart';
import 'customer_search_dialog.dart';

class PosPaymentMethods extends StatefulWidget {
  final double totalAmount;
  final double taxAmount;
  final double discountAmount;
  final double subtotalAmount;
  final double roundOffAmount;
  final Function(String, double) onPaymentComplete;
  final List<Map<String, Object>> orderItems;
  final Map<String, dynamic>? selectedCustomer;
  final Map<String, dynamic>? selectedSalesman;
  final Invoice? invoiceToEdit;
  final String? description;
  final double? initialAdvance;
  final String? dueDate;
  // When true, POS is in Custom Order tab. Payment UI should only show
  // the Credit option and outgoing requests for custom orders will force
  // payment_mode = 2 as required by backend.
  final bool? isCustomOrder;
  // Callback to notify parent (PosPage) about selected credit customer so
  // the main POS page can update its selectedCustomer state as well.
  final void Function(Map<String, dynamic>)? onSelectCreditCustomer;

  const PosPaymentMethods({
    super.key,
    required this.totalAmount,
    required this.taxAmount,
    required this.discountAmount,
    required this.subtotalAmount,
    required this.roundOffAmount,
    required this.onPaymentComplete,
    required this.orderItems,
    this.selectedCustomer,
    this.selectedSalesman,
    this.invoiceToEdit,
    this.description,
    this.initialAdvance,
    this.dueDate,
    this.isCustomOrder,
    this.onSelectCreditCustomer,
  });

  @override
  State<PosPaymentMethods> createState() => _PosPaymentMethodsState();
}

class _PosPaymentMethodsState extends State<PosPaymentMethods> {
  Future<void> _processPosPayment({
    required int paymentModeId,
    required double paidAmount,
    int? creditCustomerId,
    int? bankAccountId,
  }) async {
    // Determine transaction type based on whether this is a Custom Order.
    // Regular orders use transaction_type_id = 2, Custom orders use 11.
    // The explicit widget.isCustomOrder prop (when provided) takes
    // precedence over inferring from items.
    final bool inferredIsCustom = widget.orderItems.any((i) {
      try {
        final bool? flag = (i['isCustom'] as bool?);
        if (flag == true) return true;
      } catch (_) {}

      try {
        final extras = i['extras'];
        if (extras is List && extras.isNotEmpty) return true;
      } catch (_) {}

      return false;
    });
    final bool isCustomOrder = widget.isCustomOrder ?? inferredIsCustom;
    final int computedTransactionTypeId = isCustomOrder ? 11 : 2;

    // Compute global discount percent (discPer) based on subtotal if available
    final double computedDiscPer = (widget.subtotalAmount > 0)
        ? (widget.discountAmount / widget.subtotalAmount) * 100
        : 0.0;

    print('🔄 POS PAYMENT: Starting payment processing...');
    print(
      '📊 Payment Details: Mode=$paymentModeId, ComputedType=$computedTransactionTypeId, Amount=$paidAmount',
    );

    try {
      // Validate order items
      if (widget.orderItems.isEmpty) {
        throw Exception('Cannot process payment: No items in the order');
      }

      // Prepare order details
      final details = widget.orderItems.map((item) {
        // Prefer sending numeric product_id when possible (backend expects an ID)
        final parsedId = int.tryParse(item['id']?.toString() ?? '');
        final productIdValue = parsedId ?? item['id'];

        final Map<String, dynamic> detail = {
          'product_id': productIdValue,
          'qty': (item['quantity'] as int?)?.toString() ?? '1',
          'sale_price': (item['price'] as num?)?.toString() ?? '0.0',
        };

        // Optional per-item discounts - support both internal and API naming
        final perItemDiscPer =
            item['discPer'] ?? item['discountPercent'] ?? 0.0;
        final perItemDiscAmount =
            item['discAmount'] ?? item['discountAmount'] ?? 0.0;
        detail['discPer'] = perItemDiscPer;
        detail['discAmount'] = perItemDiscAmount;
        // Some backends expect lowercase keys; include `discamount` as well
        // to ensure the product-level discount amount is received.
        detail['discamount'] = perItemDiscAmount;

        // If the item has extras (custom order), include them as-is so bridals endpoint
        // receives the extras array expected by the API.
        if (item.containsKey('extras') && item['extras'] != null) {
          detail['extras'] = item['extras'];
        }

        return detail;
      }).toList();

      // Get customer ID
      // For bank/payments we often use customer ID 1; for credit payments
      // we use the selected credit customer id.
      final customerId = paymentModeId == 3 && creditCustomerId != null
          ? creditCustomerId
          : (paymentModeId == 3 && widget.selectedCustomer != null
                ? (widget.selectedCustomer!['id'] ?? 1)
                : (paymentModeId == 2
                      ? 1
                      : (widget.selectedCustomer != null
                            ? (widget.selectedCustomer!['id'] ?? 1)
                            : 1)));

      // Current date in YYYY-MM-DD format
      final invDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      print('📦 Order Details: ${details.length} items');
      print('👤 Customer ID: $customerId');
      print('📅 Invoice Date: $invDate');

      Map<String, dynamic> response = {};

      if (widget.invoiceToEdit != null) {
        // Update existing invoice
        print(
          '🔄 Updating existing invoice #${widget.invoiceToEdit!.invId}...',
        );
        // Build a payload suitable for either regular invoices or bridals (custom orders)
        final commonUpdateData = {
          'inv_date': invDate,
          'customer_id': customerId,
          'tax': widget.taxAmount,
          // include both naming styles to be defensive
          'disc_per': computedDiscPer,
          'disc_amount': widget.discountAmount,
          'discPer': computedDiscPer,
          'discAmount': widget.discountAmount,
          'inv_amount': widget.totalAmount,
          'paid': paidAmount,
          'payment_mode_id': paymentModeId,
          'transaction_type_id': computedTransactionTypeId,
          'employee_id': widget.selectedSalesman?['id'],
          'details': details,
        };

        // Add COA parameters for invoice updates
        if (paymentModeId == 1) {
          // Cash payment
          commonUpdateData['coa_id'] = 3;
          commonUpdateData['coaRef_id'] = 7;
        } else if (paymentModeId == 2) {
          // Bank payment - use provided bank account or admin bank account
          try {
            if (bankAccountId != null) {
              commonUpdateData['coa_id'] = bankAccountId;
              commonUpdateData['bank_acc_id'] = bankAccountId;
              commonUpdateData['coaRef_id'] = 7;
              print('🏦 Using selected bank account ID: $bankAccountId');
            } else {
              final bankAccountsResponse =
                  await BankAccountService.getBankAccounts();
              if (bankAccountsResponse.data.isNotEmpty) {
                final adminBankAccount = bankAccountsResponse.data.first;
                commonUpdateData['coa_id'] = int.tryParse(
                  adminBankAccount.coaId,
                );
                commonUpdateData['bank_acc_id'] = int.tryParse(
                  adminBankAccount.coaId,
                );
                commonUpdateData['coaRef_id'] = 7;
              }
            }
          } catch (e) {
            print('❌ Error fetching admin bank account for update: $e');
          }
        } else if (paymentModeId == 3) {
          // Credit payment - use customer account, but also handle bank account if provided
          commonUpdateData['coa_id'] = customerId;
          if (bankAccountId != null) {
            commonUpdateData['bank_acc_id'] = bankAccountId;
          }
          commonUpdateData['coaRef_id'] = 7;
        }

        if (isCustomOrder) {
          // Compute total extra amount if extras are present
          double totalExtraAmount = 0.0;
          try {
            for (final it in widget.orderItems) {
              final extras = it['extras'];
              if (extras is List) {
                for (final e in extras) {
                  final amt =
                      double.tryParse(e['amount']?.toString() ?? '') ?? 0.0;
                  totalExtraAmount += amt;
                }
              }
            }
          } catch (_) {}

          // Build bridal-specific payload (use createBridal style keys)
          final bridalUpdate = {
            ...commonUpdateData,
            if (widget.dueDate != null) 'due_date': widget.dueDate,
            if (widget.description != null && widget.description!.isNotEmpty)
              'description': widget.description,
            if (totalExtraAmount > 0) 'total_extra_amount': totalExtraAmount,
          };

          await SalesService.updateBridal(
            widget.invoiceToEdit!.invId,
            bridalUpdate,
          );
          print('✅ Bridal (custom) invoice updated successfully!');

          response = {
            'data': {'inv_id': widget.invoiceToEdit!.invId},
          };
        } else {
          await SalesService.updateInvoice(
            widget.invoiceToEdit!.invId,
            commonUpdateData,
          );

          print('✅ Invoice updated successfully!');
          response = {
            'data': {'inv_id': widget.invoiceToEdit!.invId},
          };
        }
      } else {
        // Create new invoice
        print('🌐 Calling POS API...');

        // Determine COA parameters based on payment mode
        int? coaId;
        int? bankAccId;
        const int coaRefId = 7; // Sale account reference

        if (paymentModeId == 1) {
          // Cash payment
          coaId = 3; // Cash account
          print('💰 Cash payment: coa_id=$coaId, coaRef_id=$coaRefId');
        } else if (paymentModeId == 2) {
          // Bank payment - use provided bank account or admin bank account
          try {
            if (bankAccountId != null) {
              // Use the provided bank account ID
              coaId = bankAccountId;
              bankAccId = bankAccountId;
              print(
                '🏦 Bank payment with selected account: coa_id=$coaId, bank_acc_id=$bankAccId, coaRef_id=$coaRefId',
              );
            } else {
              // Fallback to first bank account
              final bankAccountsResponse =
                  await BankAccountService.getBankAccounts();
              if (bankAccountsResponse.data.isNotEmpty) {
                final adminBankAccount = bankAccountsResponse.data.first;
                coaId = int.tryParse(adminBankAccount.coaId);
                bankAccId = int.tryParse(adminBankAccount.coaId);
                print(
                  '🏦 Bank payment with default account: coa_id=$coaId, bank_acc_id=$bankAccId, coaRef_id=$coaRefId',
                );
              } else {
                print('⚠️ No admin bank account found for bank payment');
              }
            }
          } catch (e) {
            print('❌ Error fetching bank account: $e');
          }
        } else if (paymentModeId == 3) {
          // Credit payment - use customer account, but also handle bank account if provided
          coaId = customerId;
          if (bankAccountId != null) {
            bankAccId = bankAccountId;
            print(
              '💳 Credit payment with bank: coa_id=$coaId, bank_acc_id=$bankAccId, coaRef_id=$coaRefId',
            );
          } else {
            print(
              '💳 Credit payment (cash): coa_id=$coaId, coaRef_id=$coaRefId',
            );
          }
        }

        if (isCustomOrder) {
          // Compute total extra amount for custom items
          double totalExtraAmount = 0.0;
          try {
            for (final it in widget.orderItems) {
              final extras = it['extras'];
              if (extras is List) {
                for (final e in extras) {
                  final amt =
                      double.tryParse(e['amount']?.toString() ?? '') ?? 0.0;
                  totalExtraAmount += amt;
                }
              }
            }
          } catch (_) {}

          response = await SalesService.createBridal(
            invDate: invDate,
            customerId: customerId,
            tax: widget.taxAmount,
            discPer: computedDiscPer,
            discAmount: widget.discountAmount,
            invAmount: widget.totalAmount,
            paid: paidAmount,
            paymentModeId: paymentModeId,
            transactionTypeId: computedTransactionTypeId,
            salesmanId: widget.selectedSalesman?['id'],
            details: details,
            coaId: coaId,
            bankAccId: bankAccId,
            coaRefId: coaRefId,
            description: widget.description,
            dueDate: widget.dueDate,
            totalExtraAmount: totalExtraAmount > 0 ? totalExtraAmount : null,
          );
        } else {
          response = await SalesService.createPosInvoice(
            invDate: invDate,
            customerId: customerId,
            tax: widget.taxAmount,
            discPer: computedDiscPer,
            discAmount: widget.discountAmount,
            invAmount: widget.totalAmount,
            paid: paidAmount,
            paymentModeId: paymentModeId,
            transactionTypeId: computedTransactionTypeId,
            salesmanId: widget.selectedSalesman?['id'],
            details: details,
            coaId: coaId,
            bankAccId: bankAccId,
            coaRefId: coaRefId,
            description: widget.description,
            dueDate: widget.dueDate,
          );
        }
        print('✅ POS API call successful!');

        // Update SalesProvider with the new invoice
        if (response['data'] != null && mounted) {
          try {
            final salesProvider = Provider.of<SalesProvider>(
              context,
              listen: false,
            );
            // Create a basic invoice object from the response
            final paymentModeText = paymentModeId == 1
                ? 'Cash'
                : paymentModeId == 2
                ? 'Bank'
                : 'Credit';

            final newInvoice = Invoice(
              invId: response['data']['inv_id'] ?? 0,
              invDate: invDate,
              customerName:
                  widget.selectedCustomer?['name'] ?? 'Walk-in Customer',
              invAmount: widget.totalAmount,
              paidAmount: paidAmount,
              dueAmount: widget.totalAmount - paidAmount,
              paymentMode: paymentModeText,
              isCreditCustomer: paymentModeId == 3,
              salesmanName: widget.selectedSalesman?['name'],
            );

            // Add the new invoice to the provider's cache
            final updatedInvoices = List<Invoice>.from(salesProvider.invoices)
              ..insert(0, newInvoice);
            salesProvider.setInvoices(updatedInvoices);
            print(
              '📝 SalesProvider updated with new invoice #${newInvoice.invId}',
            );
          } catch (e) {
            print('⚠️ Failed to update SalesProvider: $e');
          }
        }
      }

      // DO NOT generate invoice PDF here - let user decide via dialog
      print('✅ Payment processed successfully!');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Payment processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Normalize response shape: some backends return inv_id at top-level
      // while the UI expects response['data']['inv_id']. Ensure the
      // dialog code always has a predictable shape so the Generate Invoice
      // popup shows correctly for custom orders too.
      if (response['data'] == null) {
        if (response.containsKey('inv_id')) {
          response['data'] = {'inv_id': response['inv_id']};
        } else if (response.containsKey('id')) {
          response['data'] = {'inv_id': response['id']};
        } else {
          response['data'] = {'inv_id': 0};
        }
      }

      // Show payment completion dialog with options
      if (mounted) {
        await _showPaymentCompletionDialog(paymentModeId, paidAmount, response);
      }

      // Clear order items AFTER dialog interaction (moved from callback)
      if (mounted) {
        widget.onPaymentComplete(
          _getPaymentMethodName(paymentModeId),
          paidAmount,
        );
      }
    } catch (e) {
      print('❌ POS PAYMENT ERROR: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPaymentCompletionDialog(
    int paymentModeId,
    double paidAmount,
    Map<String, dynamic> invoiceResponse,
  ) async {
    // Capture the parent context before showing dialog
    final parentContext = context;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Payment Successful!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount Paid: Rs${paidAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Payment Method: ${_getPaymentMethodName(paymentModeId)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              const Text(
                'What would you like to do next?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('close'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Close', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.print),
              label: const Text(
                'Send to Printer',
                style: TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('generate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D1845),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.receipt_long),
              label: const Text(
                'Generate Invoice',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );

    // Handle the result after dialog is closed
    if (result == 'generate' && mounted) {
      print('📄 User requested invoice generation...');

      // Extract invoice number from response
      // Extract invoice number robustly from various possible response shapes
      int invoiceNumber = 0;
      try {
        // Normalize candidates from response['data'] if available
        final data = (invoiceResponse['data'] is Map)
            ? Map<String, dynamic>.from(invoiceResponse['data'])
            : <String, dynamic>{};

        dynamic candidate;
        if (data.containsKey('inv_id'))
          candidate = data['inv_id'];
        else if (data.containsKey('invoice_id'))
          candidate = data['invoice_id'];
        else if (data.containsKey('id'))
          candidate = data['id'];
        else if (data.containsKey('invId'))
          candidate = data['invId'];
        else if (data.containsKey('invoice_no'))
          candidate = data['invoice_no'];
        else if (data.containsKey('invoiceNumber'))
          candidate = data['invoiceNumber'];

        // Fallback to top-level response keys
        candidate ??=
            invoiceResponse['inv_id'] ??
            invoiceResponse['id'] ??
            invoiceResponse['invoice_no'] ??
            invoiceResponse['invoiceNumber'];

        if (candidate != null) {
          if (candidate is int) {
            invoiceNumber = candidate;
          } else if (candidate is String) {
            // Try to extract digits from string like "INV-123" or "123"
            final digits = candidate.replaceAll(RegExp(r'[^0-9]'), '');
            invoiceNumber = int.tryParse(digits) ?? 0;
          }
        }
      } catch (e) {
        print('Error extracting invoice number: $e');
        invoiceNumber = 0;
      }

      // Generate and print thermal receipt using parent context
      // Preserve extras on the item map so the thermal invoice renderer
      // can draw them as indented bullet points beneath their parent item.
      final List<Map<String, dynamic>> printableItems = widget.orderItems
          .map<Map<String, dynamic>>((item) {
            final Map<String, dynamic> m = {
              'name': item['name'],
              'quantity': item['quantity'],
              'price': item['price'],
            };
            try {
              if (item.containsKey('extras') && item['extras'] != null) {
                m['extras'] = item['extras'];
              }
            } catch (_) {}
            // Add product-level discount if present
            try {
              if (item.containsKey('discountPercent') &&
                  item['discountPercent'] != null) {
                m['discountPercent'] = item['discountPercent'];
              }
              if (item.containsKey('discountAmount') &&
                  item['discountAmount'] != null) {
                m['discountAmount'] = item['discountAmount'];
              }
            } catch (_) {}
            return m;
          })
          .toList(growable: false);

      await ThermalInvoiceGenerator.printThermalReceipt(
        context: parentContext,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        customerName: widget.selectedCustomer?['name'] ?? 'Walk-in Customer',
        items: printableItems,
        subtotal: widget.totalAmount - widget.taxAmount + widget.discountAmount,
        tax: widget.taxAmount,
        discount: widget.discountAmount,
        total: widget.totalAmount,
        paymentMethod: _getPaymentMethodName(paymentModeId),
        paidAmount: paidAmount,
        salesmanName: widget.selectedSalesman?['name'],
        advance: widget.initialAdvance,
        dueDate: widget.dueDate,
      );

      print('✅ Invoice generated and printed successfully!');
    } else if (result == 'print' && mounted) {
      print('🖨️ User requested direct printing...');

      // Extract invoice number from response
      // Extract invoice number robustly from various possible response shapes
      int invoiceNumber = 0;
      try {
        // Normalize candidates from response['data'] if available
        final data = (invoiceResponse['data'] is Map)
            ? Map<String, dynamic>.from(invoiceResponse['data'])
            : <String, dynamic>{};

        dynamic candidate;
        if (data.containsKey('inv_id'))
          candidate = data['inv_id'];
        else if (data.containsKey('invoice_id'))
          candidate = data['invoice_id'];
        else if (data.containsKey('id'))
          candidate = data['id'];
        else if (data.containsKey('invId'))
          candidate = data['invId'];
        else if (data.containsKey('invoice_no'))
          candidate = data['invoice_no'];
        else if (data.containsKey('invoiceNumber'))
          candidate = data['invoiceNumber'];

        // Fallback to top-level response keys
        candidate ??=
            invoiceResponse['inv_id'] ??
            invoiceResponse['id'] ??
            invoiceResponse['invoice_no'] ??
            invoiceResponse['invoiceNumber'];

        if (candidate != null) {
          if (candidate is int) {
            invoiceNumber = candidate;
          } else if (candidate is String) {
            // Try to extract digits from string like "INV-123" or "123"
            final digits = candidate.replaceAll(RegExp(r'[^0-9]'), '');
            invoiceNumber = int.tryParse(digits) ?? 0;
          }
        }
      } catch (e) {
        print('Error extracting invoice number: $e');
        invoiceNumber = 0;
      }

      // Generate and print thermal receipt directly to printer
      // Preserve extras on the item map so the thermal invoice renderer
      // can draw them as indented bullet points beneath their parent item.
      final List<Map<String, dynamic>> printableItems = widget.orderItems
          .map<Map<String, dynamic>>((item) {
            final Map<String, dynamic> m = {
              'name': item['name'],
              'quantity': item['quantity'],
              'price': item['price'],
            };
            try {
              if (item.containsKey('extras') && item['extras'] != null) {
                m['extras'] = item['extras'];
              }
            } catch (_) {}
            // Add product-level discount if present
            try {
              if (item.containsKey('discountPercent') &&
                  item['discountPercent'] != null) {
                m['discountPercent'] = item['discountPercent'];
              }
              if (item.containsKey('discountAmount') &&
                  item['discountAmount'] != null) {
                m['discountAmount'] = item['discountAmount'];
              }
            } catch (_) {}
            return m;
          })
          .toList(growable: false);

      await ThermalInvoiceGenerator.directPrintThermalReceipt(
        context: parentContext,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        customerName: widget.selectedCustomer?['name'] ?? 'Walk-in Customer',
        items: printableItems,
        subtotal: widget.totalAmount - widget.taxAmount + widget.discountAmount,
        tax: widget.taxAmount,
        discount: widget.discountAmount,
        total: widget.totalAmount,
        paymentMethod: _getPaymentMethodName(paymentModeId),
        paidAmount: paidAmount,
        salesmanName: widget.selectedSalesman?['name'],
        advance: widget.initialAdvance,
        dueDate: widget.dueDate,
      );

      print('✅ Invoice sent to printer successfully!');
    } else if (result == 'close') {
      print('ℹ️ User skipped invoice generation');
    }
  }

  String _getPaymentMethodName(int paymentModeId) {
    switch (paymentModeId) {
      case 1:
        return 'Cash';
      case 2:
        return 'Bank';
      case 3:
        return 'Credit';
      default:
        return 'Unknown';
    }
  }

  void _validateAndShowPaymentDialog(Function showDialogFunction) {
    // Validate required details before showing payment dialog
    final validationErrors = <String>[];

    // Check if order has items
    if (widget.orderItems.isEmpty) {
      validationErrors.add(
        'Please add items to the order before processing payment',
      );
    }

    // Check if total amount is greater than 0
    if (widget.totalAmount <= 0) {
      validationErrors.add('Order total must be greater than 0');
    }

    // Check if salesman is selected (required for employee_id)
    if (widget.selectedSalesman == null) {
      validationErrors.add(
        'Please select a salesman before processing payment',
      );
    }

    // If there are validation errors, show them to the user
    if (validationErrors.isNotEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please complete the following before payment:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...validationErrors.map((error) => Text('• $error')),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // All validations passed, show the payment dialog
    showDialogFunction();
  }

  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: widget.isCustomOrder == true
                ? [
                    // Only show Credit for custom orders
                    _buildPaymentButton(
                      'Credit',
                      Icons.credit_card,
                      Colors.blue,
                      () => _validateAndShowPaymentDialog(
                        _showCreditPaymentDialog,
                      ),
                    ),
                  ]
                : [
                    _buildPaymentButton(
                      'Cash',
                      Icons.money,
                      Colors.green,
                      () =>
                          _validateAndShowPaymentDialog(_showCashPaymentDialog),
                    ),
                    const SizedBox(width: 12),
                    _buildPaymentButton(
                      'Credit',
                      Icons.credit_card,
                      Colors.blue,
                      () => _validateAndShowPaymentDialog(
                        _showCreditPaymentDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPaymentButton(
                      'Bank',
                      Icons.account_balance,
                      Colors.orange,
                      () =>
                          _validateAndShowPaymentDialog(_showBankPaymentDialog),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showCreditPaymentDialog() async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch credit customers from API
      final creditCustomers = await CreditCustomerService.getCreditCustomers();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show credit payment dialog with fetched data
      _showCreditPaymentDialogWithData(
        creditCustomers['data'] as List<Map<String, dynamic>>,
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to load credit customers: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showCreditPaymentDialogWithData(
    List<Map<String, dynamic>> creditCustomers,
  ) {
    String? selectedCustomerId;
    Map<String, dynamic>? selectedCustomer;
    double paidAmount = widget.initialAdvance ?? 0.0;
    String paymentMethod = 'Cash';

    // Bank payment related variables
    List<BankAccount> bankAccounts = [];
    bool isLoadingBankAccounts = false;
    String? selectedAdminBankAccountId;
    final TextEditingController customerBankNameController =
        TextEditingController();
    final TextEditingController customerAccountHolderNameController =
        TextEditingController();
    final TextEditingController customerAccountNumberController =
        TextEditingController();
    final TextEditingController paidAmountController = TextEditingController(
      text: paidAmount.toString(),
    );

    Future<void> _fetchBankAccounts(StateSetter setState) async {
      if (isLoadingBankAccounts) return;

      setState(() {
        isLoadingBankAccounts = true;
      });

      try {
        final response = await BankAccountService.getBankAccounts();
        setState(() {
          bankAccounts =
              response.data; // Show all bank accounts regardless of status
          isLoadingBankAccounts = false;
        });
      } catch (e) {
        print('Error fetching bank accounts: $e');
        setState(() {
          isLoadingBankAccounts = false;
        });
        // Show error message
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text('Failed to load bank accounts: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 850,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Compact)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF1A237E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.credit_card,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Credit Payment',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Process credit payment for customer',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content (Compact)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.63,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Selection Button (Compact)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Credit Customer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6C757D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  // Ask user whether to Search/Select or Add New
                                  final action = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => SimpleDialog(
                                      title: const Text('Credit Customer'),
                                      children: [
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop('search'),
                                          child: const Text('Search & Select'),
                                        ),
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop('add'),
                                          child: const Text(
                                            'Add New Credit Customer',
                                          ),
                                        ),
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(null),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (action == null) return;

                                  if (action == 'search') {
                                    final customer =
                                        await showDialog<Map<String, dynamic>>(
                                          context: context,
                                          builder: (context) =>
                                              const CustomerSearchDialog(),
                                        );

                                    if (customer != null) {
                                      setState(() {
                                        selectedCustomerId = customer['id']
                                            .toString();
                                        selectedCustomer = customer;
                                      });
                                      // Notify parent POS page about this selection
                                      try {
                                        widget.onSelectCreditCustomer?.call(
                                          customer,
                                        );
                                      } catch (_) {}
                                    }
                                  } else if (action == 'add') {
                                    // Show loading while fetching cities
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    List<Map<String, dynamic>> cities = [];
                                    try {
                                      final cityResp =
                                          await CityService.getAllCities(
                                            page: 1,
                                            perPage: 1000,
                                          );
                                      cities = cityResp.data
                                          .map(
                                            (c) => {
                                              'id': c.id,
                                              'title': c.title,
                                            },
                                          )
                                          .toList();
                                    } catch (e) {
                                      // ignore and pass empty list (dialog has fallback)
                                      cities = [];
                                    }

                                    // Close loading dialog
                                    Navigator.of(context).pop();

                                    // Open the existing CustomerFormDialog
                                    final created = await showDialog(
                                      context: context,
                                      builder: (context) =>
                                          CustomerFormDialog(cities: cities),
                                    );

                                    if (created != null) {
                                      if (created is Map<String, dynamic>) {
                                        setState(() {
                                          selectedCustomerId = created['id']
                                              ?.toString();
                                          selectedCustomer = created;
                                        });

                                        // Notify parent POS page about new customer
                                        try {
                                          widget.onSelectCreditCustomer?.call(
                                            created,
                                          );
                                        } catch (_) {}

                                        // Also add to local creditCustomers list so UI shows recent record
                                        try {
                                          creditCustomers.insert(0, created);
                                        } catch (_) {}
                                      } else if (created == true) {
                                        // Fallback: refresh the credit customers and select last created by name
                                        try {
                                          final all =
                                              await CreditCustomerService.getAllCreditCustomers();
                                          if (all.isNotEmpty) {
                                            final newest = all.first;
                                            setState(() {
                                              selectedCustomerId = newest['id']
                                                  ?.toString();
                                              selectedCustomer = newest;
                                              creditCustomers.insert(0, newest);
                                            });
                                          }
                                        } catch (_) {}
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[400]!,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_search,
                                        color: Color(0xFF0D1845),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: selectedCustomer != null
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    selectedCustomer!['name']
                                                            ?.toString() ??
                                                        'Unknown Customer',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF343A40),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (selectedCustomer!['cell_no1'] !=
                                                          null &&
                                                      selectedCustomer!['cell_no1']
                                                          .toString()
                                                          .isNotEmpty)
                                                    Text(
                                                      selectedCustomer!['cell_no1']
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                ],
                                              )
                                            : Text(
                                                'Search and Select Customer',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.grey[400],
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Existing Credit Records (Compact)
                        if (selectedCustomer != null &&
                            selectedCustomer!['paymentRecords'] != null &&
                            selectedCustomer!['paymentRecords'].isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Existing Credit Records',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF343A40),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 180, // Compact height
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: DataTable(
                                        headingRowColor:
                                            MaterialStateProperty.all(
                                              Color(0xFFF8F9FA),
                                            ),
                                        dataRowMinHeight: 38, // More compact
                                        dataRowMaxHeight: 50,
                                        columnSpacing: 16,
                                        headingTextStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        dataTextStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                        columns: const [
                                          DataColumn(
                                            label: Text(
                                              'Invoice #',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Date',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Total Amount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Paid Amount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Pending Amount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: selectedCustomer!['paymentRecords']
                                            .map<DataRow>((record) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      record['invoiceNumber'],
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      DateFormat(
                                                        'dd/MM/yyyy',
                                                      ).format(
                                                        DateTime.parse(
                                                          record['date'],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      'Rs${record['totalAmount'].toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF28A745,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      'Rs${record['paidAmount'].toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF17A2B8,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      'Rs${record['pendingAmount'].toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFFDC3545,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // New Payment Section (Compact)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Color(0xFFDEE2E6)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.payment,
                                    color: Color(0xFF0D1845),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'New Payment Entry',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF343A40),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Total Bill Amount (Compact)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFDEE2E6)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Bill Amount:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF343A40),
                                      ),
                                    ),
                                    Text(
                                      'Rs${widget.totalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF28A745),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Paid Amount and Pending Amount Row (Compact)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: paidAmountController,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Paid Amount',
                                        labelStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                        prefixText: 'Rs ',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onTap: () {
                                        // Select all text when field is tapped
                                        paidAmountController
                                            .selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset:
                                              paidAmountController.text.length,
                                        );
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          paidAmount =
                                              double.tryParse(value) ?? 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Pending Amount:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF343A40),
                                            ),
                                          ),
                                          Text(
                                            'Rs${(widget.totalAmount - paidAmount).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  paidAmount >=
                                                      widget.totalAmount
                                                  ? Color(0xFF28A745)
                                                  : Color(0xFFDC3545),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Payment Method Selection (Compact)
                              DropdownButtonFormField<String>(
                                value: paymentMethod,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Payment Method',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: ['Cash', 'Bank'].map((method) {
                                  return DropdownMenuItem<String>(
                                    value: method,
                                    child: Row(
                                      children: [
                                        Icon(
                                          method == 'Cash'
                                              ? Icons.money
                                              : Icons.account_balance,
                                          color: method == 'Cash'
                                              ? Color(0xFF28A745)
                                              : Color(0xFF17A2B8),
                                          size: 17,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          method,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    paymentMethod = value!;
                                    // Reset bank-related fields when switching payment methods
                                    if (value == 'Cash') {
                                      selectedAdminBankAccountId = null;
                                      customerBankNameController.clear();
                                      customerAccountHolderNameController
                                          .clear();
                                      customerAccountNumberController.clear();
                                    }
                                  });
                                },
                              ),

                              // Bank Payment Fields (only show when Bank is selected)
                              if (paymentMethod == 'Bank') ...[
                                const SizedBox(height: 16),

                                // Fetch bank accounts when Bank is selected
                                Builder(
                                  builder: (context) {
                                    // Fetch bank accounts when this section is built
                                    if (bankAccounts.isEmpty &&
                                        !isLoadingBankAccounts) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            _fetchBankAccounts(setState);
                                          });
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Admin Bank Account Dropdown (Compact)
                                        DropdownButtonFormField<String>(
                                          value: selectedAdminBankAccountId,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Admin Bank Account',
                                            labelStyle: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            hintText:
                                                'Select admin bank account',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.account_balance,
                                              size: 18,
                                            ),
                                          ),
                                          items: () {
                                            // Remove duplicate bank accounts based on ID
                                            final seen = <int>{};
                                            final uniqueAccounts = bankAccounts
                                                .where((account) {
                                                  if (seen.contains(
                                                    account.id,
                                                  )) {
                                                    return false;
                                                  }
                                                  seen.add(account.id);
                                                  return true;
                                                })
                                                .toList();

                                            return uniqueAccounts.map((
                                              account,
                                            ) {
                                              return DropdownMenuItem<String>(
                                                value: account.id.toString(),
                                                child: Text(
                                                  '${account.accHolderName} - ${account.accNo} (${account.accType})',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            }).toList();
                                          }(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedAdminBankAccountId =
                                                  value;
                                            });
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // Customer Bank Name (Compact)
                                        TextFormField(
                                          controller:
                                              customerBankNameController,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            labelText: 'Customer Bank Name',
                                            labelStyle: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            hintText:
                                                'Enter customer bank name',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.business,
                                              size: 18,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {});
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // Customer Account Holder Name (Compact)
                                        TextFormField(
                                          controller:
                                              customerAccountHolderNameController,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            labelText:
                                                'Customer Account Holder Name',
                                            labelStyle: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            hintText:
                                                'Enter account holder name',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.person,
                                              size: 18,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {});
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // Customer Account Number (Compact)
                                        TextFormField(
                                          controller:
                                              customerAccountNumberController,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            labelText:
                                                'Customer Account Number',
                                            labelStyle: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            hintText: 'Enter account number',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.account_box,
                                              size: 18,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {});
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // Amount Paid (separate from the main paid amount)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Amount Paid:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF343A40),
                                                ),
                                              ),
                                              Text(
                                                'Rs${paidAmount.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF28A745),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        // Amount Remaining
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Amount Remaining:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF343A40),
                                                ),
                                              ),
                                              Text(
                                                'Rs${(widget.totalAmount - paidAmount).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      paidAmount >=
                                                          widget.totalAmount
                                                      ? Color(0xFF28A745)
                                                      : Color(0xFFDC3545),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons (Compact)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    selectedCustomerId != null &&
                                        paidAmount >= 0 &&
                                        paidAmount <= widget.totalAmount &&
                                        (paymentMethod == 'Cash' ||
                                            (paymentMethod == 'Bank' &&
                                                selectedAdminBankAccountId !=
                                                    null &&
                                                customerBankNameController.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                customerAccountHolderNameController
                                                    .text
                                                    .trim()
                                                    .isNotEmpty &&
                                                customerAccountNumberController
                                                    .text
                                                    .trim()
                                                    .isNotEmpty))
                                    ? () async {
                                        // Get the selected bank account's coa_id for bank payments
                                        int? bankAccountId;
                                        if (paymentMethod == 'Bank' &&
                                            selectedAdminBankAccountId !=
                                                null) {
                                          final selectedBankAccount =
                                              bankAccounts.firstWhere(
                                                (account) =>
                                                    account.id.toString() ==
                                                    selectedAdminBankAccountId,
                                                orElse: () => BankAccount(
                                                  id: -1,
                                                  coaId: '',
                                                  transactionType: '',
                                                  accHolderName: '',
                                                  accNo: '',
                                                  accType: '',
                                                  opBalance: '',
                                                  note: '',
                                                  status: '',
                                                ),
                                              );
                                          if (selectedBankAccount.id != -1) {
                                            bankAccountId = int.tryParse(
                                              selectedBankAccount.coaId,
                                            );
                                          }
                                        }

                                        await _processPosPayment(
                                          paymentModeId: 3, // Credit customer
                                          paidAmount: paidAmount,
                                          creditCustomerId: int.tryParse(
                                            selectedCustomerId ?? '',
                                          ),
                                          bankAccountId: bankAccountId,
                                        );
                                        Navigator.of(context).pop();
                                        // PDF is already generated in _processPosPayment, no need to show print dialog
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D1845),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Process Credit Payment',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCashPaymentDialog() {
    double receivedAmount = widget.initialAdvance ?? 0.0;
    final TextEditingController amountController = TextEditingController(
      text: widget.initialAdvance != null && widget.initialAdvance! > 0
          ? widget.initialAdvance!.toStringAsFixed(2)
          : '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.money,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cash Payment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Total Amount Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rs${widget.totalAmount.round()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (widget.roundOffAmount != 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Round-off:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Rs${widget.roundOffAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Amount Input
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Paying Amount',
                    labelStyle: const TextStyle(fontSize: 13),
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      receivedAmount = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
                const SizedBox(height: 14),
                // Change Display
                if (receivedAmount >= widget.totalAmount)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Change:',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Rs${(receivedAmount - widget.totalAmount).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: receivedAmount >= widget.totalAmount
                            ? () async {
                                await _processPosPayment(
                                  paymentModeId: 1,
                                  paidAmount: receivedAmount,
                                );
                                Navigator.of(context).pop();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Complete Payment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bank Account Search Dialog
  Future<BankAccount?> _showBankAccountSearchDialog(
    BuildContext parentContext,
  ) async {
    List<BankAccount> allBankAccounts = [];
    List<BankAccount> filteredBankAccounts = [];
    final TextEditingController searchController = TextEditingController();

    // Fetch bank accounts
    try {
      final response = await BankAccountService.getBankAccounts();
      allBankAccounts = response.data;
      filteredBankAccounts = List.from(allBankAccounts);
    } catch (e) {
      print('Error loading bank accounts: $e');
    }

    return showDialog<BankAccount>(
      context: parentContext,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterBankAccounts(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredBankAccounts = List.from(allBankAccounts);
                } else {
                  filteredBankAccounts = allBankAccounts.where((account) {
                    final holderName = account.accHolderName.toLowerCase();
                    final accountNo = account.accNo.toLowerCase();
                    final bankName = account.transactionType.toLowerCase();
                    final searchQuery = query.toLowerCase();
                    return holderName.contains(searchQuery) ||
                        accountNo.contains(searchQuery) ||
                        bankName.contains(searchQuery);
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
                            Icons.account_balance,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Bank Account',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
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
                          hintText: 'Search by name, account number or bank...',
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
                        onChanged: _filterBankAccounts,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bank Account List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 350),
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
                        child: filteredBankAccounts.isEmpty
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
                                        'No bank accounts found',
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
                                itemCount: filteredBankAccounts.length,
                                itemBuilder: (context, index) {
                                  final account = filteredBankAccounts[index];
                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop(account);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.account_balance_wallet,
                                              color: Color(0xFF0D1845),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  account.accHolderName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${account.transactionType} - ${account.accNo}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: Color(0xFF0D1845),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
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

  void _showBankPaymentDialog() async {
    double receivedAmount = widget.initialAdvance ?? 0.0;
    final TextEditingController amountController = TextEditingController(
      text: widget.initialAdvance != null && widget.initialAdvance! > 0
          ? widget.initialAdvance!.toStringAsFixed(2)
          : '',
    );
    final TextEditingController senderBankNameController =
        TextEditingController();
    final TextEditingController accountHolderNameController =
        TextEditingController();
    final TextEditingController accountNumberController =
        TextEditingController();

    // Fetch admin bank details
    Map<String, String> adminBankDetails = {
      'accountTitle': 'Loading...',
      'bankName': 'Loading...',
      'accountNumber': 'Loading...',
      'branchCode': 'Loading...',
    };

    // Store selected bank account
    BankAccount? selectedBankAccount;

    bool isLoadingBankDetails = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Fetch bank details on first build
            if (isLoadingBankDetails) {
              BankAccountService.getAdminBankAccount()
                  .then((details) {
                    setState(() {
                      adminBankDetails = details;
                      isLoadingBankDetails = false;
                    });
                  })
                  .catchError((error) {
                    setState(() {
                      adminBankDetails = {
                        'accountTitle': 'Error loading',
                        'bankName': 'Error loading',
                        'accountNumber': 'Error loading',
                        'branchCode': 'Error loading',
                      };
                      isLoadingBankDetails = false;
                    });
                  });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 580,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header (Compact)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0D1845), Color(0xFF1A237E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bank Transfer Payment',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Transfer amount to admin account',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.all(6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content (Compact)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Total Amount Display (Compact)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFDEE2E6),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF343A40),
                                    ),
                                  ),
                                  Text(
                                    'Rs ${widget.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF28A745),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Admin/Business Bank Account Section (Compact)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance,
                                        color: const Color(0xFF1976D2),
                                        size: 17,
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          'Admin Bank Account (Receiver)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1976D2),
                                          ),
                                        ),
                                      ),
                                      // Select Bank Account Button (Compact)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final selectedAccount =
                                              await _showBankAccountSearchDialog(
                                                context,
                                              );
                                          if (selectedAccount != null) {
                                            setState(() {
                                              selectedBankAccount =
                                                  selectedAccount;
                                              adminBankDetails = {
                                                'accountTitle': selectedAccount
                                                    .accHolderName,
                                                'bankName': selectedAccount
                                                    .transactionType,
                                                'accountNumber':
                                                    selectedAccount.accNo,
                                                'branchCode':
                                                    selectedAccount
                                                        .note
                                                        .isNotEmpty
                                                    ? selectedAccount.note
                                                    : 'N/A',
                                              };
                                            });
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.search,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Select',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1976D2,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Account Title
                                  _buildReadOnlyField(
                                    label: 'Account Title',
                                    value: adminBankDetails['accountTitle']!,
                                    icon: Icons.business,
                                  ),

                                  const SizedBox(height: 10),

                                  // Bank Name
                                  _buildReadOnlyField(
                                    label: 'Bank Name',
                                    value: adminBankDetails['bankName']!,
                                    icon: Icons.account_balance,
                                  ),

                                  const SizedBox(height: 10),

                                  // Account Number
                                  _buildReadOnlyField(
                                    label: 'Account Number',
                                    value: adminBankDetails['accountNumber']!,
                                    icon: Icons.credit_card,
                                  ),

                                  const SizedBox(height: 10),

                                  // Branch Code
                                  _buildReadOnlyField(
                                    label: 'Branch Code',
                                    value: adminBankDetails['branchCode']!,
                                    icon: Icons.location_on,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Sender's Bank Details Section (Compact)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFDEE2E6),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.send,
                                        color: const Color(0xFF0D1845),
                                        size: 17,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Sender\'s Details',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF343A40),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Sender's Bank Name (Compact)
                                  TextField(
                                    controller: senderBankNameController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Bank Name',
                                      labelStyle: const TextStyle(fontSize: 12),
                                      hintText: 'Enter sender\'s bank name',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.account_balance,
                                        size: 18,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Account Holder's Name (Compact)
                                  TextField(
                                    controller: accountHolderNameController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Account Holder Name',
                                      labelStyle: const TextStyle(fontSize: 12),
                                      hintText: 'Enter sender\'s name',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.person,
                                        size: 18,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Account Number (Compact)
                                  TextField(
                                    controller: accountNumberController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Account Number',
                                      labelStyle: const TextStyle(fontSize: 12),
                                      hintText:
                                          'Enter sender\'s account number',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.account_box,
                                        size: 18,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Paid Amount (Compact)
                                  TextField(
                                    controller: amountController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Paid Amount',
                                      labelStyle: const TextStyle(fontSize: 12),
                                      hintText: 'Enter transferred amount',
                                      prefixText: 'Rs ',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.payments,
                                        size: 18,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        receivedAmount =
                                            double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 12),

                                  // Balance Display (Compact)
                                  if (receivedAmount >= widget.totalAmount)
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Change Amount:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Rs ${(receivedAmount - widget.totalAmount).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Action Buttons (Compact)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      side: const BorderSide(
                                        color: Colors.grey,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        receivedAmount >= widget.totalAmount &&
                                            accountHolderNameController.text
                                                .trim()
                                                .isNotEmpty &&
                                            accountNumberController.text
                                                .trim()
                                                .isNotEmpty &&
                                            senderBankNameController.text
                                                .trim()
                                                .isNotEmpty
                                        ? () async {
                                            await _processPosPayment(
                                              paymentModeId: 2, // Bank
                                              paidAmount: receivedAmount,
                                              bankAccountId: int.tryParse(
                                                selectedBankAccount?.coaId ??
                                                    '',
                                              ),
                                            );
                                            Navigator.of(context).pop();
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D1845),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Complete Bank Payment',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  // Helper method to build read-only fields
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
