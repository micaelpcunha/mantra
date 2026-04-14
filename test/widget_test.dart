import 'package:asset_app/dashboard_page.dart';
import 'package:asset_app/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity check', () {
    expect(true, isTrue);
  });

  test('dashboard widget can be created for admin summary flow', () {
    const profile = UserProfile(
      id: 'admin-1',
      email: 'admin@mantra.test',
      role: AppRole.admin,
      fullName: 'Admin',
      technicianId: null,
    );

    final widget = DashboardPage(
      userProfile: profile,
      canAccessAssets: false,
      canAccessLocations: false,
      canAccessWorkOrders: false,
      canAccessAlerts: false,
      canAccessSettings: false,
      canCreateWorkOrders: false,
      onOpenAssets: () {},
      onOpenLocations: () {},
      onOpenWorkOrders: () {},
      onOpenAlerts: () {},
      onOpenSettings: () {},
      onCreateWorkOrder: () async {},
    );

    expect(widget, isA<DashboardPage>());
  });
}
