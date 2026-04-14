class CompanyProfile {
  const CompanyProfile({
    required this.id,
    this.companyId,
    this.name,
    this.legalName,
    this.taxId,
    this.email,
    this.phone,
    this.website,
    this.address,
    this.postalCode,
    this.city,
    this.country,
    this.logoUrl,
    this.coverPhotoUrl,
    this.notes,
    this.authorizationEmailSendMode,
    this.authorizationEmailProvider,
    this.authorizationEmailConnectionId,
    this.authorizationEmailSignature,
    this.authorizationSenderEmail,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? companyId;
  final String? name;
  final String? legalName;
  final String? taxId;
  final String? email;
  final String? phone;
  final String? website;
  final String? address;
  final String? postalCode;
  final String? city;
  final String? country;
  final String? logoUrl;
  final String? coverPhotoUrl;
  final String? notes;
  final String? authorizationEmailSendMode;
  final String? authorizationEmailProvider;
  final String? authorizationEmailConnectionId;
  final String? authorizationEmailSignature;
  final String? authorizationSenderEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get resolvedAuthorizationEmailProvider {
    switch (authorizationEmailProvider?.trim().toLowerCase()) {
      case 'google':
        return 'google';
      case 'microsoft':
        return 'microsoft';
      default:
        return 'manual';
    }
  }

  bool get usesLinkedAuthorizationEmailProvider =>
      resolvedAuthorizationEmailProvider != 'manual';

  String get authorizationEmailProviderLabel {
    switch (resolvedAuthorizationEmailProvider) {
      case 'google':
        return 'Google';
      case 'microsoft':
        return 'Microsoft';
      default:
        return 'Manual';
    }
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return CompanyProfile(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString(),
      name: map['name']?.toString(),
      legalName: map['legal_name']?.toString(),
      taxId: map['tax_id']?.toString(),
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      website: map['website']?.toString(),
      address: map['address']?.toString(),
      postalCode: map['postal_code']?.toString(),
      city: map['city']?.toString(),
      country: map['country']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      coverPhotoUrl: map['cover_photo_url']?.toString(),
      notes: map['notes']?.toString(),
      authorizationEmailSendMode: map['authorization_email_send_mode']
          ?.toString(),
      authorizationEmailProvider: map['authorization_email_provider']
          ?.toString(),
      authorizationEmailConnectionId: map['authorization_email_connection_id']
          ?.toString(),
      authorizationEmailSignature: map['authorization_email_signature']
          ?.toString(),
      authorizationSenderEmail: map['authorization_sender_email']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
