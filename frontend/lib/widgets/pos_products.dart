import 'package:flutter/material.dart';

class PosProducts extends StatefulWidget {
  final String selectedCategory;
  final Function(Map<String, dynamic>) onProductSelected;

  const PosProducts({
    super.key,
    required this.selectedCategory,
    required this.onProductSelected,
  });

  @override
  State<PosProducts> createState() => _PosProductsState();
}

class _PosProductsState extends State<PosProducts> {
  final List<Map<String, dynamic>> _allProducts = [
    {
      'id': '1',
      'name': 'Apple',
      'category': 'fruits',
      'price': 2.50,
      'image': 'assets/images/products/apple.png',
      'stock': 50,
      'unit': 'kg',
    },
    {
      'id': '2',
      'name': 'Banana',
      'category': 'fruits',
      'price': 1.20,
      'image': 'assets/images/products/banana.png',
      'stock': 75,
      'unit': 'kg',
    },
    {
      'id': '3',
      'name': 'Orange',
      'category': 'fruits',
      'price': 3.00,
      'image': 'assets/images/products/orange.png',
      'stock': 40,
      'unit': 'kg',
    },
    {
      'id': '4',
      'name': 'Carrot',
      'category': 'vegetables',
      'price': 1.80,
      'image': 'assets/images/products/carrot.png',
      'stock': 60,
      'unit': 'kg',
    },
    {
      'id': '5',
      'name': 'Broccoli',
      'category': 'vegetables',
      'price': 4.50,
      'image': 'assets/images/products/broccoli.png',
      'stock': 25,
      'unit': 'kg',
    },
    {
      'id': '6',
      'name': 'Milk',
      'category': 'dairy',
      'price': 3.20,
      'image': 'assets/images/products/milk.png',
      'stock': 30,
      'unit': 'liter',
    },
    {
      'id': '7',
      'name': 'Chicken Breast',
      'category': 'meat',
      'price': 8.50,
      'image': 'assets/images/products/chicken.png',
      'stock': 20,
      'unit': 'kg',
    },
    {
      'id': '8',
      'name': 'Bread',
      'category': 'bakery',
      'price': 2.00,
      'image': 'assets/images/products/bread.png',
      'stock': 35,
      'unit': 'loaf',
    },
    {
      'id': '9',
      'name': 'Coca Cola',
      'category': 'beverages',
      'price': 1.50,
      'image': 'assets/images/products/coke.png',
      'stock': 100,
      'unit': 'can',
    },
    {
      'id': '10',
      'name': 'Chips',
      'category': 'snacks',
      'price': 2.80,
      'image': 'assets/images/products/chips.png',
      'stock': 45,
      'unit': 'bag',
    },
  ];

  List<Map<String, dynamic>> get _filteredProducts {
    if (widget.selectedCategory == 'all') {
      return _allProducts;
    }
    return _allProducts
        .where((product) => product['category'] == widget.selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // Reduced from 4 to 3 columns
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75, // Adjusted aspect ratio
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => widget.onProductSelected(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    product['image'],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.inventory_2,
                        size: 48,
                        color: Colors.grey[400],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Product Name
              Text(
                product['name'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1845),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Price and Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${product['price'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: product['stock'] > 10
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${product['stock']} ${product['unit']}',
                      style: TextStyle(
                        fontSize: 9, // Slightly smaller font
                        color: product['stock'] > 10
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis, // Prevent overflow
                      maxLines: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Add to Cart Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onProductSelected(product),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
