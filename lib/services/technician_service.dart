import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/technician.dart';
import 'company_scope_service.dart';

class TechnicianService {
  TechnicianService._();

  static final TechnicianService instance = TechnicianService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Technician>> fetchTechnicians() async {
    final data = await _client.from('technicians').select().order('id');
    return List<Map<String, dynamic>>.from(data)
        .map(Technician.fromMap)
        .toList();
  }

  Future<void> createTechnician({
    required String id,
    required String name,
    String? email,
    String? contact,
    String? address,
    String? photoUrl,
    String? documentUrl,
  }) async {
    final payload = await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'technicians',
      payload: {
        'id': id,
        'name': name,
        'email': email,
        'contact': contact,
        'address': address,
        'profile_photo_url': photoUrl,
        'document_url': documentUrl,
      },
    );

    await _client.from('technicians').insert(payload);
  }

  Future<void> updateTechnician({
    required String id,
    required String name,
    String? email,
    String? contact,
    String? address,
    String? photoUrl,
    String? documentUrl,
  }) {
    return _client.from('technicians').update({
      'name': name,
      'email': email,
      'contact': contact,
      'address': address,
      'profile_photo_url': photoUrl,
      'document_url': documentUrl,
    }).eq('id', id);
  }

  Future<void> deleteTechnician({
    required String id,
  }) {
    return _client.from('technicians').delete().eq('id', id);
  }
}
