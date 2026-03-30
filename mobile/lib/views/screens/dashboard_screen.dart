import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/planning_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/notification_provider.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final plannings = context.watch<PlanningProvider>().plannings;
    final services = context.watch<ServiceProvider>().services;
    final unread = context.watch<NotificationProvider>().unreadCount;
    final user = auth.currentUser!;

    final pending = plannings.where((p) => p.status.name == 'PENDING').length;
    final inProgress = services
        .where((s) => s.status.name == 'IN_PROGRESS')
        .length;
    final completed = services
        .where((s) => s.status.name == 'COMPLETED')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, ${user.name} 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              user.roleLabel,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text(
              'Resumo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatCard(
                  label: 'Planejamentos',
                  value: plannings.length,
                  color: const Color(0xFF2E51A4),
                ),
                StatCard(
                  label: 'Pendentes',
                  value: pending,
                  color: const Color(0xFFF1C62F),
                ),
                StatCard(
                  label: 'Em Andamento',
                  value: inProgress,
                  color: Colors.blue,
                ),
                StatCard(
                  label: 'Concluídos',
                  value: completed,
                  color: Colors.green,
                ),
                StatCard(
                  label: 'Notificações',
                  value: unread,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
