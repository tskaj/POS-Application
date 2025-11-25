import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/chart_of_accounts_service.dart';
import '../../providers/providers.dart';
import 'create_coa_page.dart';

class ChartOfAccountsPage extends StatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  State<ChartOfAccountsPage> createState() => _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends State<ChartOfAccountsPage> {
  // New: All COAs from API (now using provider cache)
  List<ChartOfAccount> _allCoas = [];
  List<ChartOfAccount> _filteredCoas = [];

  // Hierarchical data from new API (now using provider cache)
  List<MainHeadOfAccountWithSubs> _mainHeadAccountsWithSubs = [];
  List<SubHeadOfAccountWithAccounts> _subHeadAccountsWithAccounts = [];

  bool _isLoading = true;

  // Filter states
  AccountOfSubHead? _selectedHead;
  MainHeadOfAccountWithSubs?
  _selectedHierarchicalMainHead; // For hierarchical filtering
  SubHeadOfAccountWithAccounts? _selectedHierarchicalSubHead;

  // Pagination
  int currentPage = 1;
  final int itemsPerPage = 18;
  List<ChartOfAccount> _paginatedCoas = [];

  // Checkbox selection
  Set<int> _selectedCoaIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchAllChartOfAccountsOnInit();
  }

  // Fetch all chart of accounts on init, checking provider cache first
  Future<void> _fetchAllChartOfAccountsOnInit() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    if (financeProvider.chartOfAccounts.isNotEmpty) {
      // Use cached data
      setState(() {
        _allCoas = financeProvider.chartOfAccounts.cast<ChartOfAccount>();
        _filteredCoas = _allCoas;
        _applyPagination();
        _isLoading = false;
      });
      _loadMainHeadAccounts();
    } else {
      // Fetch from API
      await _loadMainHeadAccounts();
    }
  }

  // Load main head accounts
  Future<void> _loadMainHeadAccounts() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    try {
      setState(() {
        _isLoading = true;
      });

      // Load all COAs from the API if not cached
      if (financeProvider.chartOfAccounts.isEmpty) {
        _allCoas = await ChartOfAccountsService.getAllChartOfAccounts();
        financeProvider.setChartOfAccounts(_allCoas);
      } else {
        _allCoas = financeProvider.chartOfAccounts.cast<ChartOfAccount>();
      }

      // Load hierarchical main head accounts with subs from new API
      if (financeProvider.mainHeadAccountsWithSubs.isEmpty) {
        _mainHeadAccountsWithSubs =
            await ChartOfAccountsService.getAllMainHeadAccounts();
        financeProvider.setMainHeadAccountsWithSubs(_mainHeadAccountsWithSubs);
      } else {
        _mainHeadAccountsWithSubs = financeProvider.mainHeadAccountsWithSubs
            .cast<MainHeadOfAccountWithSubs>();
      }

      setState(() {
        _filteredCoas = _allCoas; // Initially show all COAs
        _applyPagination(); // Apply pagination to all COAs
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load chart of accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get all accounts from hierarchical data
  List<AccountOfSubHead> _getAllAccounts() {
    List<AccountOfSubHead> allAccounts = [];
    for (final mainHead in _mainHeadAccountsWithSubs) {
      for (final subHead in mainHead.subs) {
        allAccounts.addAll(subHead.accounts);
      }
    }
    return allAccounts;
  }

  // Get all subs from hierarchical data
  List<SubHeadOfAccountWithAccounts> _getAllSubs() {
    List<SubHeadOfAccountWithAccounts> allSubs = [];
    for (final mainHead in _mainHeadAccountsWithSubs) {
      allSubs.addAll(mainHead.subs);
    }
    return allSubs;
  }

  // Load sub head accounts when main head is selected
  Future<void> _loadSubHeadAccounts(int mainHeadId) async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    try {
      // Find the selected main head with subs from the hierarchical data
      final selectedMainHead = _mainHeadAccountsWithSubs.firstWhere(
        (mainHead) => mainHead.id == mainHeadId,
        orElse: () => throw Exception('Main head not found'),
      );

      // The subs are already loaded in the hierarchical data
      _subHeadAccountsWithAccounts = selectedMainHead.subs;

      setState(() {
        _filteredCoas = financeProvider.chartOfAccounts
            .where((coa) => coa.main.id == mainHeadId)
            .toList();
        _applyPagination();
        _selectedHierarchicalSubHead = null; // Reset sub head selection
        _selectedHead = null; // Reset head selection
      });
    } catch (e) {
      setState(() {
        _selectedHierarchicalSubHead = null;
        _selectedHead = null;
        _subHeadAccountsWithAccounts = [];
        _paginatedCoas = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sub head accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Apply pagination to COAs
  void _applyPagination() {
    if (_filteredCoas.isEmpty) {
      setState(() {
        _paginatedCoas = [];
      });
      return;
    }

    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= _filteredCoas.length) {
      setState(() {
        currentPage = 1;
      });
      _applyPagination();
      return;
    }

    setState(() {
      _paginatedCoas = _filteredCoas.sublist(
        startIndex,
        endIndex > _filteredCoas.length ? _filteredCoas.length : endIndex,
      );
    });
  }

  // Handle page changes
  void _changePage(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    _applyPagination();
  }

  // Create new sub head account
  Future<void> _createNewSubHead(String name) async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    if (_selectedHierarchicalMainHead == null) return;

    try {
      await ChartOfAccountsService.createCoaSub({
        'title': name,
        'coa_main_id': _selectedHierarchicalMainHead!.id,
        'status': 'active',
      });

      // Reload the hierarchical data to include the new sub head
      final reloadedData =
          await ChartOfAccountsService.getAllMainHeadAccounts();

      // Update provider cache
      financeProvider.setMainHeadAccountsWithSubs(reloadedData);

      // Find the currently selected main head in the reloaded data to maintain selection
      final currentMainHeadId = _selectedHierarchicalMainHead!.id;
      final updatedMainHead = reloadedData.firstWhere(
        (mainHead) => mainHead.id == currentMainHeadId,
        orElse: () => reloadedData.isNotEmpty
            ? reloadedData.first
            : _selectedHierarchicalMainHead!,
      );

      setState(() {
        _mainHeadAccountsWithSubs = reloadedData;
        _selectedHierarchicalMainHead = updatedMainHead;
      });

      _loadSubHeadAccounts(updatedMainHead.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sub head account created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create sub head account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Create new head account
  Future<void> _createNewHead(String name) async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    // Require a selected Sub Head to create a COA (Head / Account)
    if (_selectedHierarchicalSubHead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Sub Head before creating an account'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Reload hierarchical data to ensure we have the latest subs and mains
      _mainHeadAccountsWithSubs =
          await ChartOfAccountsService.getAllMainHeadAccounts();
      financeProvider.setMainHeadAccountsWithSubs(_mainHeadAccountsWithSubs);

      // Determine parent main head id for the selected sub (helps API validation)
      int? parentMainId;
      if (_selectedHierarchicalMainHead != null) {
        parentMainId = _selectedHierarchicalMainHead!.id;
      } else {
        for (final mh in _mainHeadAccountsWithSubs) {
          if (mh.subs.any((s) => s.id == _selectedHierarchicalSubHead!.id)) {
            parentMainId = mh.id;
            break;
          }
        }
      }

      // Ensure we have a parent main id for validation
      if (parentMainId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to determine main head for selected sub head. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Call the COAs creation API as requested
      final payload = {
        'title': name,
        'coa_sub_id': _selectedHierarchicalSubHead!.id,
        'coa_main_id': parentMainId,
        'status': 'Active',
      };

      final createdCoa = await ChartOfAccountsService.createChartOfAccount(
        payload,
      );

      // Reload hierarchical main-heads-with-subs and full COAs
      final reloadedData =
          await ChartOfAccountsService.getAllMainHeadAccounts();
      final allCoas = await ChartOfAccountsService.getAllChartOfAccounts();

      // Update provider cache
      financeProvider.setMainHeadAccountsWithSubs(reloadedData);
      financeProvider.setChartOfAccounts(allCoas);

      // Find the Main and Sub that contain the created account
      MainHeadOfAccountWithSubs? updatedMain;
      SubHeadOfAccountWithAccounts? updatedSub;
      AccountOfSubHead? createdAccountInstance;

      for (final mh in reloadedData) {
        for (final sub in mh.subs) {
          if (sub.id == createdCoa.sub.id) {
            updatedMain = mh;
            updatedSub = sub;
            // Try to find the exact created account instance inside the sub
            try {
              createdAccountInstance = sub.accounts.firstWhere(
                (acc) => acc.id == createdCoa.id,
              );
            } catch (_) {
              // If not present, create a lightweight AccountOfSubHead from createdCoa
              createdAccountInstance = AccountOfSubHead(
                id: createdCoa.id,
                code: createdCoa.code,
                title: createdCoa.title,
                type: createdCoa.type,
                status: createdCoa.status,
              );
              // Add it to the sub's accounts list so it appears in dropdowns
              sub.accounts.add(createdAccountInstance);
            }
            break;
          }
        }
        if (updatedMain != null) break;
      }

      setState(() {
        _mainHeadAccountsWithSubs = reloadedData;
        _allCoas = allCoas;
        // Set selections to the newly created context when available
        if (updatedMain != null) {
          _selectedHierarchicalMainHead = updatedMain;
          _subHeadAccountsWithAccounts = updatedMain.subs;
        }
        if (updatedSub != null) {
          _selectedHierarchicalSubHead = updatedSub;
        }
        if (createdAccountInstance != null) {
          _selectedHead = createdAccountInstance;
          // Filter to the newly created account
          _filteredCoas = _allCoas
              .where((coa) => coa.id == createdAccountInstance!.id)
              .toList();
        } else {
          // Fallback: filter by sub if account not found
          _filteredCoas = _allCoas
              .where(
                (coa) =>
                    coa.sub.id ==
                    (updatedSub?.id ?? _selectedHierarchicalSubHead?.id),
              )
              .toList();
        }
        _applyPagination();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show create new item dialog
  Future<void> _showCreateNewDialog(
    String type,
    Function(String) onCreate,
  ) async {
    final TextEditingController controller = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New $type'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '$type Name',
              hintText: 'Enter $type name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                onCreate(controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Show create Head (COA) dialog which includes Sub Head selection and title
  Future<void> _showCreateHeadDialog() async {
    final TextEditingController titleController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    // Prepare sub options (either filtered by selected main or all subs)
    final List<SubHeadOfAccountWithAccounts> subOptions =
        _selectedHierarchicalMainHead != null
        ? _subHeadAccountsWithAccounts
        : _getAllSubs();

    SubHeadOfAccountWithAccounts? localSelectedSub =
        _selectedHierarchicalSubHead ??
        (subOptions.isNotEmpty ? subOptions.first : null);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Create New Head Account'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sub Head selector
                DropdownButtonFormField<SubHeadOfAccountWithAccounts>(
                  value: localSelectedSub,
                  decoration: InputDecoration(
                    labelText: 'Sub Head',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: subOptions.map((s) {
                    return DropdownMenuItem<SubHeadOfAccountWithAccounts>(
                      value: s,
                      child: Text('${s.code} - ${s.title}'),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => localSelectedSub = v),
                  validator: (v) =>
                      v == null ? 'Please select a sub head' : null,
                ),
                const SizedBox(height: 12),
                // Title field
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Account Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter a title'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;

                if (localSelectedSub == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a Sub Head'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final name = titleController.text.trim();

                // Temporarily set the selected sub in state so _createNewHead can use it
                setState(() {
                  _selectedHierarchicalSubHead = localSelectedSub;
                });

                // Call create logic (this will reload lists and select created account)
                await _createNewHead(name);

                Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalPages() {
    if (_filteredCoas.isEmpty) return 1;
    return (_filteredCoas.length / itemsPerPage).ceil();
  }

  bool _canGoToNextPage() {
    return currentPage < _getTotalPages();
  }

  List<Widget> _buildFilterRow() {
    List<Widget> widgets = [];

    // Prepare option lists and selected values by id to avoid identity mismatches
    final List<AccountOfSubHead> _headOptions =
        _selectedHierarchicalSubHead != null
        ? _selectedHierarchicalSubHead!.accounts
        : _getAllAccounts();
    AccountOfSubHead? _selectedHeadValue;
    if (_selectedHead != null) {
      try {
        _selectedHeadValue = _headOptions.firstWhere(
          (a) => a.id == _selectedHead!.id,
        );
      } catch (_) {
        _selectedHeadValue = null;
      }
    }

    final List<SubHeadOfAccountWithAccounts> _subOptions =
        _selectedHierarchicalMainHead != null
        ? _subHeadAccountsWithAccounts
        : _getAllSubs();
    SubHeadOfAccountWithAccounts? _selectedSubValue;
    if (_selectedHierarchicalSubHead != null) {
      try {
        _selectedSubValue = _subOptions.firstWhere(
          (s) => s.id == _selectedHierarchicalSubHead!.id,
        );
      } catch (_) {
        _selectedSubValue = null;
      }
    }

    final List<MainHeadOfAccountWithSubs> _mainOptions =
        _mainHeadAccountsWithSubs;
    MainHeadOfAccountWithSubs? _selectedMainValue;
    if (_selectedHierarchicalMainHead != null) {
      try {
        _selectedMainValue = _mainOptions.firstWhere(
          (m) => m.id == _selectedHierarchicalMainHead!.id,
        );
      } catch (_) {
        _selectedMainValue = null;
      }
    }

    // Head of Account Filter - Moved to first position
    widgets.add(
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.business, size: 14, color: Color(0xFF0D1845)),
                  SizedBox(width: 4),
                  Text(
                    'Head of Account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF343A40),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<AccountOfSubHead>(
                value: _selectedHeadValue,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Select head account',
                  hintStyle: TextStyle(color: Color(0xFFADB5BD), fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF0D1845), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add, color: Color(0xFF0D1845), size: 18),
                    onPressed: _showCreateHeadDialog,
                    tooltip: 'Create New Head Account',
                  ),
                ),
                items: _headOptions.map((account) {
                  return DropdownMenuItem<AccountOfSubHead>(
                    value: account,
                    child: Row(
                      children: [
                        Icon(
                          Icons.business,
                          color: Color(0xFF0D1845),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${account.code} - ${account.title}',
                          style: TextStyle(
                            color: Color(0xFF343A40),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedHead = value;
                    if (value != null) {
                      // Find the Sub and Main for this Head
                      for (final mainHead in _mainHeadAccountsWithSubs) {
                        for (final subHead in mainHead.subs) {
                          if (subHead.accounts.any(
                            (acc) => acc.id == value.id,
                          )) {
                            _selectedHierarchicalSubHead = subHead;
                            _selectedHierarchicalMainHead = mainHead;
                            _subHeadAccountsWithAccounts = mainHead.subs;
                            break;
                          }
                        }
                        if (_selectedHierarchicalMainHead != null) break;
                      }
                      // Filter COAs to this Head
                      _filteredCoas = _allCoas
                          .where((coa) => coa.id == value.id)
                          .toList();
                      _applyPagination();
                    } else {
                      _filteredCoas = _allCoas;
                      _applyPagination();
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );

    // Sub Head of Account Filter - Always visible
    widgets.add(const SizedBox(width: 12));
    widgets.add(
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.account_tree, size: 14, color: Color(0xFF0D1845)),
                  SizedBox(width: 4),
                  Text(
                    'Sub Head of Account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF343A40),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<SubHeadOfAccountWithAccounts>(
                value: _selectedSubValue,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Select sub head account',
                  hintStyle: TextStyle(color: Color(0xFFADB5BD), fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF0D1845), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add, color: Color(0xFF0D1845), size: 18),
                    onPressed: () => _showCreateNewDialog(
                      'Sub Head Account',
                      _createNewSubHead,
                    ),
                    tooltip: 'Create New Sub Head Account',
                  ),
                ),
                items: _subOptions.map((subHead) {
                  return DropdownMenuItem<SubHeadOfAccountWithAccounts>(
                    value: subHead,
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_tree,
                          color: Color(0xFF0D1845),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${subHead.code} - ${subHead.title}',
                          style: TextStyle(
                            color: Color(0xFF343A40),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedHierarchicalSubHead = value;
                    if (value != null) {
                      // If a Head is selected and it doesn't belong to this Sub, reset Head
                      if (_selectedHead != null &&
                          !value.accounts.any(
                            (acc) => acc.id == _selectedHead!.id,
                          )) {
                        _selectedHead = null;
                      }
                      // Filter COAs to those in this Sub
                      _filteredCoas = _allCoas
                          .where((coa) => coa.sub.id == value.id)
                          .toList();
                      _applyPagination();
                    } else {
                      // If no Sub selected, show all or based on Head
                      if (_selectedHead != null) {
                        _filteredCoas = _allCoas
                            .where((coa) => coa.id == _selectedHead!.id)
                            .toList();
                      } else {
                        _filteredCoas = _allCoas;
                      }
                      _applyPagination();
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );

    // Main Head of Account Filter - Moved to last position
    widgets.add(const SizedBox(width: 12));
    widgets.add(
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 14,
                    color: Color(0xFF0D1845),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Main Head of Account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF343A40),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<MainHeadOfAccountWithSubs>(
                value: _selectedMainValue,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Select main head account',
                  hintStyle: TextStyle(color: Color(0xFFADB5BD), fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF0D1845), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _mainHeadAccountsWithSubs.map((mainHead) {
                  return DropdownMenuItem<MainHeadOfAccountWithSubs>(
                    value: mainHead,
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: Color(0xFF0D1845),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${mainHead.code} - ${mainHead.title}',
                          style: TextStyle(
                            color: Color(0xFF343A40),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedHierarchicalMainHead = value;
                    if (value != null) {
                      _subHeadAccountsWithAccounts = value.subs;
                      // If a Sub is selected and it doesn't belong to this Main, reset Sub and Head
                      if (_selectedHierarchicalSubHead != null &&
                          !value.subs.any(
                            (sub) => sub.id == _selectedHierarchicalSubHead!.id,
                          )) {
                        _selectedHierarchicalSubHead = null;
                        _selectedHead = null;
                      }
                      // Filter COAs to those in this Main
                      _filteredCoas = _allCoas
                          .where((coa) => coa.main.id == value.id)
                          .toList();
                      _applyPagination();
                    } else {
                      // If no Main selected, show all or based on Sub/Head
                      if (_selectedHierarchicalSubHead != null) {
                        _filteredCoas = _allCoas
                            .where(
                              (coa) =>
                                  coa.sub.id ==
                                  _selectedHierarchicalSubHead!.id,
                            )
                            .toList();
                      } else if (_selectedHead != null) {
                        _filteredCoas = _allCoas
                            .where((coa) => coa.id == _selectedHead!.id)
                            .toList();
                      } else {
                        _filteredCoas = _allCoas;
                      }
                      _applyPagination();
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );

    return widgets;
  }

  List<Widget> _buildPageButtons() {
    final totalPages = _getTotalPages();
    final current = currentPage;

    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2;

    int startPage = (current - halfRange).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);

    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = (endPage - maxButtons + 1).clamp(1, totalPages);
    }

    List<Widget> buttons = [];

    for (int i = startPage; i <= endPage; i++) {
      buttons.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current
                  ? const Color(0xFF17A2B8)
                  : Colors.white,
              foregroundColor: i == current
                  ? Colors.white
                  : const Color(0xFF6C757D),
              elevation: i == current ? 2 : 0,
              side: i == current
                  ? null
                  : const BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(28, 28),
            ),
            child: Text(
              i.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  // Export selected COAs to PDF
  Future<void> _exportToPDF() async {
    if (_selectedCoaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one account to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Filter selected COAs
      final selectedCoas = _filteredCoas
          .where((coa) => _selectedCoaIds.contains(coa.id))
          .toList();

      // Create PDF document
      final PdfDocument document = PdfDocument();
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.size = PdfPageSize.a4;

      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      );
      final PdfFont headerFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        10,
        style: PdfFontStyle.bold,
      );
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      // Draw title
      graphics.drawString(
        'Chart of Accounts Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      // Draw generation info
      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      filterInfo += ' | Selected: ${selectedCoas.length} accounts';

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 6);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.08; // ID
      grid.columns[1].width = tableWidth * 0.25; // Title
      grid.columns[2].width = tableWidth * 0.20; // Sub Head
      grid.columns[3].width = tableWidth * 0.15; // Sub ID
      grid.columns[4].width = tableWidth * 0.20; // Main Head
      grid.columns[5].width = tableWidth * 0.12; // Main ID

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'ID';
      headerRow.cells[1].value = 'Title';
      headerRow.cells[2].value = 'Sub Head of Account';
      headerRow.cells[3].value = 'Sub Head ID';
      headerRow.cells[4].value = 'Main Head of Account';
      headerRow.cells[5].value = 'Main Head ID';

      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);
      for (int i = 0; i < headerRow.cells.count; i++) {
        headerRow.cells[i].style = PdfGridCellStyle(
          backgroundBrush: PdfSolidBrush(tableHeaderColor),
          textBrush: PdfSolidBrush(PdfColor(73, 80, 87)),
          font: headerFont,
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }

      // Add data rows
      for (final coa in selectedCoas) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = coa.id.toString();
        row.cells[1].value = coa.title;
        row.cells[2].value = 'sub: ${coa.sub.title}';
        row.cells[3].value = 'sub${coa.sub.id}';
        row.cells[4].value = 'main: ${coa.main.title}';
        row.cells[5].value = 'main${coa.main.id}';

        // Center align cells except title
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            format: PdfStringFormat(
              alignment: i == 1 || i == 2 || i == 4
                  ? PdfTextAlignment.left
                  : PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
        }
      }

      // Draw grid
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          60,
          page.getClientSize().width,
          page.getClientSize().height - 100,
        ),
      );

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Get directory and save file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/chart_of_accounts_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported successfully to:\n$path'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart of Account'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: Column(
          children: [
            // Header with Summary Cards
            Consumer<FinanceProvider>(
              builder: (context, financeProvider, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0D1845).withOpacity(0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.account_tree,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chart of Account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage and organize your account hierarchy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateCoaPage(),
                                ),
                              );
                              if (result == true) {
                                // Ensure provider caches are cleared and reload fresh data
                                final financeProvider =
                                    Provider.of<FinanceProvider>(
                                      context,
                                      listen: false,
                                    );
                                financeProvider.clearChartOfAccounts();
                                financeProvider.clearMainHeadAccountsWithSubs();
                                financeProvider
                                    .clearSubHeadAccountsWithAccounts();

                                await _loadMainHeadAccounts();
                              }
                            },
                            icon: const Icon(Icons.add, size: 12),
                            label: const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D1845),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _exportToPDF,
                            icon: const Icon(Icons.picture_as_pdf, size: 12),
                            label: Text(
                              'Export PDF${_selectedCoaIds.isNotEmpty ? ' (${_selectedCoaIds.length})' : ''}',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D1845),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Summary Cards
                      Row(
                        children: [
                          _buildSummaryCard(
                            'Total Accounts',
                            '${_allCoas.length}',
                            Icons.account_balance_wallet,
                            Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          _buildSummaryCard(
                            'Main Heads',
                            '${_mainHeadAccountsWithSubs.length}',
                            Icons.account_tree,
                            Colors.green,
                          ),
                          const SizedBox(width: 6),
                          _buildSummaryCard(
                            'Sub Heads',
                            '${_subHeadAccountsWithAccounts.length}',
                            Icons.account_balance,
                            Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          _buildSummaryCard(
                            'Selected',
                            '${_selectedCoaIds.length}',
                            Icons.check_circle,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Search and Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Filters Section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Row(children: _buildFilterRow())],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 45,
                            child: Checkbox(
                              value: _selectAll,
                              onChanged: (value) {
                                setState(() {
                                  _selectAll = value ?? false;
                                  if (_selectAll) {
                                    _selectedCoaIds = _filteredCoas
                                        .map((coa) => coa.id)
                                        .toSet();
                                  } else {
                                    _selectedCoaIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Text('Account ID', style: _headerStyle()),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Head of Account',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Head of Account ID',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Sub Head of Account',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Sub Head of Account ID',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Main Head of Account',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Main Head of Account ID',
                              style: _headerStyle(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _paginatedCoas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No accounts found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _paginatedCoas.length,
                              itemBuilder: (context, index) {
                                final coa = _paginatedCoas[index];

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 45,
                                        child: Checkbox(
                                          value: _selectedCoaIds.contains(
                                            coa.id,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedCoaIds.add(coa.id);
                                              } else {
                                                _selectedCoaIds.remove(coa.id);
                                                _selectAll = false;
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          coa.id.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0D1845),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${coa.code} - ${coa.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          coa.id.toString(),
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${coa.sub.code} - ${coa.sub.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          coa.sub.id.toString(),
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'main: ${coa.main.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'main${coa.main.id}',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Pagination Controls
                    ...(_filteredCoas.isNotEmpty
                        ? [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Previous button
                                  ElevatedButton.icon(
                                    onPressed: currentPage > 1
                                        ? () => _changePage(currentPage - 1)
                                        : null,
                                    icon: Icon(Icons.chevron_left, size: 14),
                                    label: Text(
                                      'Previous',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: currentPage > 1
                                          ? const Color(0xFF0D1845)
                                          : const Color(0xFF6C757D),
                                      elevation: 0,
                                      side: const BorderSide(
                                        color: Color(0xFFDEE2E6),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Page numbers
                                  ..._buildPageButtons(),

                                  const SizedBox(width: 8),

                                  // Next button
                                  ElevatedButton.icon(
                                    onPressed: _canGoToNextPage()
                                        ? () => _changePage(currentPage + 1)
                                        : null,
                                    icon: Icon(Icons.chevron_right, size: 14),
                                    label: Text(
                                      'Next',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _canGoToNextPage()
                                          ? const Color(0xFF0D1845)
                                          : Colors.grey.shade300,
                                      foregroundColor: _canGoToNextPage()
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      elevation: _canGoToNextPage() ? 2 : 0,
                                      side: _canGoToNextPage()
                                          ? null
                                          : const BorderSide(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),

                                  // Page info
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Page $currentPage of ${_getTotalPages()} (${_filteredCoas.length} total)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6C757D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : []),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontWeight: FontWeight.w600,
      color: Color(0xFF343A40),
      fontSize: 13,
    );
  }
}
