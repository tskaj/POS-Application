import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'dart:io';
import '../models/product.dart';
import '../models/vendor.dart' as vendor;
import '../models/category.dart' as category;
import '../models/sub_category.dart' as subCategory;
import '../models/color.dart' as colorModel;
import '../models/size.dart' as sizeModel;
import '../models/season.dart' as seasonModel;
import '../models/material.dart' as materialModel;
import '../services/inventory_service.dart';
import '../services/sales_service.dart';
import '../services/purchases_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  UserProfile? _userProfile;
  bool _isLoading = false;
  int _imageVersion = 0;

  User? get user => _user;
  String? get token => _token;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _user != null;
  int get imageVersion => _imageVersion;

  // Constructor - initialize auth state
  AuthProvider() {
    initAuth();
  }

  void incrementImageVersion() {
    _imageVersion++;
    notifyListeners();
  }

  // Initialize auth state
  Future<void> initAuth() async {
    _token = await ApiService.getToken();
    if (_token != null) {
      // TODO: You might want to validate token or fetch user profile here
      // For now, we'll just check if token exists
      notifyListeners();
    }
  }

  // Login method
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    print('🚀 AuthProvider: Starting login process for $email');

    try {
      final response = await ApiService.login(email, password);
      _token = response['token'];
      _user = User.fromJson(response['user']);

      print('✅ AuthProvider: Login successful for user: ${_user?.fullName}');

      // Load user profile after login
      await getUserProfile();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ AuthProvider: Login failed with error: $e');

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    _token = null;
    _userProfile = null;
    notifyListeners();
  }

  // Get user profile
  Future<bool> getUserProfile() async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      print('👤 AuthProvider: Fetching user profile');
      final profileData = await ApiService.getProfile(_user!.id);

      if (profileData.isNotEmpty) {
        // The response has 'data' with user and profile
        final actualData = profileData['data'];
        if (actualData != null) {
          // Update user if needed - only if the data contains user fields
          if (actualData['role'] != null && actualData['email'] != null) {
            // Update user role if changed
            _user = User.fromJson(actualData);
          }
          final actualProfileData = actualData['profile'];
          if (actualProfileData != null) {
            _userProfile = UserProfile.fromJson(
              actualProfileData,
              currentUser: _user,
            );
            print(
              '✅ AuthProvider: Profile loaded for user: ${_userProfile?.user.fullName}',
            );
            // Check for local profile picture if not set
            if (_userProfile!.profilePicture == null) {
              String localPath =
                  '${Directory.current.path}/assets/images/profiles/profile_${_user!.id}.jpg';
              if (File(localPath).existsSync()) {
                _userProfile!.profilePicture =
                    'assets/images/profiles/profile_${_user!.id}.jpg';
                _imageVersion++;
              }
            }
          } else {
            print('⚠️ AuthProvider: Profile data is null');
            _userProfile = null;
          }
        } else {
          print('⚠️ AuthProvider: Data is null');
          _userProfile = null;
        }
      } else {
        print('⚠️ AuthProvider: No profile data found');
        _userProfile = null;
      }

      _isLoading = false;
      notifyListeners();
      return _userProfile != null;
    } catch (e) {
      print('❌ AuthProvider: Failed to load profile: $e');
      _userProfile = null; // Set to null on error
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Create user profile
  Future<bool> createUserProfile(Map<String, dynamic> profileData) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      print('📝 AuthProvider: Creating user profile');
      final response = await ApiService.createProfile(profileData);

      // Check if the response has a 'data' key or is the profile data directly
      final actualProfileData = response.containsKey('data')
          ? response['data']
          : response;

      if (actualProfileData != null) {
        _userProfile = UserProfile.fromJson(
          actualProfileData,
          currentUser: _user,
        );
        // Check for local profile picture if not set
        if (_userProfile!.profilePicture == null) {
          String localPath =
              '${Directory.current.path}/assets/images/profiles/profile_${_user!.id}.jpg';
          if (File(localPath).existsSync()) {
            _userProfile!.profilePicture =
                'assets/images/profiles/profile_${_user!.id}.jpg';
            _imageVersion++;
          }
        }
        print('✅ AuthProvider: Profile created successfully');
      } else {
        print('⚠️ AuthProvider: Profile creation response invalid');
        _userProfile = null;
      }
      _isLoading = false;
      notifyListeners();
      return _userProfile != null;
    } catch (e) {
      print('❌ AuthProvider: Failed to create profile: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      print('📝 AuthProvider: Updating user profile');
      final oldProfilePicture = _userProfile?.profilePicture;
      final response = await ApiService.updateProfile(_user!.id, profileData);

      // Update local profile data
      final actualProfileData = response.containsKey('data')
          ? response['data']
          : response;
      if (actualProfileData != null) {
        _userProfile = UserProfile.fromJson(
          actualProfileData,
          currentUser: _user,
        );
        // Retain local profile picture if backend returns HTTP URL
        if (_userProfile!.profilePicture == null && oldProfilePicture != null) {
          _userProfile!.profilePicture = oldProfilePicture;
        }
        _imageVersion++;
      }

      print('✅ AuthProvider: Profile updated successfully');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // If profile doesn't exist (404), try to create it
      if (e.toString().contains('404') ||
          e.toString().contains('No query results')) {
        print(
          '⚠️ AuthProvider: Profile not found, attempting to create new profile',
        );
        try {
          final createResponse = await ApiService.createProfile(profileData);
          final actualCreateData = createResponse.containsKey('data')
              ? createResponse['data']
              : createResponse;
          if (actualCreateData != null) {
            _userProfile = UserProfile.fromJson(
              actualCreateData,
              currentUser: _user,
            );
            print('✅ AuthProvider: Profile created successfully');
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            print('⚠️ AuthProvider: Profile creation response invalid');
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (createError) {
          print('❌ AuthProvider: Failed to create profile: $createError');
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        print('❌ AuthProvider: Failed to update profile: $e');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }
  }

  // Upload profile picture
  Future<bool> uploadProfilePicture(String imagePath) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      print('🖼️ AuthProvider: Uploading profile picture');
      final response = await ApiService.uploadProfilePicture(
        _user!.id,
        imagePath,
      );

      // Update local profile data if needed
      if (_userProfile != null && response.containsKey('data')) {
        _userProfile = UserProfile.fromJson(response['data']);
      }

      print('✅ AuthProvider: Profile picture uploaded successfully');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ AuthProvider: Failed to upload profile picture: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete user account
  Future<bool> deleteUser() async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      print('🗑️ AuthProvider: Deleting user account');
      await ApiService.deleteUser(_user!.id);

      // Clear all user data
      _user = null;
      _token = null;
      _userProfile = null;

      print('✅ AuthProvider: User account deleted successfully');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ AuthProvider: Failed to delete user account: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get auth headers for API calls
  Map<String, String> getAuthHeaders() {
    if (_token == null) return {};
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
}

class InventoryProvider with ChangeNotifier {
  // Data lists
  List<category.Category> _categories = [];
  List<subCategory.SubCategory> _subCategories = [];
  List<Product> _products = [];
  List<Product> _lowStockProducts = [];
  List<vendor.Vendor> _vendors = [];
  List<colorModel.Color> _colors = [];
  List<sizeModel.Size> _sizes = [];
  List<seasonModel.Season> _seasons = [];
  List<materialModel.Material> _materials = [];

  // Loading states
  bool _isLoadingCategories = false;
  bool _isLoadingSubCategories = false;
  bool _isLoadingProducts = false;
  bool _isLoadingLowStockProducts = false;
  bool _isLoadingVendors = false;
  bool _isLoadingColors = false;
  bool _isLoadingSizes = false;
  bool _isLoadingSeasons = false;
  bool _isLoadingMaterials = false;
  bool _isPreFetching = false;

  // Getters
  List<category.Category> get categories => _categories;
  List<subCategory.SubCategory> get subCategories => _subCategories;
  List<Product> get products => _products;
  List<Product> get lowStockProducts => _lowStockProducts;
  List<vendor.Vendor> get vendors => _vendors;
  List<colorModel.Color> get colors => _colors;
  List<sizeModel.Size> get sizes => _sizes;
  List<seasonModel.Season> get seasons => _seasons;
  List<materialModel.Material> get materials => _materials;

  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingSubCategories => _isLoadingSubCategories;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingLowStockProducts => _isLoadingLowStockProducts;
  bool get isLoadingVendors => _isLoadingVendors;
  bool get isLoadingColors => _isLoadingColors;
  bool get isLoadingSizes => _isLoadingSizes;
  bool get isLoadingSeasons => _isLoadingSeasons;
  bool get isLoadingMaterials => _isLoadingMaterials;
  bool get isPreFetching => _isPreFetching;

  // Pre-fetch all data
  Future<void> preFetchAllData() async {
    _isPreFetching = true;
    notifyListeners();

    try {
      print('🚀 InventoryProvider: Starting pre-fetch of all data');

      // Fetch all data in parallel
      final futures = <Future>[];
      futures.add(_fetchCategories());
      futures.add(_fetchSubCategories());
      futures.add(_fetchProducts());
      futures.add(_fetchVendors());
      futures.add(_fetchColors());
      futures.add(_fetchSizes());
      futures.add(_fetchSeasons());
      futures.add(_fetchMaterials());

      await Future.wait(futures);

      print('✅ InventoryProvider: Pre-fetch completed successfully');
    } catch (e) {
      print('❌ InventoryProvider: Pre-fetch failed: $e');
      // Don't throw, just log - app should still work
    } finally {
      _isPreFetching = false;
      notifyListeners();
    }
  }

  // Individual fetch methods
  Future<void> _fetchCategories() async {
    _isLoadingCategories = true;
    notifyListeners();

    try {
      final response = await InventoryService.getCategories(
        limit: 1000,
      ); // Fetch all
      _categories = response.data;
      print('📂 InventoryProvider: Fetched ${_categories.length} categories');
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch categories: $e');
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSubCategories() async {
    _isLoadingSubCategories = true;
    notifyListeners();

    try {
      final response = await InventoryService.getSubCategories(limit: 1000);
      _subCategories = response.data;
      print(
        '📂 InventoryProvider: Fetched ${_subCategories.length} subcategories',
      );
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch subcategories: $e');
    } finally {
      _isLoadingSubCategories = false;
      notifyListeners();
    }
  }

  Future<void> _fetchProducts() async {
    _isLoadingProducts = true;
    notifyListeners();

    try {
      final response = await InventoryService.getProducts(limit: 1000);
      _products = response.data;
      print('📦 InventoryProvider: Fetched ${_products.length} products');
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch products: $e');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> _fetchLowStockProducts() async {
    _isLoadingLowStockProducts = true;
    notifyListeners();

    try {
      // Fetch all low stock products (without pagination for caching)
      List<Product> allLowStockProducts = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final response = await InventoryService.getLowStockProducts(
          page: currentPage,
          limit: 100, // Fetch in chunks
        );

        final products = (response['data'] as List)
            .map((item) => Product.fromJson(item))
            .toList();

        allLowStockProducts.addAll(products);

        // Check if there are more pages
        final totalItems = response['total'] ?? 0;
        final fetchedSoFar = allLowStockProducts.length;

        if (fetchedSoFar >= totalItems) {
          hasMorePages = false;
        } else {
          currentPage++;
        }
      }

      _lowStockProducts = allLowStockProducts;
      print(
        '⚠️ InventoryProvider: Fetched ${_lowStockProducts.length} low stock products',
      );
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch low stock products: $e');
    } finally {
      _isLoadingLowStockProducts = false;
      notifyListeners();
    }
  }

  Future<void> _fetchVendors() async {
    _isLoadingVendors = true;
    notifyListeners();

    try {
      final response = await InventoryService.getVendors(limit: 1000);
      _vendors = response.data;
      print('🏪 InventoryProvider: Fetched ${_vendors.length} vendors');
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch vendors: $e');
    } finally {
      _isLoadingVendors = false;
      notifyListeners();
    }
  }

  Future<void> _fetchColors() async {
    _isLoadingColors = true;
    notifyListeners();

    try {
      final response = await InventoryService.getColors(limit: 1000);
      _colors = response.data;
      print('🎨 InventoryProvider: Fetched ${_colors.length} colors');
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch colors: $e');
    } finally {
      _isLoadingColors = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSizes() async {
    _isLoadingSizes = true;
    notifyListeners();

    try {
      final response = await InventoryService.getSizes(limit: 1000);
      _sizes = response.data;
      print('📏 InventoryProvider: Fetched ${_sizes.length} sizes');
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch sizes: $e');
    } finally {
      _isLoadingSizes = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSeasons() async {
    _isLoadingSeasons = true;
    notifyListeners();

    try {
      final response = await InventoryService.getSeasons(limit: 1000);
      _seasons = response.data;
      print('🌤️ InventoryProvider: Fetched ${_seasons.length} seasons');
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch seasons: $e');
    } finally {
      _isLoadingSeasons = false;
      notifyListeners();
    }
  }

  Future<void> _fetchMaterials() async {
    _isLoadingMaterials = true;
    notifyListeners();

    try {
      final response = await InventoryService.getMaterials(limit: 1000);
      _materials = response.data;
      print('🧵 InventoryProvider: Fetched ${_materials.length} materials');
    } catch (e) {
      print('❌ InventoryProvider: Failed to fetch materials: $e');
    } finally {
      _isLoadingMaterials = false;
      notifyListeners();
    }
  }

  // Refresh methods for individual data
  Future<void> refreshCategories() => _fetchCategories();
  Future<void> refreshSubCategories() => _fetchSubCategories();
  Future<void> refreshProducts() => _fetchProducts();
  Future<void> refreshLowStockProducts() => _fetchLowStockProducts();
  Future<void> refreshVendors() => _fetchVendors();
  Future<void> refreshColors() => _fetchColors();
  Future<void> refreshSizes() => _fetchSizes();
  Future<void> refreshSeasons() => _fetchSeasons();
  Future<void> refreshMaterials() => _fetchMaterials();

  // Set methods for updating cache from pages
  void setVendors(List<vendor.Vendor> vendors) {
    _vendors = vendors;
    notifyListeners();
  }

  void setCategories(List<category.Category> categories) {
    _categories = categories;
    notifyListeners();
  }

  void setSubCategories(List<subCategory.SubCategory> subCategories) {
    _subCategories = subCategories;
    notifyListeners();
  }

  void setProducts(List<Product> products) {
    _products = products;
    notifyListeners();
  }

  void setLowStockProducts(List<Product> lowStockProducts) {
    _lowStockProducts = lowStockProducts;
    notifyListeners();
  }

  void setColors(List<colorModel.Color> colors) {
    _colors = colors;
    notifyListeners();
  }

  void setSizes(List<sizeModel.Size> sizes) {
    _sizes = sizes;
    notifyListeners();
  }

  void setSeasons(List<seasonModel.Season> seasons) {
    _seasons = seasons;
    notifyListeners();
  }

  void setMaterials(List<materialModel.Material> materials) {
    _materials = materials;
    notifyListeners();
  }

  // Clear all data (for logout)
  void clearAllData() {
    _categories.clear();
    _subCategories.clear();
    _products.clear();
    _lowStockProducts.clear();
    _vendors.clear();
    _colors.clear();
    _sizes.clear();
    _seasons.clear();
    _materials.clear();
    notifyListeners();
  }
}

class SalesProvider with ChangeNotifier {
  // Data lists for persistent caching
  List<Invoice> _invoices = [];
  List<SalesReturn> _salesReturns = [];

  // Loading states
  bool _isLoadingInvoices = false;
  bool _isLoadingSalesReturns = false;

  // Getters
  List<Invoice> get invoices => _invoices;
  List<SalesReturn> get salesReturns => _salesReturns;

  bool get isLoadingInvoices => _isLoadingInvoices;
  bool get isLoadingSalesReturns => _isLoadingSalesReturns;

  // Set methods for updating cache from pages
  void setInvoices(List<Invoice> invoices) {
    _invoices = invoices;
    notifyListeners();
  }

  void setSalesReturns(List<SalesReturn> salesReturns) {
    _salesReturns = salesReturns;
    notifyListeners();
  }

  // Clear methods for refreshing data
  void clearInvoices() {
    _invoices.clear();
    notifyListeners();
  }

  void clearSalesReturns() {
    _salesReturns.clear();
    notifyListeners();
  }

  // Clear all sales data (for logout)
  void clearAllSalesData() {
    _invoices.clear();
    _salesReturns.clear();
    notifyListeners();
  }
}

class PurchaseProvider with ChangeNotifier {
  // Data lists for persistent caching
  List<Purchase> _purchases = [];
  List<PurchaseReturn> _purchaseReturns = [];

  // Loading states
  bool _isLoadingPurchases = false;
  bool _isLoadingPurchaseReturns = false;

  // Getters
  List<Purchase> get purchases => _purchases;
  List<PurchaseReturn> get purchaseReturns => _purchaseReturns;

  bool get isLoadingPurchases => _isLoadingPurchases;
  bool get isLoadingPurchaseReturns => _isLoadingPurchaseReturns;

  // Set methods for updating cache from pages
  void setPurchases(List<Purchase> purchases) {
    _purchases = purchases;
    notifyListeners();
  }

  void setPurchaseReturns(List<PurchaseReturn> purchaseReturns) {
    _purchaseReturns = purchaseReturns;
    notifyListeners();
  }

  // Clear methods for refreshing data
  void clearPurchases() {
    _purchases.clear();
    notifyListeners();
  }

  void clearPurchaseReturns() {
    _purchaseReturns.clear();
    notifyListeners();
  }

  // Clear all purchase data (for logout)
  void clearAllPurchaseData() {
    _purchases.clear();
    _purchaseReturns.clear();
    notifyListeners();
  }
}

class FinanceProvider with ChangeNotifier {
  // Data lists for persistent caching
  List<BankAccount> _bankAccounts = [];
  List<Income> _incomes = [];
  List<ChartOfAccount> _chartOfAccounts = [];
  List<MainHeadOfAccountWithSubs> _mainHeadAccountsWithSubs = [];
  List<SubHeadOfAccountWithAccounts> _subHeadAccountsWithAccounts = [];
  AccountStatement? _accountStatement;
  List<Payout> _payouts = [];
  List<PayIn> _payIns = [];
  List<Cashflow> _cashflow = [];

  // Loading states
  bool _isLoadingBankAccounts = false;
  bool _isLoadingExpenses = false;
  bool _isLoadingIncomes = false;
  bool _isLoadingChartOfAccounts = false;
  bool _isLoadingMainHeadAccounts = false;
  bool _isLoadingAccountStatement = false;
  bool _isLoadingPayouts = false;
  bool _isLoadingPayIns = false;
  bool _isLoadingCashflow = false;

  // Getters
  List<BankAccount> get bankAccounts => _bankAccounts;
  List<Income> get incomes => _incomes;
  List<ChartOfAccount> get chartOfAccounts => _chartOfAccounts;
  List<MainHeadOfAccountWithSubs> get mainHeadAccountsWithSubs =>
      _mainHeadAccountsWithSubs;
  List<SubHeadOfAccountWithAccounts> get subHeadAccountsWithAccounts =>
      _subHeadAccountsWithAccounts;
  AccountStatement? get accountStatement => _accountStatement;
  List<Payout> get payouts => _payouts;
  List<PayIn> get payIns => _payIns;
  List<Cashflow> get cashflow => _cashflow;

  bool get isLoadingBankAccounts => _isLoadingBankAccounts;
  bool get isLoadingExpenses => _isLoadingExpenses;
  bool get isLoadingIncomes => _isLoadingIncomes;
  bool get isLoadingChartOfAccounts => _isLoadingChartOfAccounts;
  bool get isLoadingMainHeadAccounts => _isLoadingMainHeadAccounts;
  bool get isLoadingAccountStatement => _isLoadingAccountStatement;
  bool get isLoadingPayouts => _isLoadingPayouts;
  bool get isLoadingPayIns => _isLoadingPayIns;
  bool get isLoadingCashflow => _isLoadingCashflow;

  // Set methods for updating cache from pages
  void setBankAccounts(List<BankAccount> bankAccounts) {
    _bankAccounts = bankAccounts;
    notifyListeners();
  }

  void setIncomes(List<Income> incomes) {
    _incomes = incomes;
    notifyListeners();
  }

  void setChartOfAccounts(List<ChartOfAccount> chartOfAccounts) {
    _chartOfAccounts = chartOfAccounts;
    notifyListeners();
  }

  void setMainHeadAccountsWithSubs(
    List<MainHeadOfAccountWithSubs> mainHeadAccountsWithSubs,
  ) {
    _mainHeadAccountsWithSubs = mainHeadAccountsWithSubs;
    notifyListeners();
  }

  void setSubHeadAccountsWithAccounts(
    List<SubHeadOfAccountWithAccounts> subHeadAccountsWithAccounts,
  ) {
    _subHeadAccountsWithAccounts = subHeadAccountsWithAccounts;
    notifyListeners();
  }

  void setAccountStatement(AccountStatement? accountStatement) {
    _accountStatement = accountStatement;
    notifyListeners();
  }

  void setPayouts(List<Payout> payouts) {
    _payouts = payouts;
    notifyListeners();
  }

  void setPayIns(List<PayIn> payIns) {
    _payIns = payIns;
    notifyListeners();
  }

  void setCashflow(List<Cashflow> cashflow) {
    _cashflow = cashflow;
    notifyListeners();
  }

  // Clear methods for refreshing data
  void clearBankAccounts() {
    _bankAccounts.clear();
    notifyListeners();
  }

  void clearIncomes() {
    _incomes.clear();
    notifyListeners();
  }

  void clearChartOfAccounts() {
    _chartOfAccounts.clear();
    notifyListeners();
  }

  void clearMainHeadAccountsWithSubs() {
    _mainHeadAccountsWithSubs.clear();
    notifyListeners();
  }

  void clearSubHeadAccountsWithAccounts() {
    _subHeadAccountsWithAccounts.clear();
    notifyListeners();
  }

  void clearAccountStatement() {
    _accountStatement = null;
    notifyListeners();
  }

  void clearPayouts() {
    _payouts.clear();
    notifyListeners();
  }

  void clearPayIns() {
    _payIns.clear();
    notifyListeners();
  }

  void clearCashflow() {
    _cashflow.clear();
    notifyListeners();
  }

  // Clear all finance data (for logout)
  void clearAllFinanceData() {
    _bankAccounts.clear();
    _incomes.clear();
    _chartOfAccounts.clear();
    _mainHeadAccountsWithSubs.clear();
    _subHeadAccountsWithAccounts.clear();
    _accountStatement = null;
    _payouts.clear();
    _payIns.clear();
    _cashflow.clear();
    notifyListeners();
  }
}

class WindowProvider with ChangeNotifier {
  bool _isFullScreen = false;
  bool get isFullScreen => _isFullScreen;

  Future<void> toggleFullScreen() async {
    try {
      if (_isFullScreen) {
        await windowManager.setFullScreen(false);
        await windowManager.setSize(const Size(1200, 700));
        await windowManager.center();
        _isFullScreen = false;
      } else {
        await windowManager.setFullScreen(true);
        _isFullScreen = true;
      }
      notifyListeners();
    } catch (e) {
      print('Error toggling full screen: $e');
    }
  }

  Future<void> exitFullScreen() async {
    if (_isFullScreen) {
      await toggleFullScreen();
    }
  }

  Future<void> initWindow() async {
    // Check initial state
    _isFullScreen = await windowManager.isFullScreen();
    notifyListeners();
  }
}

class PeopleProvider with ChangeNotifier {
  // Data lists for persistent caching
  List<Map<String, dynamic>> _creditCustomers = [];

  // Loading states
  bool _isLoadingCreditCustomers = false;

  // Getters
  List<Map<String, dynamic>> get creditCustomers => _creditCustomers;

  bool get isLoadingCreditCustomers => _isLoadingCreditCustomers;

  // Set methods for updating cache from pages
  void setCreditCustomers(List<Map<String, dynamic>> creditCustomers) {
    _creditCustomers = creditCustomers;
    notifyListeners();
  }

  // Clear methods for refreshing data
  void clearCreditCustomers() {
    _creditCustomers.clear();
    notifyListeners();
  }

  // Clear all people data (for logout)
  void clearAllPeopleData() {
    _creditCustomers.clear();
    notifyListeners();
  }
}
