class CompanyEmailConnection {
  const CompanyEmailConnection({
    required this.id,
    this.companyId,
    required this.provider,
    required this.email,
    this.displayName,
    this.status,
    this.externalAccountId,
    this.accessScope = const <String>[],
    this.connectedAt,
    this.lastSyncAt,
    this.lastTestAt,
    this.lastError,
    this.metadata = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? companyId;
  final String provider;
  final String email;
  final String? displayName;
  final String? status;
  final String? externalAccountId;
  final List<String> accessScope;
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;
  final DateTime? lastTestAt;
  final String? lastError;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isConnected => status == 'connected';

  String get providerLabel {
    switch (provider) {
      case 'google':
        return 'Google';
      case 'microsoft':
        return 'Microsoft';
      default:
        return provider;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'connected':
        return 'Ligada';
      case 'needs_reauth':
        return 'Reautenticacao necessaria';
      case 'revoked':
        return 'Revogada';
      case 'error':
        return 'Com erro';
      case 'pending_setup':
        return 'Preparacao pendente';
      default:
        return 'Estado desconhecido';
    }
  }

  String get identityLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name <$email>';
    }
    return email;
  }

  factory CompanyEmailConnection.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    final rawScopes = map['access_scope'];
    final scopes = rawScopes is List
        ? rawScopes.map((item) => item.toString()).toList()
        : const <String>[];

    final rawMetadata = map['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : const <String, dynamic>{};

    return CompanyEmailConnection(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString(),
      provider: map['provider']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['display_name']?.toString(),
      status: map['status']?.toString(),
      externalAccountId: map['external_account_id']?.toString(),
      accessScope: scopes,
      connectedAt: parseDate(map['connected_at']),
      lastSyncAt: parseDate(map['last_sync_at']),
      lastTestAt: parseDate(map['last_test_at']),
      lastError: map['last_error']?.toString(),
      metadata: metadata,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
