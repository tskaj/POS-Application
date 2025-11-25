import '../services/services.dart';

// Models for Chart of Accounts
class MainHeadAccount {
  final int id;
  final String name;
  final String code;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  MainHeadAccount({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MainHeadAccount.fromJson(Map<String, dynamic> json) {
    return MainHeadAccount(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }
}

class SubHeadAccount {
  final int id;
  final String name;
  final String code;
  final int mainHeadId;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubHeadAccount({
    required this.id,
    required this.name,
    required this.code,
    required this.mainHeadId,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubHeadAccount.fromJson(Map<String, dynamic> json) {
    return SubHeadAccount(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      mainHeadId: json['main_head_id'] ?? 0,
      description: json['description'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }
}

class HeadAccount {
  final int id;
  final String name;
  final String code;
  final int subHeadId;
  final int mainHeadId;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  HeadAccount({
    required this.id,
    required this.name,
    required this.code,
    required this.subHeadId,
    required this.mainHeadId,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HeadAccount.fromJson(Map<String, dynamic> json) {
    return HeadAccount(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      subHeadId: json['sub_head_id'] ?? 0,
      mainHeadId: json['main_head_id'] ?? 0,
      description: json['description'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }
}

// New COA model to match API response structure
class ChartOfAccount {
  final int id;
  final String code;
  final String title;
  final String type;
  final String status;
  final SubHeadOfAccount sub;

  ChartOfAccount({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
    required this.sub,
  });

  // Convenience getter to access main from sub
  MainHeadOfAccount get main => sub.main;

  factory ChartOfAccount.fromJson(Map<String, dynamic> json) {
    return ChartOfAccount(
      id: json['id'] ?? 0,
      code: (json['code'] ?? '').toString(),
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      sub: SubHeadOfAccount.fromJson(json['sub'] ?? {}),
    );
  }
}

class MainHeadOfAccountWithSubs {
  final int id;
  final String code;
  final String title;
  final String type;
  final String status;
  final List<SubHeadOfAccountWithAccounts> subs;

  MainHeadOfAccountWithSubs({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
    required this.subs,
  });

  factory MainHeadOfAccountWithSubs.fromJson(Map<String, dynamic> json) {
    return MainHeadOfAccountWithSubs(
      id: json['id'] ?? 0,
      code: (json['code'] ?? '').toString(),
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      subs:
          (json['subs'] as List<dynamic>?)
              ?.map((item) => SubHeadOfAccountWithAccounts.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SubHeadOfAccountWithAccounts {
  final int id;
  final String code;
  final String title;
  final String type;
  final String status;
  final List<AccountOfSubHead> accounts;

  SubHeadOfAccountWithAccounts({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
    required this.accounts,
  });

  factory SubHeadOfAccountWithAccounts.fromJson(Map<String, dynamic> json) {
    return SubHeadOfAccountWithAccounts(
      id: json['id'] ?? 0,
      code: (json['code'] ?? '').toString(),
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      accounts:
          (json['accounts'] as List<dynamic>?)
              ?.map((item) => AccountOfSubHead.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class AccountOfSubHead {
  final int id;
  final String code;
  final String title;
  final String type;
  final String status;

  AccountOfSubHead({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
  });

  factory AccountOfSubHead.fromJson(Map<String, dynamic> json) {
    return AccountOfSubHead(
      id: json['id'] ?? 0,
      code: (json['code'] ?? '').toString(),
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class MainHeadOfAccount {
  final int id;
  final String code;
  final String title;
  final String type;
  final String status;

  MainHeadOfAccount({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
  });

  factory MainHeadOfAccount.fromJson(Map<String, dynamic> json) {
    return MainHeadOfAccount(
      id: json['id'] ?? 0,
      code: (json['code'] ?? '').toString(),
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class SubHeadOfAccount {
  final int id;
  final String code;
  final String title;
  final String type;
  final String status;
  final MainHeadOfAccount main;

  SubHeadOfAccount({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
    required this.main,
  });

  factory SubHeadOfAccount.fromJson(Map<String, dynamic> json) {
    return SubHeadOfAccount(
      id: json['id'] ?? 0,
      code: (json['code'] ?? '').toString(),
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      main: MainHeadOfAccount.fromJson(json['main'] ?? {}),
    );
  }
}

class ChartOfAccountsResponse {
  final List<MainHeadAccount> mainHeads;
  final List<SubHeadAccount> subHeads;
  final List<HeadAccount> heads;

  ChartOfAccountsResponse({
    required this.mainHeads,
    required this.subHeads,
    required this.heads,
  });

  factory ChartOfAccountsResponse.fromJson(Map<String, dynamic> json) {
    return ChartOfAccountsResponse(
      mainHeads:
          (json['main_heads'] as List<dynamic>?)
              ?.map((item) => MainHeadAccount.fromJson(item))
              .toList() ??
          [],
      subHeads:
          (json['sub_heads'] as List<dynamic>?)
              ?.map((item) => SubHeadAccount.fromJson(item))
              .toList() ??
          [],
      heads:
          (json['heads'] as List<dynamic>?)
              ?.map((item) => HeadAccount.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Service class
class ChartOfAccountsService {
  static const String mainHeadEndpoint = '/main-head-accounts';
  static const String subHeadEndpoint = '/sub-head-accounts';
  static const String headEndpoint = '/head-accounts';
  static const String coasEndpoint = '/coas';

  // Get all COAs from the new API endpoint
  static Future<List<ChartOfAccount>> getAllChartOfAccounts() async {
    try {
      final response = await ApiService.get(coasEndpoint);

      if (response['data'] != null && response['data'] is List) {
        return (response['data'] as List<dynamic>)
            .map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return ChartOfAccount.fromJson(item);
                } else {
                  print('⚠️ Invalid COA item format: $item');
                  return null;
                }
              } catch (e) {
                print('⚠️ Error parsing COA item: $e, item: $item');
                return null;
              }
            })
            .where((coa) => coa != null)
            .cast<ChartOfAccount>()
            .toList();
      } else {
        print('⚠️ No data found in COAs response');
        return [];
      }
    } catch (e) {
      print('💥 Error fetching COAs: $e');
      throw Exception('Failed to load chart of accounts: $e');
    }
  }

  // Get all main head accounts
  static Future<List<MainHeadAccount>> getMainHeadAccounts() async {
    try {
      final response = await ApiService.get(mainHeadEndpoint);

      if (response['data'] != null) {
        return (response['data'] as List<dynamic>)
            .map((item) => MainHeadAccount.fromJson(item))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Failed to load main head accounts: $e');
    }
  }

  // Get all main head accounts with nested structure
  static Future<List<MainHeadOfAccountWithSubs>>
  getAllMainHeadAccounts() async {
    try {
      final response = await ApiService.get('/coa-mains');

      if (response['data'] != null && response['data'] is List) {
        return (response['data'] as List<dynamic>)
            .map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return MainHeadOfAccountWithSubs.fromJson(item);
                } else {
                  print('⚠️ Invalid main head item format: $item');
                  return null;
                }
              } catch (e) {
                print('⚠️ Error parsing main head item: $e, item: $item');
                return null;
              }
            })
            .where((mainHead) => mainHead != null)
            .cast<MainHeadOfAccountWithSubs>()
            .toList();
      } else {
        print('⚠️ No data found in main heads response');
        return [];
      }
    } catch (e) {
      print('💥 Error fetching main heads: $e');
      throw Exception('Failed to load main head accounts: $e');
    }
  }

  // Get sub head accounts by main head ID
  static Future<List<SubHeadOfAccountWithAccounts>>
  getSubHeadAccountsByMainHead(int mainHeadId) async {
    try {
      final allMainHeads = await getAllMainHeadAccounts();
      final mainHead = allMainHeads.firstWhere(
        (mh) => mh.id == mainHeadId,
        orElse: () => throw Exception('Main head account not found'),
      );
      return mainHead.subs;
    } catch (e) {
      throw Exception(
        'Failed to load sub head accounts for main head $mainHeadId: $e',
      );
    }
  }

  // Get head accounts by sub head ID
  static Future<List<HeadAccount>> getHeadAccounts(int subHeadId) async {
    try {
      final response = await ApiService.get(
        '$headEndpoint?sub_head_id=$subHeadId',
      );

      if (response['data'] != null) {
        return (response['data'] as List<dynamic>)
            .map((item) => HeadAccount.fromJson(item))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Failed to load head accounts: $e');
    }
  }

  // Get all chart of accounts data
  static Future<ChartOfAccountsResponse> getChartOfAccounts({
    int? mainHeadId,
    int? subHeadId,
  }) async {
    try {
      String endpoint = '/chart-of-accounts';
      List<String> params = [];

      if (mainHeadId != null) {
        params.add('main_head_id=$mainHeadId');
      }
      if (subHeadId != null) {
        params.add('sub_head_id=$subHeadId');
      }

      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final response = await ApiService.get(endpoint);

      if (response['data'] != null) {
        return ChartOfAccountsResponse.fromJson(response['data']);
      } else {
        return ChartOfAccountsResponse(mainHeads: [], subHeads: [], heads: []);
      }
    } catch (e) {
      throw Exception('Failed to load chart of accounts: $e');
    }
  }

  // Create main head account
  static Future<MainHeadAccount> createMainHeadAccount(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiService.post(mainHeadEndpoint, data);

      if (response['data'] != null) {
        return MainHeadAccount.fromJson(response['data']);
      } else {
        throw Exception('Failed to create main head account');
      }
    } catch (e) {
      throw Exception('Failed to create main head account: $e');
    }
  }

  // Create sub head account
  static Future<SubHeadAccount> createSubHeadAccount(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiService.post(subHeadEndpoint, data);

      if (response['data'] != null) {
        return SubHeadAccount.fromJson(response['data']);
      } else {
        throw Exception('Failed to create sub head account');
      }
    } catch (e) {
      throw Exception('Failed to create sub head account: $e');
    }
  }

  // Create new COA (Chart of Account)
  static Future<ChartOfAccount> createChartOfAccount(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiService.post(coasEndpoint, data);

      if (response['data'] != null) {
        return ChartOfAccount.fromJson(response['data']);
      } else {
        throw Exception('Failed to create chart of account');
      }
    } catch (e) {
      throw Exception('Failed to create chart of account: $e');
    }
  }

  // Create head account
  static Future<HeadAccount> createHeadAccount(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiService.post(headEndpoint, data);

      if (response['data'] != null) {
        return HeadAccount.fromJson(response['data']);
      } else {
        throw Exception('Failed to create head account');
      }
    } catch (e) {
      throw Exception('Failed to create head account: $e');
    }
  }

  // Create COA sub (sub head account) using new API
  static Future<Map<String, dynamic>> createCoaSub(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiService.post('/coa_subs', data);

      if (response['status'] == true && response['data'] != null) {
        return response['data'];
      } else {
        throw Exception(response['message'] ?? 'Failed to create COA sub');
      }
    } catch (e) {
      throw Exception('Failed to create COA sub: $e');
    }
  }
}
