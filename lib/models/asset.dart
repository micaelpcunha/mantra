class Asset {
  const Asset({
    required this.id,
    required this.name,
    required this.status,
    required this.completedTasks,
    required this.locationId,
    this.companyId,
  });

  final dynamic id;
  final String name;
  final String status;
  final int completedTasks;
  final dynamic locationId;
  final String? companyId;

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      name: map['name']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      completedTasks: (map['tarefas_concluidas'] as num?)?.toInt() ?? 0,
      locationId: map['location_id'],
      companyId: map['company_id']?.toString(),
    );
  }
}
