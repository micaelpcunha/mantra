import '../models/user_profile.dart';

class ClientScopeService {
  ClientScopeService._();

  static bool hasScope(UserProfile? profile) {
    if (profile == null || !profile.isClient) return false;
    return profile.clientAssetIds.isNotEmpty || profile.clientLocationIds.isNotEmpty;
  }

  static bool canAccessAsset(UserProfile? profile, Map<String, dynamic> asset) {
    if (profile == null || !profile.isClient) return true;
    if (!hasScope(profile)) return true;

    final assetId = asset['id']?.toString();
    final locationId = asset['location_id']?.toString();

    return (assetId != null && profile.clientAssetIds.contains(assetId)) ||
        (locationId != null && profile.clientLocationIds.contains(locationId));
  }

  static bool canAccessLocation(
    UserProfile? profile,
    Map<String, dynamic> location, {
    Iterable<Map<String, dynamic>> assets = const [],
  }) {
    if (profile == null || !profile.isClient) return true;
    if (!hasScope(profile)) return true;

    final locationId = location['id']?.toString();
    if (locationId != null && profile.clientLocationIds.contains(locationId)) {
      return true;
    }

    for (final asset in assets) {
      final assetLocationId = asset['location_id']?.toString();
      if (assetLocationId != locationId) continue;
      if (canAccessAsset(profile, asset)) return true;
    }

    return false;
  }

  static bool canAccessWorkOrder(
    UserProfile? profile,
    Map<String, dynamic> workOrder, {
    required Map<String, Map<String, dynamic>> assetsById,
  }) {
    if (profile == null || !profile.isClient) return true;
    if (!hasScope(profile)) return true;

    final assetId = workOrder['asset_id']?.toString();
    if (assetId == null || assetId.isEmpty) return false;

    final asset = assetsById[assetId];
    if (asset == null) {
      return profile.clientAssetIds.contains(assetId);
    }

    return canAccessAsset(profile, asset);
  }
}
