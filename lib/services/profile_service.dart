import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';
import 'local_cache_service.dart';

class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  SupabaseClient get _client => Supabase.instance.client;

  User? get _currentUser => _client.auth.currentUser;

  Future<UserProfile> getCurrentUserProfile() async {
    return _getCurrentUserProfileInternal();
  }

  Future<UserProfile> _getCurrentUserProfileInternal({
    bool allowJwtRetry = true,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nao existe utilizador autenticado.');
    }

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        throw StateError(
          'Nao foi encontrado um perfil valido para este utilizador.',
        );
      }

      final map = Map<String, dynamic>.from(data);
      map.putIfAbsent('email', () => user.email ?? '');

      final technicianId = map['technician_id']?.toString();
      if (technicianId != null && technicianId.isNotEmpty) {
        try {
          final technicianData = await _client
              .from('technicians')
              .select(
                'can_access_assets, can_access_locations, can_access_work_orders, can_create_work_orders, can_view_all_work_orders, can_close_work_orders, can_edit_work_orders, can_edit_assets, can_edit_asset_devices, can_edit_locations, can_view_alerts, can_manage_technicians, can_manage_users',
              )
              .eq('id', technicianId)
              .maybeSingle();

          if (technicianData != null) {
            map.putIfAbsent(
              'can_access_assets',
              () => technicianData['can_access_assets'],
            );
            map.putIfAbsent(
              'can_access_locations',
              () => technicianData['can_access_locations'],
            );
            map.putIfAbsent(
              'can_access_work_orders',
              () => technicianData['can_access_work_orders'],
            );
            map.putIfAbsent(
              'can_create_work_orders',
              () => technicianData['can_create_work_orders'],
            );
            map.putIfAbsent(
              'can_view_all_work_orders',
              () => technicianData['can_view_all_work_orders'],
            );
            map.putIfAbsent(
              'can_close_work_orders',
              () => technicianData['can_close_work_orders'],
            );
            map.putIfAbsent(
              'can_edit_work_orders',
              () => technicianData['can_edit_work_orders'],
            );
            map.putIfAbsent(
              'can_edit_assets',
              () => technicianData['can_edit_assets'],
            );
            map.putIfAbsent(
              'can_edit_asset_devices',
              () => technicianData['can_edit_asset_devices'],
            );
            map.putIfAbsent(
              'can_edit_locations',
              () => technicianData['can_edit_locations'],
            );
            map.putIfAbsent(
              'can_view_alerts',
              () => technicianData['can_view_alerts'],
            );
            map.putIfAbsent(
              'can_manage_technicians',
              () => technicianData['can_manage_technicians'],
            );
            map.putIfAbsent(
              'can_manage_users',
              () => technicianData['can_manage_users'],
            );
          }
        } catch (_) {
          // Keep profile data even if technician permissions are unavailable.
        }
      }

      await LocalCacheService.instance.writeJson(
        _cacheKeyForUser(user.id),
        map,
      );
      return UserProfile.fromMap(map);
    } catch (error) {
      if (allowJwtRetry && _isInvalidJwtError(error)) {
        try {
          final refreshed = await AuthService.instance
              .refreshSessionIfPossible();
          if (refreshed) {
            return _getCurrentUserProfileInternal(allowJwtRetry: false);
          }
        } catch (_) {}
      }

      final cached = await LocalCacheService.instance.readJsonMap(
        _cacheKeyForUser(user.id),
      );
      if (cached != null) {
        cached.putIfAbsent('email', () => user.email ?? '');
        cached.putIfAbsent('id', () => user.id);
        return UserProfile.fromMap(cached);
      }
      rethrow;
    }
  }

  String _cacheKeyForUser(String userId) => 'user_profile:$userId';

  bool _isInvalidJwtError(Object error) {
    if (error is AuthException) {
      final code = error.code?.toLowerCase().trim() ?? '';
      final message = error.message.toLowerCase();
      return code == 'bad_jwt' ||
          message.contains('invalid jwt') ||
          message.contains('jwt');
    }

    if (error is PostgrestException) {
      final text = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
          .toLowerCase();
      return text.contains('invalid jwt') || text.contains('jwt');
    }

    final text = error.toString().toLowerCase();
    return text.contains('invalid jwt') || text.contains('jwt');
  }
}
