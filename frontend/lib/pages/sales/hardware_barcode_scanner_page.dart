import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../utils/barcode_utils.dart';
import '../../services/inventory_service.dart';
import '../../providers/providers.dart';

class HardwareBarcodeScanner extends StatefulWidget {
  const HardwareBarcodeScanner({super.key});

  @override
  State<HardwareBarcodeScanner> createState() => _HardwareBarcodeScannerState();
}

class _HardwareBarcodeScannerState extends State<HardwareBarcodeScanner> {
  final FocusNode _focusNode = FocusNode();
  String _scannedData = '';
  bool _isScanning = false;
  Product? _foundProduct;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (_scannedData.isNotEmpty) {
          _processScannedBarcode(_scannedData.trim());
          _scannedData = '';
        }
      } else if (key == LogicalKeyboardKey.backspace) {
        if (_scannedData.isNotEmpty) {
          setState(() {
            _scannedData = _scannedData.substring(0, _scannedData.length - 1);
          });
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        setState(() {
          _scannedData += event.character!;
          _isScanning = true;
        });
      }
    }
  }

  Future<void> _processScannedBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isScanning = false;
    });

    try {
      // Check if products are cached in InventoryProvider first
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      List<Product> productsToSearch;

      if (inventoryProvider.products.isNotEmpty) {
        // Use cached products
        productsToSearch = inventoryProvider.products;
      } else {
        // Fetch products and cache them
        final productsResponse = await InventoryService.getProducts(
          limit: 1000,
        );
        productsToSearch = productsResponse.data;
        inventoryProvider.setProducts(productsToSearch);
      }

      final candidates = generateBarcodeLookupCandidates(barcode);

      final foundProduct = productsToSearch.firstWhere(
        (product) {
          final pDesign = product.designCode.trim().toLowerCase();
          final pBarcode = product.barcode.trim().toLowerCase();
          final pId = product.id.toString();
          final pNumeric = getNumericBarcode(product);

          for (final cand in candidates) {
            if (cand == pDesign ||
                cand == pBarcode ||
                cand == pId ||
                cand == pNumeric) {
              return true;
            }
          }
          return false;
        },
        orElse: () => Product(
          id: 0,
          title: '',
          designCode: '',
          imagePath: '',
          imagePaths: [],
          subCategoryId: '',
          salePrice: '0.00',
          openingStockQuantity: '0',
          inStockQuantity: '0',
          vendorId: '',
          vendor: ProductVendor.empty(),
          barcode: '',
          status: '',
          createdAt: '',
          updatedAt: '',
        ),
      );

      if (foundProduct.id != 0) {
        setState(() {
          _foundProduct = foundProduct;
        });
      } else {
        _showProductNotFoundDialog(barcode);
      }
    } catch (e) {
      print('Error searching for product: $e');
      _showErrorDialog('Error searching for product. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text('No product found with barcode: $barcode'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _scannedData = '';
      _foundProduct = null;
      _isLoading = false;
      _isScanning = false;
    });
    _focusNode.requestFocus();
  }

  void _addProductToCart() {
    if (_foundProduct != null) {
      Navigator.of(context).pop(_foundProduct);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Barcode Scanner'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKeyEvent,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isScanning
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isScanning ? Colors.blue : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isScanning ? Icons.scanner : Icons.scanner_outlined,
                      size: 48,
                      color: _isScanning ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning
                          ? 'Receiving barcode data...'
                          : 'Ready to scan. Click here to focus.',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isScanning ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_scannedData.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Current input: $_scannedData',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hardware Scanner Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Connect your barcode scanner via USB/Bluetooth\n'
                      '• Ensure scanner is configured to send Enter key after scan\n'
                      '• Click the blue area above to focus input\n'
                      '• Scan barcode - product will be found automatically',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Searching for product...'),
                          ],
                        ),
                      )
                    : _foundProduct != null
                    ? _buildProductInfo()
                    : _buildWaitingState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.barcode_reader, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Waiting for barcode scan...',
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use your hardware barcode scanner',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    if (_foundProduct == null) return const SizedBox.shrink();

    final price = double.tryParse(_foundProduct!.salePrice) ?? 0.0;
    final stock = int.tryParse(_foundProduct!.inStockQuantity) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Found',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D1845),
          ),
        ),
        const SizedBox(height: 16),

        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1845).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _foundProduct!.imagePath?.isNotEmpty ?? false
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _foundProduct!.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.inventory_2, size: 40),
                    ),
                  )
                : const Icon(
                    Icons.inventory_2,
                    size: 40,
                    color: Color(0xFF0D1845),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          _foundProduct!.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Text(
              'Rs${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Stock: $stock',
              style: TextStyle(
                fontSize: 14,
                color: stock > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Barcode: $_scannedData',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),

        const Spacer(),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetScanner,
                child: const Text('Scan Again'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: stock > 0 ? _addProductToCart : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1845),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
