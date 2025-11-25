import 'package:flutter/material.dart';

class PosCategories extends StatefulWidget {
  final Function(String) onCategorySelected;
  final String selectedCategory;

  const PosCategories({
    super.key,
    required this.onCategorySelected,
    required this.selectedCategory,
  });

  @override
  State<PosCategories> createState() => _PosCategoriesState();
}

class _PosCategoriesState extends State<PosCategories> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'All', 'icon': Icons.category, 'count': 0},
    {'id': 'fruits', 'name': 'Fruits', 'icon': Icons.apple, 'count': 12},
    {
      'id': 'vegetables',
      'name': 'Vegetables',
      'icon': Icons.grass,
      'count': 18,
    },
    {'id': 'dairy', 'name': 'Dairy', 'icon': Icons.local_drink, 'count': 8},
    {'id': 'meat', 'name': 'Meat', 'icon': Icons.restaurant, 'count': 15},
    {'id': 'bakery', 'name': 'Bakery', 'icon': Icons.cake, 'count': 10},
    {
      'id': 'beverages',
      'name': 'Beverages',
      'icon': Icons.local_bar,
      'count': 20,
    },
    {'id': 'snacks', 'name': 'Snacks', 'icon': Icons.cookie, 'count': 25},
    {'id': 'household', 'name': 'Household', 'icon': Icons.home, 'count': 14},
    {
      'id': 'personal',
      'name': 'Personal Care',
      'icon': Icons.clean_hands,
      'count': 16,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0D1845)),
              onChanged: (value) {
                // TODO: Implement search functionality
              },
            ),
          ),

          const SizedBox(height: 12),

          // Categories Horizontal List
          SizedBox(
            height: 70, // Fixed height for the list
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = widget.selectedCategory == category['id'];

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => widget.onCategorySelected(category['id']),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80, // Smaller width
                      height: 60, // Smaller height
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0D1845)
                            : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0D1845)
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0D1845,
                                  ).withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category['icon'],
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF0D1845),
                            size: 16, // Smaller icon
                          ),
                          const SizedBox(height: 1),
                          Flexible(
                            child: Text(
                              category['name'],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF0D1845),
                                fontSize: 8, // Much smaller font
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (category['count'] > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${category['count']}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.teal,
                                  fontSize: 6, // Very small font
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
