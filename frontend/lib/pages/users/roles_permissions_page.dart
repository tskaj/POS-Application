import 'package:flutter/material.dart';
import 'models.dart';

class RolesPermissionsPage extends StatefulWidget {
  const RolesPermissionsPage({super.key});

  @override
  State<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends State<RolesPermissionsPage> {
  late List<User> _users = [];
  late Map<int, UserPermissions> _userPermissions = {};
  late bool _isLoading = false;
  late String _errorMessage = '';
  late bool _showPermissionsDialog = false;
  late User? _selectedUser = null;
  late bool _isUpdatingPermissions = false;

  // System sections
  final List<String> _systemSections = [
    'Inventory',
    'Sales',
    'Purchase',
    'Reports',
    'Finance & Accounts',
    'General Settings',
    'Users',
  ];

  // Pagination variables
  int currentPage = 1;
  final int itemsPerPage = 10;
  List<User> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsersAndPermissions();
  }

  void _loadUsersAndPermissions() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Dummy data for now
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _users = [
          User(
            id: 1,
            username: 'admin',
            email: 'admin@pos.com',
            password: '********',
            picture: 'https://via.placeholder.com/50',
            isActive: true,
          ),
          User(
            id: 2,
            username: 'manager',
            email: 'manager@pos.com',
            password: '********',
            picture: 'https://via.placeholder.com/50',
            isActive: true,
          ),
          User(
            id: 3,
            username: 'cashier',
            email: 'cashier@pos.com',
            password: '********',
            picture: 'https://via.placeholder.com/50',
            isActive: false,
          ),
          User(
            id: 4,
            username: 'sales_rep',
            email: 'sales@pos.com',
            password: '********',
            picture: 'https://via.placeholder.com/50',
            isActive: true,
          ),
        ];

        // Initialize permissions for each user
        _userPermissions = {};
        for (final user in _users) {
          _userPermissions[user.id] = UserPermissions(
            userId: user.id,
            permissions: {
              // Admin has all permissions
              if (user.username == 'admin') ...{
                for (final section in _systemSections) section: true,
              }
              // Manager has most permissions except Users
              else if (user.username == 'manager') ...{
                'Inventory': true,
                'Sales': true,
                'Purchase': true,
                'Reports': true,
                'Finance & Accounts': true,
                'General Settings': false,
                'Users': false,
              }
              // Cashier has limited permissions
              else if (user.username == 'cashier') ...{
                'Inventory': false,
                'Sales': true,
                'Purchase': false,
                'Reports': false,
                'Finance & Accounts': false,
                'General Settings': false,
                'Users': false,
              }
              // Sales rep has sales and reports
              else ...{
                'Inventory': false,
                'Sales': true,
                'Purchase': false,
                'Reports': true,
                'Finance & Accounts': false,
                'General Settings': false,
                'Users': false,
              },
            },
          );
        }

        _isLoading = false;
        _applyPagination();
      });
    });
  }

  void _applyPagination() {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    setState(() {
      _filteredUsers = _users.sublist(
        startIndex,
        endIndex > _users.length ? _users.length : endIndex,
      );
    });
  }

  void _changePage(int page) {
    if (page < 1 || page > _getTotalPages()) return;
    setState(() {
      currentPage = page;
    });
    _applyPagination();
  }

  int _getTotalPages() {
    return (_users.length / itemsPerPage).ceil();
  }

  bool _canGoToNextPage() {
    return currentPage < _getTotalPages();
  }

  // Selection methods
  void _openPermissionsDialog(User user) {
    setState(() {
      _showPermissionsDialog = true;
      _selectedUser = user;
    });
  }

  void _closePermissionsDialog() {
    setState(() {
      _showPermissionsDialog = false;
      _selectedUser = null;
    });
  }

  void _updatePermission(String section, bool value) {
    if (_selectedUser == null) return;

    setState(() {
      _userPermissions[_selectedUser!.id]!.permissions[section] = value;
    });
  }

  void _savePermissions() async {
    if (_selectedUser == null) return;

    setState(() {
      _isUpdatingPermissions = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isUpdatingPermissions = false;
      _showPermissionsDialog = false;
      _selectedUser = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permissions updated successfully')),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
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
        title: const Text('Roles & Permissions'),
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
        child: Stack(
          children: [
            Column(
              children: [
                // Header with margin
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0D1845).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Roles & Permissions',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage user access and permissions for system modules',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Summary Cards
                      Row(
                        children: [
                          _buildSummaryCard(
                            'Total Users',
                            '${_users.length}',
                            Icons.people_outline,
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'Active Users',
                            '${_users.where((u) => u.isActive).length}',
                            Icons.verified_user,
                            Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'Modules',
                            '${_systemSections.length}',
                            Icons.apps,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Error message display
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = '';
                            });
                          },
                          icon: Icon(Icons.close, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Table Section
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'User Name',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Email',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Roles and Permissions',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Table Body
                              Expanded(
                                child: _filteredUsers.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.admin_panel_settings,
                                              size: 64,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No users found',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _filteredUsers.length,
                                        itemBuilder: (context, index) {
                                          final user = _filteredUsers[index];
                                          final permissions =
                                              _userPermissions[user.id];
                                          final grantedSections =
                                              permissions?.permissions.entries
                                                  .where((entry) => entry.value)
                                                  .map((entry) => entry.key)
                                                  .toList() ??
                                              [];

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey[200]!,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    user.username,
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    user.email,
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blue
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '${grantedSections.length}/${_systemSections.length} modules',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .blue[800],
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.edit,
                                                          color: Colors.blue,
                                                          size: 18,
                                                        ),
                                                        onPressed: () =>
                                                            _openPermissionsDialog(
                                                              user,
                                                            ),
                                                        tooltip:
                                                            'Edit Permissions',
                                                        padding:
                                                            const EdgeInsets.all(
                                                              6,
                                                            ),
                                                        constraints:
                                                            const BoxConstraints(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              // Pagination Controls
                              if (_users.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
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
                                        icon: const Icon(
                                          Icons.chevron_left,
                                          size: 14,
                                        ),
                                        label: Text(
                                          'Previous',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: currentPage > 1
                                              ? const Color(0xFF17A2B8)
                                              : const Color(0xFF6C757D),
                                          elevation: 0,
                                          side: BorderSide(
                                            color: const Color(0xFFDEE2E6),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
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
                                        icon: const Icon(
                                          Icons.chevron_right,
                                          size: 14,
                                        ),
                                        label: Text(
                                          'Next',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _canGoToNextPage()
                                              ? const Color(0xFF17A2B8)
                                              : Colors.grey.shade300,
                                          foregroundColor: _canGoToNextPage()
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                          elevation: _canGoToNextPage() ? 2 : 0,
                                          side: _canGoToNextPage()
                                              ? null
                                              : BorderSide(
                                                  color: const Color(
                                                    0xFFDEE2E6,
                                                  ),
                                                ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                        ),
                                      ),

                                      // Page info
                                      const SizedBox(width: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Page $currentPage of ${_getTotalPages()} (${_users.length} total)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6C757D),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),

            // Permissions Dialog
            ...(_showPermissionsDialog ? [_buildPermissionsDialog()] : []),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPageButtons() {
    final totalPages = _getTotalPages();
    final current = currentPage;

    // Show max 5 page buttons centered around current page
    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2;

    // Calculate desired start and end
    int startPage = (current - halfRange).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);

    // If endPage exceeds totalPages, adjust startPage
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
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(32, 32),
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

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Color(0xFF343A40),
    );
  }

  TextStyle _cellStyle() {
    return const TextStyle(fontSize: 13, color: Color(0xFF6C757D));
  }

  Widget _buildPermissionsDialog() {
    if (_selectedUser == null) return const SizedBox.shrink();

    final permissions = _userPermissions[_selectedUser!.id];

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.7,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1845),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Permissions for ${_selectedUser!.username}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _closePermissionsDialog,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Dialog Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage(
                                _selectedUser!.picture,
                              ),
                              onBackgroundImageError: (_, __) =>
                                  const Icon(Icons.person),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedUser!.username,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D1845),
                                    ),
                                  ),
                                  Text(
                                    _selectedUser!.email,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6C757D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // System Sections
                      const Text(
                        'System Access Permissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _systemSections.map((section) {
                            final isGranted =
                                permissions?.permissions[section] ?? false;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: section == _systemSections.last
                                        ? 0
                                        : 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: _getSectionColor(
                                              section,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            _getSectionIcon(section),
                                            color: _getSectionColor(section),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          section,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF343A40),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isGranted,
                                    onChanged: (value) {
                                      _updatePermission(
                                        section,
                                        value ?? false,
                                      );
                                    },
                                    activeColor: const Color(0xFF0D1845),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              // Select all
                              for (final section in _systemSections) {
                                _updatePermission(section, true);
                              }
                            },
                            icon: const Icon(Icons.select_all),
                            label: const Text('Select All'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () {
                              // Deselect all
                              for (final section in _systemSections) {
                                _updatePermission(section, false);
                              }
                            },
                            icon: const Icon(Icons.deselect),
                            label: const Text('Deselect All'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isUpdatingPermissions
                                  ? null
                                  : _savePermissions,
                              icon: _isUpdatingPermissions
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isUpdatingPermissions
                                    ? 'Updating...'
                                    : 'Save Permissions',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D1845),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: _closePermissionsDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            child: const Text('Cancel'),
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
    );
  }

  Color _getSectionColor(String section) {
    switch (section) {
      case 'Inventory':
        return Colors.blue;
      case 'Sales':
        return Colors.green;
      case 'Purchase':
        return Colors.orange;
      case 'Reports':
        return Colors.purple;
      case 'Finance & Accounts':
        return Colors.teal;
      case 'General Settings':
        return Colors.grey;
      case 'Users':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'Inventory':
        return Icons.inventory;
      case 'Sales':
        return Icons.point_of_sale;
      case 'Purchase':
        return Icons.shopping_cart;
      case 'Reports':
        return Icons.bar_chart;
      case 'Finance & Accounts':
        return Icons.account_balance;
      case 'General Settings':
        return Icons.settings;
      case 'Users':
        return Icons.people;
      default:
        return Icons.apps;
    }
  }
}
