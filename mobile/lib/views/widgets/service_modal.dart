import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/planning_provider.dart'; // importando pra reusar se for um serviço planejado
import '../../models/models.dart';
import 'package:uuid/uuid.dart';

class ServiceModal extends StatefulWidget {
  const ServiceModal({super.key});

  @override
  State<ServiceModal> createState() => _ServiceModalState();
}

class _ServiceModalState extends State<ServiceModal> {
  final _serviceTypeCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(); // AAAA-MM-DD
  final _timeCtrl = TextEditingController(); // HH:MM
  final _addressCtrl = TextEditingController();

  List<String> _selectedTeamIds = [];
  List<UserModel> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await context.read<AuthProvider>().getAllUsers();
    if (mounted)
      setState(() => _allUsers = users
          .where((u) =>
              u.role == UserRole.GESTOR ||
              u.role == UserRole.SECRETARY ||
              u.role == UserRole.EMPLOYEE)
          .toList());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Criar Novo Serviço em Andamento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serviceTypeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Descrição/Nome do Serviço'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _departmentCtrl,
              decoration:
                  const InputDecoration(labelText: 'Departamento Destino'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                  labelText: 'Endereço GPS (Obrigatório)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Data (AAAA-MM-DD)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Hora (HH:MM)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Designar Operadores (Equipe)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.blueGrey),
            ),
            ..._allUsers.map((u) => CheckboxListTile(
                  dense: true,
                  title: Text(u.name),
                  value: _selectedTeamIds.contains(u.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true)
                        _selectedTeamIds.add(u.id);
                      else
                        _selectedTeamIds.remove(u.id);
                    });
                  },
                )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  if (_serviceTypeCtrl.text.isEmpty ||
                      _addressCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Preencha os campos vitais!')));
                    return;
                  }

                  final auth = context.read<AuthProvider>();
                  final svcCtrl = context.read<ServiceProvider>();

                  final user = auth.currentUser!;
                  final managerId = auth.managerId!;

                  final serviceToInsert = {
                    "id": const Uuid().v4(),
                    "managerId": managerId,
                    "createdById": user.id,
                    "teamIds": _selectedTeamIds,
                    "status": ServiceStatus.IN_PROGRESS.name,
                    "createdAt": DateTime.now().toIso8601String(),
                    "serviceTypeSnapshot": _serviceTypeCtrl.text.trim(),
                    "departmentSnapshot": _departmentCtrl.text.trim(),
                    "dateSnapshot": _dateCtrl.text.trim(),
                    "timeSnapshot": _timeCtrl.text.trim(),
                    "locationSnapshot": {"address": _addressCtrl.text.trim()}
                  };

                  await svcCtrl.createServiceDirectly(serviceToInsert);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Designar Serviço'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
