import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/planning_provider.dart';
import '../../providers/service_provider.dart';
import '../../models/models.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plannings = context.watch<PlanningProvider>().plannings;
    final services = context.watch<ServiceProvider>().services;

    final byType = <String, int>{};
    for (final p in plannings) {
      byType[p.serviceType] = (byType[p.serviceType] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Planejamentos'),
            _row('Total', plannings.length),
            _row(
              'Aprovados',
              plannings.where((p) => p.status == ServiceStatus.APPROVED).length,
              color: Colors.green,
            ),
            _row(
              'Rejeitados',
              plannings.where((p) => p.status == ServiceStatus.REJECTED).length,
              color: Colors.red,
            ),
            _row(
              'Pendentes',
              plannings.where((p) => p.status == ServiceStatus.PENDING).length,
              color: const Color(0xFFF1C62F),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Serviços'),
            _row('Total', services.length),
            _row(
              'Concluídos',
              services.where((s) => s.status == ServiceStatus.COMPLETED).length,
              color: Colors.green,
            ),
            _row(
              'Em Andamento',
              services
                  .where((s) => s.status == ServiceStatus.IN_PROGRESS)
                  .length,
              color: Colors.blue,
            ),
            _row(
              'Cancelados',
              services.where((s) => s.status == ServiceStatus.CANCELLED).length,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            _sectionTitle('Por Tipo de Serviço'),
            ...(byType.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .map((e) => _row(e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E51A4),
          ),
        ),
      );

  Widget _row(String label, int value, {Color? color}) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.blueGrey)),
              Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
}
