import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/planning_provider.dart';
import '../../providers/shift_provider.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'planning_screen.dart';
import 'services_screen.dart';
import 'schedule_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'team_screen.dart';

final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

const _primary = Color(0xFF2E51A4);
const _accent = Color(0xFFF1C62F);

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
      context.read<NotificationProvider>().loadForUser(userId, managerId),
      if (isSecretary)
        context.read<ShiftProvider>().loadAll()
      else
        context.read<ShiftProvider>().loadForManager(managerId),
    ]);
  }

  void _navigate(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final unread = context.watch<NotificationProvider>().unreadCount;

    final name = user?.name ?? 'Usuário';
    final roleLabel = user?.roleLabel ?? '';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'U';

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
      drawer: _buildDrawer(context, auth, name, roleLabel, initials, unread),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(unread),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthProvider auth,
    String name,
    String roleLabel,
    String initials,
    int unread,
  ) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Cabeçalho do drawer ───────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A3478), _primary],
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A3478),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Itens de navegação ────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: _selectedIndex == 0,
                  onTap: () => _navigate(0),
                ),
                _DrawerItem(
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month_rounded,
                  label: 'Planejamentos',
                  selected: _selectedIndex == 1,
                  onTap: () => _navigate(1),
                ),
                _DrawerItem(
                  icon: Icons.work_outline_rounded,
                  activeIcon: Icons.work_rounded,
                  label: 'Serviços',
                  selected: _selectedIndex == 2,
                  onTap: () => _navigate(2),
                ),
                _DrawerItem(
                  icon: Icons.schedule_outlined,
                  activeIcon: Icons.schedule_rounded,
                  label: 'Escalas',
                  selected: _selectedIndex == 3,
                  onTap: () => _navigate(3),
                ),
                _DrawerItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Relatórios',
                  selected: _selectedIndex == 4,
                  onTap: () => _navigate(4),
                ),
                _DrawerItem(
                  icon: Icons.group_outlined,
                  activeIcon: Icons.group_rounded,
                  label: 'Equipe',
                  selected: _selectedIndex == 5,
                  onTap: () => _navigate(5),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Divider(height: 1),
                ),
                _DrawerItem(
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications_rounded,
                  label: 'Notificações',
                  badge: unread,
                  selected: _selectedIndex == 6,
                  onTap: () => _navigate(6),
                ),
                _DrawerItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Perfil',
                  selected: _selectedIndex == 7,
                  onTap: () => _navigate(7),
                ),
              ],
            ),
          ),

          // ── Rodapé ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              top: 4,
            ),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.logout_rounded,
                        color: Colors.red.shade600, size: 20),
                  ),
                  title: Text(
                    'Sair',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () async {
                    Navigator.pop(context); // close drawer
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(int unread) {
    return NavigationBar(
      selectedIndex: _selectedIndex > 3 ? 0 : _selectedIndex,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: _primary.withOpacity(0.12),
      onDestinationSelected: (i) {
        setState(() => _selectedIndex = i);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded, color: _primary),
          label: 'Dashboard',
        ),
        const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded, color: _primary),
          label: 'Planos',
        ),
        const NavigationDestination(
          icon: Icon(Icons.work_outline_rounded),
          selectedIcon: Icon(Icons.work_rounded, color: _primary),
          label: 'Serviços',
        ),
        const NavigationDestination(
          icon: Icon(Icons.schedule_outlined),
          selectedIcon: Icon(Icons.schedule_rounded, color: _primary),
          label: 'Escalas',
        ),
      ],
    );
  }
}

// ── Drawer Item ──────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? _primary.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected ? _primary : Colors.grey.shade600,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? _primary : Colors.grey.shade800,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
