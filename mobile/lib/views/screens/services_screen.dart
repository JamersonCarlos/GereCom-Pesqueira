import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/planning_provider.dart';
import '../../models/models.dart';
import '../widgets/status_badge.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.watch<ServiceProvider>().services;
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: services.isEmpty
          ? const Center(child: Text('Nenhum serviço encontrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              itemBuilder: (context, i) =>
                  _ServiceCard(service: services[i], user: user),
            ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final UserModel user;

  const _ServiceCard({required this.service, required this.user});

  @override
  Widget build(BuildContext context) {
    final svcCtrl = context.read<ServiceProvider>();
    final notifCtrl = context.read<NotificationProvider>();
    final planCtrl = context.read<PlanningProvider>();
    final managerId = context.read<AuthProvider>().managerId!;

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
                    service.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                StatusBadge(status: service.status),
              ],
            ),
            if (service.dateSnapshot != null)
              Text(
                '${service.dateSnapshot} às ${service.timeSnapshot ?? ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            if (service.locationSnapshot != null)
              Text(
                service.locationSnapshot!.address,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (service.status == ServiceStatus.WAITING_APPROVAL &&
                user.role == UserRole.MANAGER) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => svcCtrl.confirmCompletion(
                        service.id,
                        managerId,
                        notifCtrl,
                        planCtrl,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => svcCtrl.requestReview(
                        service.id,
                        managerId,
                        notifCtrl,
                        planCtrl,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Revisar'),
                    ),
                  ),
                ],
              ),
            ],
            if (service.status == ServiceStatus.IN_PROGRESS)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton(
                  onPressed: () => _showStatusOptions(
                    context,
                    svcCtrl,
                    notifCtrl,
                    planCtrl,
                    managerId,
                  ),
                  child: const Text('Atualizar Status'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showStatusOptions(
    BuildContext context,
    ServiceProvider svcCtrl,
    NotificationProvider notifCtrl,
    PlanningProvider planCtrl,
    String managerId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.grey),
              title: const Text('Cancelar Serviço'),
              onTap: () async {
                Navigator.pop(context);
                final reason = await _promptReason(
                  context,
                  'Motivo do cancelamento',
                );
                if (reason != null && reason.isNotEmpty && context.mounted) {
                  await svcCtrl.updateStatus(
                    service.id,
                    ServiceStatus.CANCELLED,
                    user.id,
                    managerId,
                    notifCtrl,
                    planCtrl,
                    reason: reason,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat, color: Colors.purple),
              title: const Text('Reagendar'),
              onTap: () async {
                Navigator.pop(context);
                final reason = await _promptReason(
                  context,
                  'Motivo do reagendamento',
                );
                if (reason != null && reason.isNotEmpty && context.mounted) {
                  await svcCtrl.updateStatus(
                    service.id,
                    ServiceStatus.RESCHEDULED,
                    user.id,
                    managerId,
                    notifCtrl,
                    planCtrl,
                    reason: reason,
                  );
                }
              },
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
