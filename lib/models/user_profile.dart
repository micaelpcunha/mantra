enum AppRole {
  admin,
  technician,
  client;

  String get label {
    switch (this) {
      case AppRole.admin:
        return 'Admin';
      case AppRole.technician:
        return 'Tecnico';
      case AppRole.client:
        return 'Cliente';
    }
  }

  static AppRole fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'tecnico':
      case 'technician':
        return AppRole.technician;
      case 'cliente':
      case 'client':
        return AppRole.client;
      case 'admin':
      default:
        return AppRole.admin;
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    required this.technicianId,
    this.companyId,
    this.canAccessAssets = true,
    this.canAccessLocations = true,
    this.canAccessWorkOrders = true,
    this.canCreateWorkOrders = false,
    this.canViewAllWorkOrders = false,
    this.canCloseWorkOrders = true,
    this.canEditWorkOrders = false,
    this.canEditAssets = false,
    this.canEditAssetDevices = false,
    this.canEditLocations = false,
    this.canViewAlerts = false,
    this.canManageTechnicians = false,
    this.canManageUsers = false,
    this.canClientViewDescription = true,
    this.canClientViewComments = true,
    this.canClientViewPhotos = true,
    this.canClientViewAttachments = true,
    this.canClientViewScheduling = true,
    this.canClientViewTechnician = true,
    this.canClientViewLocation = true,
    this.clientAssetIds = const [],
    this.clientLocationIds = const [],
  });

  final String id;
  final String email;
  final AppRole role;
  final String? fullName;
  final String? technicianId;
  final String? companyId;
  final bool canAccessAssets;
  final bool canAccessLocations;
  final bool canAccessWorkOrders;
  final bool canCreateWorkOrders;
  final bool canViewAllWorkOrders;
  final bool canCloseWorkOrders;
  final bool canEditWorkOrders;
  final bool canEditAssets;
  final bool canEditAssetDevices;
  final bool canEditLocations;
  final bool canViewAlerts;
  final bool canManageTechnicians;
  final bool canManageUsers;
  final bool canClientViewDescription;
  final bool canClientViewComments;
  final bool canClientViewPhotos;
  final bool canClientViewAttachments;
  final bool canClientViewScheduling;
  final bool canClientViewTechnician;
  final bool canClientViewLocation;
  final List<String> clientAssetIds;
  final List<String> clientLocationIds;

  bool get isAdmin => role == AppRole.admin;
  bool get isTechnician => role == AppRole.technician;
  bool get isClient => role == AppRole.client;
  bool get mayCreateWorkOrders => isAdmin || canCreateWorkOrders;
  bool get mayViewAllWorkOrders => isAdmin || canViewAllWorkOrders;
  bool get mayCloseWorkOrders => isAdmin || canCloseWorkOrders;
  bool get mayEditWorkOrders => isAdmin || canEditWorkOrders;
  bool get mayEditAssets => isAdmin || canEditAssets;
  bool get mayEditAssetDevices => isAdmin || canEditAssetDevices;
  bool get mayEditLocations => isAdmin || canEditLocations;
  bool get mayViewAlerts => isAdmin || canViewAlerts;
  bool get mayManageTechnicians => isAdmin || canManageTechnicians;
  bool get mayManageUsers => isAdmin || canManageUsers;

  UserProfile copyWith({
    String? id,
    String? email,
    AppRole? role,
    String? fullName,
    String? technicianId,
    String? companyId,
    bool? canAccessAssets,
    bool? canAccessLocations,
    bool? canAccessWorkOrders,
    bool? canCreateWorkOrders,
    bool? canViewAllWorkOrders,
    bool? canCloseWorkOrders,
    bool? canEditWorkOrders,
    bool? canEditAssets,
    bool? canEditAssetDevices,
    bool? canEditLocations,
    bool? canViewAlerts,
    bool? canManageTechnicians,
    bool? canManageUsers,
    bool? canClientViewDescription,
    bool? canClientViewComments,
    bool? canClientViewPhotos,
    bool? canClientViewAttachments,
    bool? canClientViewScheduling,
    bool? canClientViewTechnician,
    bool? canClientViewLocation,
    List<String>? clientAssetIds,
    List<String>? clientLocationIds,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      technicianId: technicianId ?? this.technicianId,
      companyId: companyId ?? this.companyId,
      canAccessAssets: canAccessAssets ?? this.canAccessAssets,
      canAccessLocations: canAccessLocations ?? this.canAccessLocations,
      canAccessWorkOrders: canAccessWorkOrders ?? this.canAccessWorkOrders,
      canCreateWorkOrders: canCreateWorkOrders ?? this.canCreateWorkOrders,
      canViewAllWorkOrders: canViewAllWorkOrders ?? this.canViewAllWorkOrders,
      canCloseWorkOrders: canCloseWorkOrders ?? this.canCloseWorkOrders,
      canEditWorkOrders: canEditWorkOrders ?? this.canEditWorkOrders,
      canEditAssets: canEditAssets ?? this.canEditAssets,
      canEditAssetDevices: canEditAssetDevices ?? this.canEditAssetDevices,
      canEditLocations: canEditLocations ?? this.canEditLocations,
      canViewAlerts: canViewAlerts ?? this.canViewAlerts,
      canManageTechnicians: canManageTechnicians ?? this.canManageTechnicians,
      canManageUsers: canManageUsers ?? this.canManageUsers,
      canClientViewDescription:
          canClientViewDescription ?? this.canClientViewDescription,
      canClientViewComments:
          canClientViewComments ?? this.canClientViewComments,
      canClientViewPhotos: canClientViewPhotos ?? this.canClientViewPhotos,
      canClientViewAttachments:
          canClientViewAttachments ?? this.canClientViewAttachments,
      canClientViewScheduling:
          canClientViewScheduling ?? this.canClientViewScheduling,
      canClientViewTechnician:
          canClientViewTechnician ?? this.canClientViewTechnician,
      canClientViewLocation:
          canClientViewLocation ?? this.canClientViewLocation,
      clientAssetIds: clientAssetIds ?? this.clientAssetIds,
      clientLocationIds: clientLocationIds ?? this.clientLocationIds,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    List<String> readStringList(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return UserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: AppRole.fromString(map['role']?.toString()),
      fullName: map['full_name']?.toString(),
      technicianId: map['technician_id']?.toString(),
      companyId: map['company_id']?.toString(),
      canAccessAssets: map['can_access_assets'] != false,
      canAccessLocations: map['can_access_locations'] != false,
      canAccessWorkOrders: map['can_access_work_orders'] != false,
      canCreateWorkOrders: map['can_create_work_orders'] == true,
      canViewAllWorkOrders: map['can_view_all_work_orders'] == true,
      canCloseWorkOrders: map['can_close_work_orders'] != false,
      canEditWorkOrders: map['can_edit_work_orders'] == true,
      canEditAssets: map['can_edit_assets'] == true,
      canEditAssetDevices: map['can_edit_asset_devices'] == true,
      canEditLocations: map['can_edit_locations'] == true,
      canViewAlerts: map['can_view_alerts'] == true,
      canManageTechnicians: map['can_manage_technicians'] == true,
      canManageUsers: map['can_manage_users'] == true,
      canClientViewDescription: map['can_client_view_description'] != false,
      canClientViewComments: map['can_client_view_comments'] != false,
      canClientViewPhotos: map['can_client_view_photos'] != false,
      canClientViewAttachments: map['can_client_view_attachments'] != false,
      canClientViewScheduling: map['can_client_view_scheduling'] != false,
      canClientViewTechnician: map['can_client_view_technician'] != false,
      canClientViewLocation: map['can_client_view_location'] != false,
      clientAssetIds: readStringList(map['client_asset_ids']),
      clientLocationIds: readStringList(map['client_location_ids']),
    );
  }
}
