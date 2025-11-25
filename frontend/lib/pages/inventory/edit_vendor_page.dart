import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../services/inventory_service.dart';
import '../../services/city_service.dart';
import '../../models/vendor.dart' as vendor;
import '../../models/city.dart' as cityModel;

class EditVendorPage extends StatefulWidget {
  final vendor.Vendor vendorData;

  const EditVendorPage({super.key, required this.vendorData});

  @override
  State<EditVendorPage> createState() => _EditVendorPageState();

  // Static method to show the dialog
  static Future<bool?> show(BuildContext context, vendor.Vendor vendorData) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return EditVendorPage(vendorData: vendorData);
      },
    );
  }
}

class _EditVendorPageState extends State<EditVendorPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedStatus = 'Active';
  int? _selectedCityId; // Changed to nullable
  bool _isLoading = false;
  Map<String, String> _fieldErrors = {}; // Store field-specific errors

  // City data - now dynamic
  List<cityModel.City> _cities = [];
  bool _isLoadingCities = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill form with existing vendor data
    _firstNameController.text = widget.vendorData.firstName;
    _lastNameController.text = widget.vendorData.lastName;
    _cnicController.text = widget.vendorData.cnic ?? '';
    _emailController.text = widget.vendorData.email ?? '';
    // Handle phone number - remove +92 prefix if present and store only digits
    String phoneNumber = widget.vendorData.phone ?? '';
    if (phoneNumber.startsWith('+92')) {
      phoneNumber = phoneNumber.substring(3); // Remove +92 prefix
    }
    _phoneController.text = phoneNumber;
    _addressController.text = widget.vendorData.address ?? '';
    _selectedStatus = widget.vendorData.status;
    _selectedCityId = int.tryParse(widget.vendorData.cityId) ?? 1;
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
  void _showCitySearchDialog() {
    List<cityModel.City> filteredCities = List.from(_cities);
    final TextEditingController searchController = TextEditingController();

    showDialog(
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
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pop(); // Close search dialog
                              _showAddCityDialog(); // Open add city dialog
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
                                      setState(() {
                                        this.setState(() {
                                          _selectedCityId = city.id;
                                        });
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
  }

  void _showAddCityDialog() async {
    final TextEditingController cityController = TextEditingController();
    final GlobalKey<FormState> cityFormKey = GlobalKey<FormState>();
    bool isAdding = false;

    await showDialog(
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

                              // Set the newly created city as selected
                              if (mounted) {
                                setState(() {
                                  _selectedCityId = response.data.id;
                                });
                              }

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(response.message),
                                    backgroundColor: Colors.green,
                                  ),
                                );
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
  }

  Future<void> _submitForm() async {
    // Validate city selection
    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a city'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldErrors.clear(); // Clear previous field errors
    });

    try {
      final vendorData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'city_id': _selectedCityId,
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'phone': _phoneController.text.trim().isNotEmpty
            ? '+92${_phoneController.text.trim()}'
            : null,
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        'status': _selectedStatus,
      };

      // Remove null values
      vendorData.removeWhere((key, value) => value == null);

      await InventoryService.updateVendor(widget.vendorData.id, vendorData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Vendor updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF28A745),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to update vendor';
        bool hasFieldErrors = false;

        // Try to parse validation errors from the API response
        if (e.toString().contains('Inventory API failed')) {
          try {
            // Extract the response body from the error message
            final errorParts = e.toString().split(' - ');
            if (errorParts.length >= 2) {
              final responseBody = errorParts[1];
              final errorData = jsonDecode(responseBody);

              if (errorData is Map<String, dynamic>) {
                // Check for Laravel validation errors
                if (errorData.containsKey('errors') &&
                    errorData['errors'] is Map) {
                  final errors = errorData['errors'] as Map<String, dynamic>;
                  setState(() {
                    _fieldErrors.clear();
                    errors.forEach((field, messages) {
                      if (messages is List && messages.isNotEmpty) {
                        // Map API field names to form field names
                        String formField = field;
                        if (field == 'city_id') formField = 'city';
                        _fieldErrors[formField] = messages.first.toString();
                      }
                    });
                  });
                  hasFieldErrors = true;

                  // Clear CNIC field if there's a CNIC validation error
                  if (_fieldErrors.containsKey('cnic')) {
                    _cnicController.clear();
                  }

                  // Re-validate form to show field errors
                  _formKey.currentState!.validate();
                } else if (errorData.containsKey('message')) {
                  errorMessage = errorData['message'].toString();
                }
              }
            }
          } catch (parseError) {
            // If parsing fails, use the original error
            errorMessage = e.toString();
          }
        } else {
          errorMessage = e.toString();
        }

        // Only show snackbar if there are no field-specific errors
        if (!hasFieldErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Color(0xFFDC3545),
              duration: Duration(seconds: 4),
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
        width: isWideScreen ? 700 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
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
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Vendor',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update details for "${widget.vendorData.fullName}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _submitForm,
                      child: const Text(
                        'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Form Fields Container
                        Container(
                          padding: const EdgeInsets.all(20),
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
                              // First Name and Last Name Row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstNameController,
                                      decoration: InputDecoration(
                                        labelText: 'First Name *',
                                        hintText: 'Enter first name',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(Icons.person),
                                        errorText: _fieldErrors['first_name'],
                                      ),
                                      onChanged: (value) {
                                        if (_fieldErrors.containsKey(
                                          'first_name',
                                        )) {
                                          setState(() {
                                            _fieldErrors.remove('first_name');
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (_fieldErrors.containsKey(
                                          'first_name',
                                        )) {
                                          return _fieldErrors['first_name'];
                                        }
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'First name is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Last Name *',
                                        hintText: 'Enter last name',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(Icons.person),
                                        errorText: _fieldErrors['last_name'],
                                      ),
                                      onChanged: (value) {
                                        if (_fieldErrors.containsKey(
                                          'last_name',
                                        )) {
                                          setState(() {
                                            _fieldErrors.remove('last_name');
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (_fieldErrors.containsKey(
                                          'last_name',
                                        )) {
                                          return _fieldErrors['last_name'];
                                        }
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Last name is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // CNIC and Email Row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cnicController,
                                      decoration: InputDecoration(
                                        labelText: 'CNIC',
                                        hintText: '12345-1234567-1 (Optional)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(
                                          Icons.credit_card,
                                        ),
                                        errorText: _fieldErrors['cnic'],
                                      ),
                                      onChanged: (value) {
                                        if (_fieldErrors.containsKey('cnic')) {
                                          setState(() {
                                            _fieldErrors.remove('cnic');
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (_fieldErrors.containsKey('cnic')) {
                                          return _fieldErrors['cnic'];
                                        }
                                        // Only validate format if CNIC is provided
                                        if (value != null &&
                                            value.trim().isNotEmpty) {
                                          // Basic CNIC format validation
                                          final cnicRegex = RegExp(
                                            r'^\d{5}-\d{7}-\d{1}$',
                                          );
                                          if (!cnicRegex.hasMatch(
                                            value.trim(),
                                          )) {
                                            return 'Invalid CNIC format (xxxxx-xxxxxxx-x)';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'vendor@example.com',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(Icons.email),
                                        errorText: _fieldErrors['email'],
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (value) {
                                        if (_fieldErrors.containsKey('email')) {
                                          setState(() {
                                            _fieldErrors.remove('email');
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (_fieldErrors.containsKey('email')) {
                                          return _fieldErrors['email'];
                                        }
                                        if (value != null &&
                                            value.trim().isNotEmpty) {
                                          final emailRegex = RegExp(
                                            r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+$',
                                          );
                                          if (!emailRegex.hasMatch(
                                            value.trim(),
                                          )) {
                                            return 'Invalid email format';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Phone and Status Row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      decoration: InputDecoration(
                                        labelText: 'Phone',
                                        hintText: '3001234567 (10 digits)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(Icons.phone),
                                        prefixText: '+92 ',
                                        prefixStyle: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        errorText: _fieldErrors['phone'],
                                      ),
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      onChanged: (value) {
                                        if (_fieldErrors.containsKey('phone')) {
                                          setState(() {
                                            _fieldErrors.remove('phone');
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (_fieldErrors.containsKey('phone')) {
                                          return _fieldErrors['phone'];
                                        }
                                        if (value != null &&
                                            value.trim().isNotEmpty) {
                                          if (value.length != 10) {
                                            return 'Phone number must be exactly 10 digits';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedStatus,
                                      decoration: InputDecoration(
                                        labelText: 'Status *',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(Icons.toggle_on),
                                        errorText: _fieldErrors['status'],
                                      ),
                                      items: ['Active', 'Inactive'].map((
                                        status,
                                      ) {
                                        return DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedStatus = value;
                                            if (_fieldErrors.containsKey(
                                              'status',
                                            )) {
                                              _fieldErrors.remove('status');
                                            }
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (_fieldErrors.containsKey(
                                          'status',
                                        )) {
                                          return _fieldErrors['status'];
                                        }
                                        if (value == null || value.isEmpty) {
                                          return 'Status is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // City Row
                              _isLoadingCities
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                                          final selectedCity =
                                                              _cities.firstWhere(
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
                                                  fontWeight:
                                                      _selectedCityId != null
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
                              const SizedBox(height: 16),

                              // Address
                              TextFormField(
                                controller: _addressController,
                                decoration: InputDecoration(
                                  labelText: 'Address',
                                  hintText: 'Enter vendor address',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  prefixIcon: const Icon(Icons.home),
                                  errorText: _fieldErrors['address'],
                                ),
                                maxLines: 3,
                                onChanged: (value) {
                                  if (_fieldErrors.containsKey('address')) {
                                    setState(() {
                                      _fieldErrors.remove('address');
                                    });
                                  }
                                },
                                validator: (value) {
                                  if (_fieldErrors.containsKey('address')) {
                                    return _fieldErrors['address'];
                                  }
                                  return null;
                                },
                              ),
                            ], // close children of form fields Column
                          ), // close form fields Column
                        ), // close form fields Container
                      ], // close children of Form's Column
                    ), // close Form's Column
                  ), // close Form
                ), // close SingleChildScrollView
              ), // close body Container
            ), // close Flexible
          ], // close children of main Column
        ), // close main Column
      ), // close Dialog's Container
    ); // close Dialog
  }
}
