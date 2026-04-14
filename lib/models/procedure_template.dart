class ProcedureChecklistItem {
  const ProcedureChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
    this.requiresPhoto = false,
    this.isRequired = false,
    this.photoUrl,
  });

  final String id;
  final String title;
  final bool isChecked;
  final bool requiresPhoto;
  final bool isRequired;
  final String? photoUrl;

  bool get hasPhoto => (photoUrl?.trim().isNotEmpty ?? false);

  ProcedureChecklistItem copyWith({
    String? id,
    String? title,
    bool? isChecked,
    bool? requiresPhoto,
    bool? isRequired,
    String? photoUrl,
    bool clearPhoto = false,
  }) {
    return ProcedureChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      isRequired: isRequired ?? this.isRequired,
      photoUrl: clearPhoto ? null : photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toTemplateMap() {
    return {
      'id': id,
      'title': title,
      'requires_photo': requiresPhoto,
      'is_required': isRequired,
    };
  }

  Map<String, dynamic> toSnapshotMap() {
    return {
      'id': id,
      'title': title,
      'is_checked': isChecked,
      'requires_photo': requiresPhoto,
      'is_required': isRequired,
      'photo_url': photoUrl,
    };
  }

  static List<ProcedureChecklistItem> listFromDynamic(dynamic value) {
    if (value is! List) return const [];

    final items = <ProcedureChecklistItem>[];
    for (var index = 0; index < value.length; index++) {
      final raw = value[index];
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(raw);
      final title = map['title']?.toString().trim() ?? '';
      if (title.isEmpty) continue;

      final id = map['id']?.toString().trim();
      items.add(
        ProcedureChecklistItem(
          id: id == null || id.isEmpty ? 'step_${index + 1}' : id,
          title: title,
          isChecked: map['is_checked'] == true,
          requiresPhoto: map['requires_photo'] == true,
          isRequired: map['is_required'] == true,
          photoUrl: map['photo_url']?.toString().trim(),
        ),
      );
    }

    return items;
  }

  static List<Map<String, dynamic>> toTemplateJson(
    List<ProcedureChecklistItem> items,
  ) {
    return items.map((item) => item.toTemplateMap()).toList();
  }

  static List<Map<String, dynamic>> toSnapshotJson(
    List<ProcedureChecklistItem> items,
  ) {
    return items.map((item) => item.toSnapshotMap()).toList();
  }

  static List<ProcedureChecklistItem> resetChecks(
    List<ProcedureChecklistItem> items,
  ) {
    return items
        .map((item) => item.copyWith(isChecked: false, clearPhoto: true))
        .toList();
  }
}

class ProcedureTemplate {
  const ProcedureTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
    this.isActive = true,
    this.companyId,
    this.assetId,
    this.assetDeviceId,
    this.assetDeviceName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final List<ProcedureChecklistItem> steps;
  final bool isActive;
  final String? companyId;
  final String? assetId;
  final String? assetDeviceId;
  final String? assetDeviceName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get stepCount => steps.length;

  ProcedureTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<ProcedureChecklistItem>? steps,
    bool? isActive,
    String? companyId,
    String? assetId,
    String? assetDeviceId,
    String? assetDeviceName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProcedureTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      isActive: isActive ?? this.isActive,
      companyId: companyId ?? this.companyId,
      assetId: assetId ?? this.assetId,
      assetDeviceId: assetDeviceId ?? this.assetDeviceId,
      assetDeviceName: assetDeviceName ?? this.assetDeviceName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProcedureTemplate.fromMap(Map<String, dynamic> map) {
    return ProcedureTemplate(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString().trim() ?? '',
      description: map['description']?.toString(),
      steps: ProcedureChecklistItem.listFromDynamic(map['steps']),
      isActive: map['is_active'] != false,
      companyId: map['company_id']?.toString(),
      assetId: map['asset_id']?.toString(),
      assetDeviceId: map['asset_device_id']?.toString(),
      assetDeviceName: map['asset_device_name']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}
