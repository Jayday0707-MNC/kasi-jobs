import 'package:flutter/material.dart';
import 'admin_screen.dart';
import 'alerts_screen.dart';
import 'employer_dashboard.dart';
import 'employer_state.dart';
import 'jobs_screen.dart';
import 'profile_screen.dart';
import 'session.dart';
import 'verification_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  Object? lastUid;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final String? role =
            session.loggedIn ? (session.user?['role'] as String?) : null;
        final Object? uid = session.loggedIn && session.user != null
          ? session.user!['id']
          : null;

        // A different person signed in or out: start from the first tab.
        if (uid != lastUid) {
          lastUid = uid;
          index = 0;
          employerState.reset();
        }

        final pages = <Widget>[];
        final destinations = <NavigationDestination>[];

        void add(Widget page, IconData icon, IconData selected, String label) {
          pages.add(page);
          destinations.add(NavigationDestination(
            icon: Icon(icon),
            selectedIcon: Icon(selected),
            label: label,
          ));
        }

        if (role == 'employer') {
          // Employers never see the public job list or alerts.
          add(
            EmployerDashboard(
              key: ValueKey('dash-$uid'),
              onVerify: () => setState(() => index = 1),
            ),
            Icons.business_center_outlined,
            Icons.business_center,
            'My jobs',
          );
          add(
            VerificationScreen(key: ValueKey('verify-$uid')),
            Icons.verified_user_outlined,
            Icons.verified_user,
            'Verification',
          );
        } else {
          add(const JobsScreen(), Icons.work_outline, Icons.work, 'Jobs');
          if (role == 'admin') {
            add(
              AdminScreen(key: ValueKey('admin-$uid')),
              Icons.admin_panel_settings_outlined,
              Icons.admin_panel_settings,
              'Admin',
            );
          } else {
            add(const AlertsScreen(), Icons.notifications_outlined,
                Icons.notifications, 'Alerts');
          }
        }
        add(const ProfileScreen(), Icons.person_outline, Icons.person,
            'Profile');

        final i = index >= pages.length ? 0 : index;

        return Scaffold(
          body: IndexedStack(index: i, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (x) => setState(() => index = x),
            destinations: destinations,
          ),
        );
      },
    );
  }
}