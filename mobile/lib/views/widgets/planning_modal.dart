import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/planning_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/models.dart';
import 'package:uuid/uuid.dart';

class PlanningModal extends StatefulWidget {
  const PlanningModal({super.key});

  @override
  State<PlanningModal> createState() => _PlanningModalState();
}

class _PlanningModalState extends State<PlanningModal> {
  final _serviceTypeCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(); // AAAA-MM-DD
  final _addressCtrl = TextEditingController(); // Rua XYZ

  UrgencyLevel _urgency = UrgencyLevel.MEDIUM;
  PlanningPeriod _period = PlanningPeriod.UNPLANNED;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Novo Planejamento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serviceTypeCtrl,
              decoration: const InputDecoration(labelText: 'Tipo de Serviço (Ex: Poda, Iluminação)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _departmentCtrl,
              decoration: const InputDecoration(labelText: 'Bairro/Departamento'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Endereço Completo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dateCtrl,
              decoration: const InputDecoration(labelText: 'Data Desejada (AAAA-MM-DD)', hintText: '2025-05-20'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<UrgencyLevel>(
                    value: _urgency,
                    decoration: const InputDecoration(labelText: 'Urgência'),
                    items: UrgencyLevel.values.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
                    onChanged: (v) => setState(() => _urgency = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<PlanningPeriod>(
                    value: _period,
                    decoration: const InputDecoration(labelText: 'Período'),
                    items: PlanningPeriod.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (v) => setState(() => _period = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  if (_serviceTypeCtrl.text.isEmpty || _dateCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha serviço, data e endereço')));
                     return;
                  }

                  final auth = context.read<AuthProvider>();
                  final planCtrl = context.read<PlanningProvider>();
                  final notifCtrl = context.read<NotificationProvider>();
                  
                  final user = auth.currentUser!;
                  final managerId = auth.managerId!;

                  final plan = PlanningModel(
                    id: const Uuid().v4(),
                    managerId: managerId,
                    secretaryId: user.role == UserRole.SECRETARY ? user.id : user.managerId,
                    department: _departmentCtrl.text.trim(),
                    serviceType: _serviceTypeCtrl.text.trim(),
                    date: _dateCtrl.text.trim(),
                    location: PlanningLocation(address: _addressCtrl.text.trim()),
                    urgency: _urgency,
                    period: _period,
                    status: ServiceStatus.PENDING,
                    createdAt: DateTime.now().toIso8601String()
                  );

                  await planCtrl.add(plan, notifCtrl);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Salvar Planejamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
