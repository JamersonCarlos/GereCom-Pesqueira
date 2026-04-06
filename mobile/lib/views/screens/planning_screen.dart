import 'main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/planning_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/models.dart';
import '../widgets/status_badge.dart';
import '../widgets/planning_modal.dart';
import 'package:url_launcher/url_launcher.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final allPlannings = context.watch<PlanningProvider>().plannings;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final canCreate = user.role == UserRole.GESTOR ||
        user.role == UserRole.SECRETARY ||
        user.role == UserRole.MANAGER ||
        user.role == UserRole.GENERAL_MANAGER;

    List<PlanningModel> plannings = [];
    if (user.role == UserRole.MANAGER ||
        user.role == UserRole.GESTOR ||
        user.role == UserRole.GENERAL_MANAGER) {
      plannings = allPlannings;
    } else if (user.role == UserRole.SECRETARY) {
      plannings = allPlannings
          .where((p) =>
              p.secretaryId == user.id || p.responsibleSecretaryId == user.id)
          .toList();
    } else {
      // Employees nominally don't deal with plannings, but just in case they are assigned to one as responsible
      plannings = allPlannings
          .where((p) => p.responsibleEmployeeIds.contains(user.id))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
        title: const Text('Planejamentos'),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              heroTag: 'fab_planning',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const PlanningModal(),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: plannings.isEmpty
          ? const Center(child: Text('Nenhum planejamento encontrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plannings.length,
              itemBuilder: (context, i) {
                final p = plannings[i];
                return _PlanningCard(planning: p, user: user);
              },
            ),
    );
  }
}

class _PlanningCard extends StatelessWidget {
  final PlanningModel planning;
  final UserModel user;

  const _PlanningCard({required this.planning, required this.user});

  @override
  Widget build(BuildContext context) {
    final planCtrl = context.read<PlanningProvider>();
    final notifCtrl = context.read<NotificationProvider>();

    Future<void> approve() async {
      await planCtrl.updateStatus(
        planning.id,
        ServiceStatus.APPROVED,
        notifCtrl: notifCtrl,
      );
    }

    Future<void> reject() async {
      final reason = await _promptReason(context, 'Motivo da rejeição');
      if (reason != null && reason.isNotEmpty) {
        await planCtrl.updateStatus(
          planning.id,
          ServiceStatus.REJECTED,
          rejectionReason: reason,
          notifCtrl: notifCtrl,
        );
      }
    }

    Future<void> delete() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Excluir Planejamento'),
          content: const Text('Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm == true) await planCtrl.delete(planning.id);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    planning.serviceType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                StatusBadge(status: planning.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${planning.department ?? '-'} · ${planning.date}'
              '${planning.time != null ? ' às ${planning.time}' : ''}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (planning.location != null)
              GestureDetector(
                onTap: () async {
                  final loc = planning.location!;
                  if (loc.lat != null && loc.lng != null) {
                    final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${loc.lat},${loc.lng}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  } else {
                    final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc.address)}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          planning.location!.address,
                          style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 13,
                              decoration: TextDecoration.underline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (planning.urgency == UrgencyLevel.URGENT)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '⚠ Urgente',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            if ((user.role == UserRole.MANAGER ||
                    user.role == UserRole.GESTOR ||
                    user.role == UserRole.GENERAL_MANAGER) &&
                planning.status == ServiceStatus.PENDING) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: approve,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Aprovar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: reject,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Rejeitar'),
                    ),
                  ),
                ],
              ),
            ],
            if ((user.role == UserRole.MANAGER ||
                user.role == UserRole.GESTOR ||
                user.role == UserRole.GENERAL_MANAGER))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: delete,
                  child: const Text(
                    'Excluir',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptReason(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(hintText: 'Descreva o motivo...'),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
}
