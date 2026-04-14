class Location {
  const Location({
    required this.id,
    required this.name,
    required this.photoUrl,
    this.companyId,
  });

  final dynamic id;
  final String name;
  final String? photoUrl;
  final String? companyId;

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'],
      name: map['name']?.toString() ?? '',
      photoUrl: map['photo_url']?.toString(),
      companyId: map['company_id']?.toString(),
    );
  }
}
