class Technician {
  const Technician({
    required this.id,
    required this.name,
    required this.email,
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
    this.contact,
    this.address,
    this.photoUrl,
    this.documentUrl,
  });

  final String id;
  final String name;
  final String? email;
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
  final String? contact;
  final String? address;
  final String? photoUrl;
  final String? documentUrl;

  factory Technician.fromMap(Map<String, dynamic> map) {
    return Technician(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString(),
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
      contact: map['contact']?.toString(),
      address: map['address']?.toString(),
      photoUrl: map['profile_photo_url']?.toString(),
      documentUrl: map['document_url']?.toString(),
    );
  }
}
