import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/location.dart';
import 'company_scope_service.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Location>> fetchLocations() async {
    final data = await _client.from('locations').select().order('name');
    return List<Map<String, dynamic>>.from(data)
        .map(Location.fromMap)
        .toList();
  }

  Future<void> createLocation({
    required String name,
  }) async {
    final payload = await CompanyScopeService.instance.attachCurrentCompanyId(
      table: 'locations',
      payload: {
        'name': name,
      },
    );

    await _client.from('locations').insert(payload);
  }

  Future<void> updateLocation({
    required dynamic locationId,
    required String name,
  }) {
    return _client.from('locations').update({
      'name': name,
    }).eq('id', locationId);
  }

  Future<void> deleteLocation({
    required dynamic locationId,
  }) {
    return _client.from('locations').delete().eq('id', locationId);
  }
}
