import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/planning_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../models/models.dart';
import '../widgets/status_badge.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plannings = context.watch<PlanningController>().plannings;
    final auth = context.watch<AuthController>();
    final user = auth.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejamentos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
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
    final planCtrl = context.read<PlanningController>();
    final notifCtrl = context.read<NotificationController>();

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
              '${planning.department} · ${planning.date} às ${planning.time}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              planning.location.address,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            if (user.role == UserRole.MANAGER &&
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
            if (user.role == UserRole.MANAGER)
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
