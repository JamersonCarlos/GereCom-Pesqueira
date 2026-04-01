import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
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

final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

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
    final isSecretary = auth.currentUser!.role == UserRole.SECRETARY;

    await Future.wait([
      context.read<PlanningProvider>().loadForManager(managerId),
      context.read<ServiceProvider>().loadForManager(managerId),
      context.read<NotificationProvider>().loadForUser(userId, managerId),
      if (isSecretary)
        context.read<ShiftProvider>().loadAll()
      else
        context.read<ShiftProvider>().loadForManager(managerId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final notifCtrl = context.watch<NotificationProvider>();
    final unread = notifCtrl.unreadCount;

    final name = user?.name ?? 'Usuário';
    final role = user?.role.name ?? '';

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
      key: rootScaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(name),
              accountEmail: Text(role),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person, size: 40),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Planejamentos'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('Serviços'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Escalas'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Relatórios'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Equipe'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications),
              ),
              title: const Text('Notificações'),
              selected: _selectedIndex == 6,
              onTap: () {
                setState(() => _selectedIndex = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              selected: _selectedIndex == 7,
              onTap: () {
                setState(() => _selectedIndex = 7);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final navigator = Navigator.of(context);
                await auth.logout();
                // Destrói todas as rotas ativas (ex: modais, dialogs abertos)
                // para a navegação voltar ao "home:" ditado pelo app.dart
                navigator.popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex > 3 ? 0 : _selectedIndex,
        onDestinationSelected: (i) {
          setState(() {
            if (i == 0) _selectedIndex = 0; // Dashboard
            if (i == 1) _selectedIndex = 1; // Planejamentos
            if (i == 2) _selectedIndex = 2; // Serviços
            if (i == 3) _selectedIndex = 3; // Escalas
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Planejamentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Serviços',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Escalas',
          ),
        ],
      ),
    );
  }
}
