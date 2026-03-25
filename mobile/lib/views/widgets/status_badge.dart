import 'package:flutter/material.dart';
import '../../models/planning_model.dart';

final _statusColors = <ServiceStatus, Color>{
  ServiceStatus.PENDING: const Color(0xFFF1C62F),
  ServiceStatus.APPROVED: Colors.green,
  ServiceStatus.REJECTED: Colors.red,
  ServiceStatus.IN_PROGRESS: Colors.blue,
  ServiceStatus.COMPLETED: Colors.teal,
  ServiceStatus.CANCELLED: Colors.grey,
  ServiceStatus.RESCHEDULED: Colors.purple,
  ServiceStatus.WAITING_APPROVAL: Colors.orange,
};

final _statusLabels = <ServiceStatus, String>{
  ServiceStatus.PENDING: 'Pendente',
  ServiceStatus.APPROVED: 'Aprovado',
  ServiceStatus.REJECTED: 'Rejeitado',
  ServiceStatus.IN_PROGRESS: 'Em Andamento',
  ServiceStatus.COMPLETED: 'Concluído',
  ServiceStatus.CANCELLED: 'Cancelado',
  ServiceStatus.RESCHEDULED: 'Reagendado',
  ServiceStatus.WAITING_APPROVAL: 'Aguard. Aprovação',
};

class StatusBadge extends StatelessWidget {
  final ServiceStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[status] ?? Colors.grey;
    final label = _statusLabels[status] ?? status.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
