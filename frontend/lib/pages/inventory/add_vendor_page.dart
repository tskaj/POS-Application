import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../services/inventory_service.dart';
import '../../services/city_service.dart';
import '../../models/city.dart' as cityModel;

// Custom input formatter for CNIC with automatic dashes
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.length > 13) {
      return oldValue;
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 5 || i == 12) {
        formatted += '-';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Custom input formatter for phone number with +92 prefix
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Limit to +92 prefix + 10 digits (14 characters total)
    if (text.length > 14) {
      return oldValue;
    }

    // Always ensure +92 prefix is present
    if (!text.startsWith('+92 ')) {
      if (text.startsWith('+92')) {
        // If it starts with +92 but no space, add space
        final formatted = '+92 ' + text.substring(3);
        if (formatted.length > 14) {
          return oldValue;
        }
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      } else if (text.startsWith('92')) {
        // If it starts with 92, replace with +92
        final formatted = '+92 ' + text.substring(2);
        if (formatted.length > 14) {
          return oldValue;
        }
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      } else {
        // Add +92 prefix to any other input
        final formatted = '+92 ' + text;
        if (formatted.length > 14) {
          return oldValue;
        }
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    // Allow backspace to remove characters after +92
    if (oldValue.text.length > newValue.text.length && newValue.text == '+92') {
      return TextEditingValue(
        text: '+92 ',
        selection: TextSelection.collapsed(offset: '+92 '.length),
      );
    }

    return newValue;
  }
}

class AddVendorPage extends StatefulWidget {
  const AddVendorPage({super.key});

  @override
  State<AddVendorPage> createState() => _AddVendorPageState();

  // Static method to show the dialog
  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AddVendorPage();
      },
    );
  }
}

class _AddVendorPageState extends State<AddVendorPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: '+92 ');
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  String _selectedStatus = 'Active';
  int? _selectedCityId; // Changed to nullable
  bool _isLoading = false;
  Map<String, String> _fieldErrors = {}; // Store field-specific errors
  String? _emailError; // Store email validation error

  late AnimationController _submitAnimation;

  // City data - now dynamic
  List<cityModel.City> _cities = [];
  bool _isLoadingCities = false;
  TextEditingController? _autocompleteController; // Controller for Autocomplete

  @override
  void initState() {
    super.initState();
    _autocompleteController = TextEditingController();
    _submitAnimation = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _loadCities(); // Load cities on init
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cnicController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingBalanceController.dispose();
    _autocompleteController?.dispose();
    _submitAnimation.dispose();
    super.dispose();
  }

  // Load cities from API
  Future<void> _loadCities() async {
    setState(() {
      _isLoadingCities = true;
    });

    try {
      final response = await CityService.getAllCities();
      if (response.success) {
        setState(() {
          _cities = response.data;
          // Don't set default city - let user choose
        });
      } else {
        // Handle error - maybe show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load cities'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading cities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load cities'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCities = false;
        });
      }
    }
  }

  // Show city search dialog
  Future<void> _showCitySearchDialog() async {
    List<cityModel.City> filteredCities = List.from(_cities);
    final TextEditingController searchController = TextEditingController();

    final selectedCity = await showDialog<cityModel.City?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterCities(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredCities = List.from(_cities);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredCities = _cities.where((city) {
                    final title = city.title.toLowerCase();
                    return title.contains(searchQuery);
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
                            Icons.location_city,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select City',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                          ),
                        ),
                        // Add City Button
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF28A745),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              // Open add-city dialog on top. If a city is created,
                              // return it to the caller of the search dialog so
                              // the Add Vendor form can update immediately.
                              final createdCity = await _showAddCityDialog();
                              if (createdCity != null) {
                                Navigator.of(context).pop(createdCity);
                              }
                            },
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Add New City',
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
                          hintText: 'Search by city name...',
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
                        onChanged: _filterCities,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // City List
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
                        child: filteredCities.isEmpty
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
                                        'No cities found',
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
                                itemCount: filteredCities.length,
                                itemBuilder: (context, index) {
                                  final city = filteredCities[index];
                                  final isSelected = city.id == _selectedCityId;

                                  return InkWell(
                                    onTap: () {
                                      // Return the selected city to the caller so parent can update
                                      Navigator.of(context).pop(city);
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
                                            index < filteredCities.length - 1
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
                                                  city.title,
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
                                                  '${city.state.title}, ${city.state.country.title}',
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

    // Update parent state with returned selection so the chosen city label
    // updates immediately in the form (was only visible after form submit).
    if (selectedCity != null && mounted) {
      setState(() {
        _selectedCityId = selectedCity.id;
        _fieldErrors.remove('city');
        _autocompleteController?.text = selectedCity.title;
      });
    }
  }

  Future<cityModel.City?> _showAddCityDialog() async {
    final TextEditingController cityController = TextEditingController();
    final GlobalKey<FormState> cityFormKey = GlobalKey<FormState>();
    bool isAdding = false;

    final createdCity = await showDialog<cityModel.City?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Add New City'),
              content: Form(
                key: cityFormKey,
                child: TextFormField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City Name',
                    hintText: 'Enter city name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter city name';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          if (!cityFormKey.currentState!.validate()) return;

                          setState(() => isAdding = true);

                          try {
                            // Create city with default state_id and status
                            final response = await CityService.createCity(
                              title: cityController.text.trim(),
                              stateId: 1, // Default state ID
                              status: 'active',
                            );

                            if (response.success) {
                              // Reload cities to include the new one
                              await _loadCities();

                              // Return the newly created city to the caller so the
                              // parent can update its UI immediately.
                              if (context.mounted) {
                                Navigator.of(context).pop(response.data);
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to create city'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            print('Error creating city: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to create city'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => isAdding = false);
                            }
                          }
                        },
                  child: isAdding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add City'),
                ),
              ],
            );
          },
        );
      },
    );

    // Return the created city (if any) to the caller so upstream callers
    // (like the city search dialog or the Add Vendor form) can update
    // their UI immediately.
    return createdCity;
  }

  // Helper method to create clean InputDecoration
  InputDecoration _buildCleanInputDecoration(
    String label, {
    bool isRequired = false,
    String? hint,
    IconData? prefixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isRequired ? Colors.black87 : Colors.grey[700],
        fontWeight: isRequired ? FontWeight.w500 : FontWeight.w400,
        fontSize: 14,
      ),
      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D1845), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey[600])
          : null,
    );
  }

  // Helper method to create clean DropdownButtonFormField decoration
  InputDecoration _buildCleanDropdownDecoration(
    String label, {
    bool isRequired = false,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      labelStyle: TextStyle(
        color: isRequired ? Colors.black87 : Colors.grey[700],
        fontWeight: isRequired ? FontWeight.w500 : FontWeight.w400,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D1845), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey[600])
          : null,
    );
  }

  // Vendor Information Section
  Widget _buildVendorInformationSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1845).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Color(0xFF0D1845),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Vendor Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Form Content
          Padding(
            padding: const EdgeInsets.all(16), // Reduced from 20 to 16
            child: Column(
              children: [
                // First Row: First Name and Last Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First Name
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: _buildCleanInputDecoration(
                            'First Name',
                            isRequired: true,
                            prefixIcon: Icons.person,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter first name';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    // Last Name
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 12),
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: _buildCleanInputDecoration(
                            'Last Name',
                            isRequired: false,
                            prefixIcon: Icons.person,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          // Last name is optional per requirements
                          validator: (value) {
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Reduced from 20 to 16
                // Second Row: CNIC and Email
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CNIC
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: TextFormField(
                          controller: _cnicController,
                          decoration: _buildCleanInputDecoration(
                            'CNIC',
                            hint: '12345-1234567-1',
                            prefixIcon: Icons.credit_card,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CnicInputFormatter(),
                            LengthLimitingTextInputFormatter(
                              15,
                            ), // 13 digits + 2 dashes
                          ],
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final cleanCnic = value.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );

                              if (cleanCnic.length != 13) {
                                return 'CNIC must be exactly 13 digits';
                              }

                              final cnicRegex = RegExp(r'^\d{5}\d{7}\d{1}$');
                              if (!cnicRegex.hasMatch(cleanCnic)) {
                                return 'Invalid CNIC format';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    // Email
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 12),
                        child: TextFormField(
                          controller: _emailController,
                          decoration: _buildCleanInputDecoration(
                            'Email',
                            hint: 'vendor@example.com',
                            prefixIcon: Icons.email,
                            errorText: _emailError,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            // Immediate validation for @ symbol
                            if (value.trim().isNotEmpty &&
                                !value.contains('@')) {
                              setState(() {
                                _emailError = 'Email must contain @ symbol';
                              });
                            } else {
                              setState(() {
                                _emailError = null;
                              });
                            }
                          },
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final emailRegex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Reduced from 20 to 16
                // Third Row: Phone and City
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: _buildCleanInputDecoration(
                            'Phone',
                            isRequired: true,
                            hint: '300 1234567',
                            prefixIcon: Icons.phone,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            PhoneInputFormatter(),
                            LengthLimitingTextInputFormatter(
                              14,
                            ), // +92 + space + 10 digits
                          ],
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty ||
                                value.trim() == '+92') {
                              return 'Please enter phone number';
                            }
                            final phoneNumber = value.replaceAll('+92 ', '');
                            if (phoneNumber.length < 10) {
                              return 'Please enter a valid 10-digit phone number';
                            }
                            if (phoneNumber.length > 10) {
                              return 'Phone number cannot exceed 10 digits';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    // City
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 12),
                        child: _isLoadingCities
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Loading cities...'),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: OutlinedButton(
                                  onPressed: _showCitySearchDialog,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    backgroundColor: Colors.white,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.centerLeft,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedCityId != null &&
                                                  _cities.isNotEmpty
                                              ? (() {
                                                  try {
                                                    final selectedCity = _cities
                                                        .firstWhere(
                                                          (c) =>
                                                              c.id ==
                                                              _selectedCityId,
                                                        );
                                                    return '${selectedCity.title}, ${selectedCity.state.title}';
                                                  } catch (e) {
                                                    return 'Select City *';
                                                  }
                                                })()
                                              : 'Select City *',
                                          style: TextStyle(
                                            color: _selectedCityId != null
                                                ? Colors.black87
                                                : Colors.grey[700],
                                            fontSize: 14,
                                            fontWeight: _selectedCityId != null
                                                ? FontWeight.w400
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                // Show inline city error if present (city selector is not a FormField)
                if (_fieldErrors.containsKey('city'))
                  Padding(
                    padding: const EdgeInsets.only(left: 0, top: 8, bottom: 8),
                    child: Text(
                      _fieldErrors['city']!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16), // Reduced from 20 to 16
                // Fourth Row: Address (Full Width)
                TextFormField(
                  controller: _addressController,
                  decoration: _buildCleanInputDecoration(
                    'Address',
                    hint: 'Enter complete address',
                    prefixIcon: Icons.home,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
                  maxLines: 2, // Reduced from 3 to 2 for more compact layout
                ),
                const SizedBox(height: 16), // Reduced from 20 to 16
                // Fifth Row: Opening Balance (Full Width)
                TextFormField(
                  controller: _openingBalanceController,
                  decoration: _buildCleanInputDecoration(
                    'Opening Balance',
                    isRequired: true,
                    hint: '0.00',
                    prefixIcon: Icons.account_balance_wallet,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    if (_fieldErrors.containsKey('opening_balance')) {
                      setState(() {
                        _fieldErrors.remove('opening_balance');
                      });
                    }
                  },
                  validator: (value) {
                    if (_fieldErrors.containsKey('opening_balance')) {
                      return _fieldErrors['opening_balance'];
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'Opening balance is required';
                    }
                    final balance = double.tryParse(value.trim());
                    if (balance == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16), // Reduced from 20 to 16
                // Sixth Row: Status (Full Width)
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: _buildCleanDropdownDecoration(
                    'Status',
                    isRequired: true,
                    prefixIcon: Icons.toggle_on,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
                  items: ['Active', 'Inactive'].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'Active' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a status';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Submit Section
  Widget _buildSubmitSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _submitAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _submitAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _isLoading
                      ? null
                      : LinearGradient(
                          colors: [
                            const Color(0xFF28A745),
                            const Color(0xFF20B545),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isLoading
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF28A745).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Create Vendor',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Colors.white,
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
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Ensure city is selected (city field is an OutlinedButton, not a FormField)
    if (_selectedCityId == null) {
      setState(() {
        _fieldErrors['city'] = 'Please select a city';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldErrors.clear();
    });

    try {
      // If user didn't provide CNIC, send null so backend receives a null value
      // (we remove null entries later from the map so the field will be omitted).
      final cnicToSend = _cnicController.text.trim().isNotEmpty
          ? _cnicController.text.trim()
          : null;

      final vendorData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'cnic': cnicToSend,
        'city_id': _selectedCityId,
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'phone':
            _phoneController.text.trim().isNotEmpty &&
                _phoneController.text.trim() != '+92'
            ? _phoneController.text.replaceAll('+92 ', '')
            : null,
        // If address not provided, send a dummy placeholder to satisfy backend
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : 'N/A',
        'status': _selectedStatus,
        'opening_balance': double.parse(_openingBalanceController.text.trim()),
      };

      vendorData.removeWhere((key, value) => value == null);

      final response = await InventoryService.createVendor(vendorData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Vendor created successfully'),
              ],
            ),
            backgroundColor: Color(0xFF28A745),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.of(context).pop(response); // Return the created vendor data
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to create vendor';
        bool hasFieldErrors = false;

        if (e.toString().contains('Inventory API failed')) {
          try {
            final errorParts = e.toString().split(' - ');
            if (errorParts.length >= 2) {
              final responseBody = errorParts[1];
              final errorData = jsonDecode(responseBody);

              if (errorData is Map<String, dynamic>) {
                if (errorData.containsKey('errors') &&
                    errorData['errors'] is Map<String, dynamic>) {
                  final errors = errorData['errors'] as Map<String, dynamic>;
                  setState(() {
                    _fieldErrors = errors.map((key, value) {
                      if (value is List && value.isNotEmpty) {
                        return MapEntry(key, value.first.toString());
                      }
                      return MapEntry(key, value.toString());
                    });
                  });
                  hasFieldErrors = true;
                  _formKey.currentState!.validate();
                } else if (errorData.containsKey('message')) {
                  errorMessage = errorData['message'];
                }
              }
            }
          } catch (parseError) {
            errorMessage = e.toString();
          }
        } else {
          errorMessage = e.toString();
        }

        if (!hasFieldErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Color(0xFFDC3545),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isWideScreen ? 600 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1845),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.business,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Vendor',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(null),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Body - Non-scrollable
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vendor Information Section
                    _buildVendorInformationSection(theme),

                    const SizedBox(height: 20),

                    // Submit Button
                    _buildSubmitSection(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
