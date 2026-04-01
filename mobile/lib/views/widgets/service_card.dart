import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/service_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/planning_provider.dart';
import '../../config.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final UserModel user;

  const ServiceCard({super.key, required this.service, required this.user});

  Future<void> _openMap() async {
    final loc = service.locationSnapshot;
    if (loc == null) return;
    final Uri url;
    if (loc.lat != null && loc.lng != null) {
      url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${loc.lat},${loc.lng}');
    } else if (loc.address.isNotEmpty) {
      url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc.address)}');
    } else {
      return;
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  bool get _isManager =>
      user.role == UserRole.GESTOR ||
      user.role == UserRole.MANAGER ||
      user.role == UserRole.GENERAL_MANAGER ||
      user.role == UserRole.SECRETARY;

  bool get _isTeamMember => service.teamIds.contains(user.id);

  Future<void> _executeService(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como Executado?'),
        content: Text(
            'Confirma que o serviço "${service.serviceTypeSnapshot ?? 'Serviço'}" foi concluído e aguarda aprovação do gestor?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final svcCtrl = context.read<ServiceProvider>();
    final notifCtrl = context.read<NotificationProvider>();
    final planningCtrl = context.read<PlanningProvider>();
    try {
      await svcCtrl.updateStatus(
        service.id,
        ServiceStatus.WAITING_APPROVAL,
        user.id,
        service.managerId,
        notifCtrl,
        planningCtrl,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar status.')),
        );
      }
    }
  }

  Future<void> _confirmCompletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Conclusão?'),
        content: Text(
            'Confirma a conclusão do serviço "${service.serviceTypeSnapshot ?? 'Serviço'}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final svcCtrl = context.read<ServiceProvider>();
    final notifCtrl = context.read<NotificationProvider>();
    final planningCtrl = context.read<PlanningProvider>();
    try {
      await svcCtrl.confirmCompletion(
        service.id,
        user.id,
        notifCtrl,
        planningCtrl,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao confirmar conclusão.')),
        );
      }
    }
  }

  Future<void> _deleteService(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Serviço?'),
        content: Text(
            'Tem certeza que deseja remover "${service.serviceTypeSnapshot ?? 'Serviço'}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<ServiceProvider>().delete(service.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao remover serviço.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canExecute = !_isManager &&
        _isTeamMember &&
        service.status == ServiceStatus.IN_PROGRESS;
    final bool canConfirm =
        _isManager && service.status == ServiceStatus.WAITING_APPROVAL;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service.serviceTypeSnapshot ?? 'Serviço s/ Tipo',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        _statusLabel(service.status),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: _statusColor(service.status),
                    ),
                    if (_isManager)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _deleteService(context),
                        tooltip: 'Remover serviço',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (service.locationSnapshot != null)
              InkWell(
                onTap: _openMap,
                child: Row(
                  children: [
                    Icon(
                      service.locationSnapshot!.lat != null
                          ? Icons.gps_fixed
                          : Icons.location_on,
                      color: Colors.blue,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        service.locationSnapshot!.lat != null &&
                                service.locationSnapshot!.address.isEmpty
                            ? '${service.locationSnapshot!.lat!.toStringAsFixed(5)}, ${service.locationSnapshot!.lng!.toStringAsFixed(5)}'
                            : service.locationSnapshot!.address,
                        style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                    if (service.locationSnapshot!.lat != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified_outlined,
                            color: Colors.green, size: 14),
                      ),
                  ],
                ),
              ),

            // ── Static Map thumbnail ────────────────────────────────────────
            if (service.locationSnapshot?.lat != null &&
                service.locationSnapshot?.lng != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openMap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    'https://maps.googleapis.com/maps/api/staticmap'
                    '?center=${service.locationSnapshot!.lat},${service.locationSnapshot!.lng}'
                    '&zoom=15'
                    '&size=600x180'
                    '&maptype=roadmap'
                    '&markers=color:red%7C${service.locationSnapshot!.lat},${service.locationSnapshot!.lng}'
                    '&key=$kGoogleMapsApiKey',
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            height: 130,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
                'Data: ${service.dateSnapshot ?? '-'} | Hora: ${service.timeSnapshot ?? '-'}'),
            const SizedBox(height: 4),
            Text('Departamento: ${service.departmentSnapshot ?? '-'}'),
            if (service.teamIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Operadores alocados: ${service.teamIds.length}',
                  style: const TextStyle(color: Colors.grey)),
            ],
            if (canExecute) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _executeService(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como Executado'),
                ),
              ),
            ],
            if (canConfirm) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _confirmCompletion(context),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Confirmar Conclusão'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(ServiceStatus s) {
    const labels = {
      ServiceStatus.PENDING: 'Pendente',
      ServiceStatus.APPROVED: 'Aprovado',
      ServiceStatus.REJECTED: 'Rejeitado',
      ServiceStatus.IN_PROGRESS: 'Em Andamento',
      ServiceStatus.COMPLETED: 'Concluído',
      ServiceStatus.CANCELLED: 'Cancelado',
      ServiceStatus.RESCHEDULED: 'Reagendado',
      ServiceStatus.WAITING_APPROVAL: 'Aguardando Aprovação',
    };
    return labels[s] ?? s.name;
  }

  Color _statusColor(ServiceStatus s) {
    switch (s) {
      case ServiceStatus.IN_PROGRESS:
        return Colors.blue.shade100;
      case ServiceStatus.WAITING_APPROVAL:
        return Colors.orange.shade100;
      case ServiceStatus.COMPLETED:
        return Colors.green.shade100;
      case ServiceStatus.CANCELLED:
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}
