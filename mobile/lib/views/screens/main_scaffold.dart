import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/planning_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/shift_provider.dart';
import 'dashboard_screen.dart';
import 'planning_screen.dart';
import 'services_screen.dart';
import 'schedule_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'team_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final managerId = auth.managerId;
    if (managerId == null) return;
    final userId = auth.currentUser!.id;

    await Future.wait([
      context.read<PlanningProvider>().loadForManager(managerId),
      context.read<ServiceProvider>().loadForManager(managerId),
      context.read<NotificationProvider>().loadForUser(userId, managerId),
      context.read<ShiftProvider>().loadForManager(managerId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final notifCtrl = context.watch<NotificationProvider>();
    final unread = notifCtrl.unreadCount;

    final screens = <Widget>[
      const DashboardScreen(),
      const PlanningScreen(),
      const ServicesScreen(),
      const ScheduleScreen(),
      const ReportsScreen(),
      const TeamScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex > 5 ? _selectedIndex : _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Planejamentos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Serviços',
          ),
          const NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Escalas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Relatórios',
          ),
          const NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Equipe',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notificações',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
