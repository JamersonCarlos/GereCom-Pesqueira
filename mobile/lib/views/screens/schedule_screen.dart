import 'main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../models/models.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<UserModel> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await context.read<AuthProvider>().getAllUsers();
      if (mounted) {
        setState(() => _allUsers = users
            .where((u) =>
                u.role == UserRole.GESTOR ||
                u.role == UserRole.SECRETARY ||
                u.role == UserRole.EMPLOYEE)
            .toList());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao buscar colaboradores: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  String _userName(String id) {
    try {
      return _allUsers
          .firstWhere((u) => u.id == id)
          .name; // O prompt exige o nome completo, o atributo "name" já traz a string exata em vez de abreviações.
    } catch (_) {
      return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allShifts = context.watch<ShiftProvider>().shifts;
    final user = auth.currentUser!;

    final isManager = user.role == UserRole.MANAGER ||
        user.role == UserRole.GESTOR ||
        user.role == UserRole.GENERAL_MANAGER;

    // IMPLEMENTAÇÃO DE REGRAS DE ACESSO "ESCALA"
    List<ShiftModel> shifts = [];
    if (isManager) {
      shifts = allShifts;
    } else {
      // Funcionário vê apenas seus serviços atribuídos (ou secretários etc que possam estar nas escalas)
      shifts = allShifts.where((s) => s.employeeIds.contains(user.id)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
        title: const Text('Escalas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              onPressed: () => _showAddShiftSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: shifts.isEmpty
          ? const Center(child: Text('Nenhuma escala encontrada.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shifts.length,
              itemBuilder: (context, i) {
                final shift = shifts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shift.date,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            if (shift.startTime != null ||
                                shift.endTime != null)
                              Text(
                                '${shift.startTime ?? ''}–${shift.endTime ?? ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            if (isManager) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () =>
                                    _showEditShiftSheet(context, shift),
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, shift.id),
                                tooltip: 'Excluir',
                              ),
                            ],
                          ],
                        ),
                        if (shift.observations != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              shift.observations!,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Colaboradores:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                            fontSize: 13,
                          ),
                        ),
                        ...shift.employeeIds.map(
                          (id) => Text(
                            '· ${_userName(id)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String shiftId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Escala'),
        content: const Text('Deseja realmente excluir esta escala?'),
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
    if (confirm == true && context.mounted) {
      await context.read<ShiftProvider>().delete(shiftId);
    }
  }

  void _showAddShiftSheet(BuildContext context) {
    _showShiftSheet(context, null);
  }

  void _showEditShiftSheet(BuildContext context, ShiftModel shift) {
    _showShiftSheet(context, shift);
  }

  void _showShiftSheet(BuildContext context, ShiftModel? existing) {
    final dateCtrl = TextEditingController(text: existing?.date ?? '');
    final startCtrl = TextEditingController(text: existing?.startTime ?? '');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '');
    final obsCtrl = TextEditingController(text: existing?.observations ?? '');
    final selectedIds = List<String>.from(existing?.employeeIds ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Nova Escala' : 'Editar Escala',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Data (AAAA-MM-DD)',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Início (HH:MM)',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Fim (HH:MM)',
                          prefixIcon: Icon(Icons.access_time_filled),
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecionar Colaboradores',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
                ..._allUsers.map(
                  (u) => CheckboxListTile(
                    dense: true,
                    title: Text(u.name),
                    subtitle: Text(u.roleLabel),
                    value: selectedIds.contains(u.id),
                    onChanged: (v) => setModal(() {
                      if (v == true) {
                        selectedIds.add(u.id);
                      } else {
                        selectedIds.remove(u.id);
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      if (dateCtrl.text.isEmpty) return;
                      final shiftCtrl = context.read<ShiftProvider>();
                      final managerId = context.read<AuthProvider>().managerId!;
                      Navigator.pop(ctx);
                      if (existing == null) {
                        await shiftCtrl.createShift(
                          managerId: managerId,
                          date: dateCtrl.text.trim(),
                          startTime: startCtrl.text.trim().isEmpty
                              ? null
                              : startCtrl.text.trim(),
                          endTime: endCtrl.text.trim().isEmpty
                              ? null
                              : endCtrl.text.trim(),
                          employeeIds: selectedIds,
                          observations: obsCtrl.text.trim().isEmpty
                              ? null
                              : obsCtrl.text.trim(),
                        );
                      } else {
                        await shiftCtrl.update(
                          existing.copyWith(
                            date: dateCtrl.text.trim(),
                            startTime: startCtrl.text.trim().isEmpty
                                ? null
                                : startCtrl.text.trim(),
                            endTime: endCtrl.text.trim().isEmpty
                                ? null
                                : endCtrl.text.trim(),
                            employeeIds: selectedIds,
                            observations: obsCtrl.text.trim().isEmpty
                                ? null
                                : obsCtrl.text.trim(),
                          ),
                        );
                      }
                    },
                    child: Text(existing == null ? 'Criar' : 'Salvar'),
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
