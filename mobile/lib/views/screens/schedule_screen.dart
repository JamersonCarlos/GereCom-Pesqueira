import 'main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../models/models.dart';

// -- Internal config per day ------------------------------------------------

class _DayConfig {
  List<String> employeeIds;
  String startTime;
  String endTime;
  String observations;

  _DayConfig({
    List<String>? employeeIds,
    this.startTime = '',
    this.endTime = '',
    this.observations = '',
  }) : employeeIds = employeeIds ?? [];
}

// -- Main screen ------------------------------------------------------------

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
        setState(() => _allUsers = users);
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

  Map<String, List<ShiftModel>> _groupByMonth(List<ShiftModel> shifts) {
    final map = <String, List<ShiftModel>>{};
    for (final s in shifts) {
      final key = s.date.substring(0, 7);
      map.putIfAbsent(key, () => []).add(s);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _monthLabel(String key) {
    final dt = DateTime.parse('$key-01');
    final raw = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(dt);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  Future<void> _pickMonthAndCreate(BuildContext context) async {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Selecionar MÃªs da Escala'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedMonth,
                  decoration: const InputDecoration(labelText: 'MÃªs'),
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              DateFormat('MMMM', 'pt_BR')
                                  .format(DateTime(2000, m)),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setDialog(() => selectedMonth = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  items: List.generate(5, (i) => DateTime.now().year - 1 + i)
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ))
                      .toList(),
                  onChanged: (v) => setDialog(() => selectedYear = v!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MonthBuilderScreen(
            year: selectedYear,
            month: selectedMonth,
            allUsers: _allUsers,
          ),
        ),
      );
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

    final isSecretary = user.role == UserRole.SECRETARY;

    final shifts = isManager
        ? allShifts
        : isSecretary
            ? allShifts
            : allShifts.where((s) => s.employeeIds.contains(user.id)).toList();

    final grouped = _groupByMonth(shifts);

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
          ? FloatingActionButton.extended(
              onPressed: () => _pickMonthAndCreate(context),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Nova Escala do MÃªs'),
            )
          : null,
      body: grouped.isEmpty
          ? const Center(child: Text('Nenhuma escala encontrada.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, i) {
                final key = grouped.keys.elementAt(i);
                final monthShifts = grouped[key]!
                  ..sort((a, b) => a.date.compareTo(b.date));
                return _MonthCard(
                  label: _monthLabel(key),
                  shifts: monthShifts,
                  allUsers: _allUsers,
                  isManager: isManager,
                  isSecretary: isSecretary,
                );
              },
            ),
    );
  }
}

// -- Month summary card -----------------------------------------------------

class _MonthCard extends StatelessWidget {
  final String label;
  final List<ShiftModel> shifts;
  final List<UserModel> allUsers;
  final bool isManager;
  final bool isSecretary;

  const _MonthCard({
    required this.label,
    required this.shifts,
    required this.allUsers,
    required this.isManager,
    this.isSecretary = false,
  });

  String _userName(String id) {
    try {
      return allUsers.firstWhere((u) => u.id == id).name;
    } catch (_) {
      return id;
    }
  }

  String _managerName(String managerId) {
    try {
      return allUsers.firstWhere((u) => u.id == managerId).name;
    } catch (_) {
      return 'Gestor';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSecretary) {
      final Map<String, List<ShiftModel>> byManager = {};
      for (final s in shifts) {
        byManager.putIfAbsent(s.managerId, () => []).add(s);
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${shifts.length} dia${shifts.length != 1 ? 's' : ''} escalado${shifts.length != 1 ? 's' : ''}',
          ),
          children: byManager.entries.map((entry) {
            final mName = _managerName(entry.key);
            final mShifts = entry.value
              ..sort((a, b) => a.date.compareTo(b.date));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.amber.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Gestor: $mName',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                ...mShifts.map((shift) {
                  final dt = DateTime.tryParse(shift.date);
                  final dayFmt = dt != null
                      ? DateFormat("dd/MM - EEEE", 'pt_BR').format(dt)
                      : shift.date;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.today_outlined, size: 20),
                    title: Text(dayFmt),
                    subtitle: shift.employeeIds.isEmpty
                        ? const Text('Sem colaboradores',
                            style: TextStyle(color: Colors.grey))
                        : Text(
                            shift.employeeIds.map(_userName).join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${shifts.length} dia${shifts.length != 1 ? 's' : ''} escalado${shifts.length != 1 ? 's' : ''}',
        ),
        children: shifts.map((shift) {
          final dt = DateTime.tryParse(shift.date);
          final dayFmt = dt != null
              ? DateFormat("dd/MM - EEEE", 'pt_BR').format(dt)
              : shift.date;

          return ListTile(
            dense: true,
            leading: const Icon(Icons.today_outlined, size: 20),
            title: Text(dayFmt),
            subtitle: shift.employeeIds.isEmpty
                ? const Text('Sem colaboradores',
                    style: TextStyle(color: Colors.grey))
                : Text(
                    shift.employeeIds.map(_userName).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: isManager
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shift.startTime != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${shift.startTime} - ${shift.endTime ?? ''}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blueGrey),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Excluir dia'),
                              content: Text('Remover escala de $dayFmt?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Excluir',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context
                                .read<ShiftProvider>()
                                .delete(shift.id);
                          }
                        },
                      ),
                    ],
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }
}

// -- Monthly builder screen -------------------------------------------------

class _MonthBuilderScreen extends StatefulWidget {
  final int year;
  final int month;
  final List<UserModel> allUsers;

  const _MonthBuilderScreen({
    required this.year,
    required this.month,
    required this.allUsers,
  });

  @override
  State<_MonthBuilderScreen> createState() => _MonthBuilderScreenState();
}

class _MonthBuilderScreenState extends State<_MonthBuilderScreen> {
  final Map<String, _DayConfig> _configs = {};
  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final lastDay = DateTime(widget.year, widget.month + 1, 0).day;
    _days = List.generate(
      lastDay,
      (i) => DateTime(widget.year, widget.month, i + 1),
    );
  }

  String _dateKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  Future<void> _editDay(DateTime day) async {
    final key = _dateKey(day);
    final existing = _configs[key];

    List<String> selectedIds = List.from(existing?.employeeIds ?? []);
    final startCtrl =
        TextEditingController(text: existing?.startTime ?? '00:01');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '23:59');
    final obsCtrl = TextEditingController(text: existing?.observations ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final rawTitle =
              DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(day);
          final dayTitle = rawTitle[0].toUpperCase() + rawTitle.substring(1);

          return Padding(
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
                    dayTitle,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final parts = startCtrl.text.split(':');
                            final init = parts.length == 2
                                ? TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 0,
                                    minute: int.tryParse(parts[1]) ?? 1)
                                : const TimeOfDay(hour: 0, minute: 1);
                            final picked = await showTimePicker(
                                context: ctx, initialTime: init);
                            if (picked != null) {
                              setSheet(() => startCtrl.text =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: startCtrl,
                              decoration: const InputDecoration(
                                labelText: 'InÃ­cio',
                                prefixIcon: Icon(Icons.access_time),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final parts = endCtrl.text.split(':');
                            final init = parts.length == 2
                                ? TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 23,
                                    minute: int.tryParse(parts[1]) ?? 59)
                                : const TimeOfDay(hour: 23, minute: 59);
                            final picked = await showTimePicker(
                                context: ctx, initialTime: init);
                            if (picked != null) {
                              setSheet(() => endCtrl.text =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: endCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Fim',
                                prefixIcon: Icon(Icons.access_time_filled),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ObservaÃ§Ãµes',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Colaboradores',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.blueGrey),
                  ),
                  ...widget.allUsers.map((u) => CheckboxListTile(
                        dense: true,
                        title: Text(u.name),
                        subtitle: Text(u.roleLabel),
                        value: selectedIds.contains(u.id),
                        onChanged: (v) => setSheet(() {
                          if (v == true) {
                            selectedIds.add(u.id);
                          } else {
                            selectedIds.remove(u.id);
                          }
                        }),
                      )),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (existing != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _configs.remove(key));
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.clear, color: Colors.red),
                            label: const Text('Limpar dia',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      if (existing != null) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _configs[key] = _DayConfig(
                                employeeIds: List.from(selectedIds),
                                startTime: startCtrl.text,
                                endTime: endCtrl.text,
                                observations: obsCtrl.text,
                              );
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Confirmar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveAll() async {
    final configuredDays = _configs.entries
        .where((e) => e.value.employeeIds.isNotEmpty)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (configuredDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configure ao menos um dia com colaboradores.')),
      );
      return;
    }

    final shiftCtrl = context.read<ShiftProvider>();
    final managerId = context.read<AuthProvider>().managerId!;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final entry in configuredDays) {
        await shiftCtrl.createShift(
          managerId: managerId,
          date: entry.key,
          startTime:
              entry.value.startTime.isEmpty ? null : entry.value.startTime,
          endTime: entry.value.endTime.isEmpty ? null : entry.value.endTime,
          employeeIds: entry.value.employeeIds,
          observations: entry.value.observations.isEmpty
              ? null
              : entry.value.observations,
        );
      }
      if (mounted) {
        Navigator.pop(context); // close loading
        Navigator.pop(context); // back to list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${configuredDays.length} dia${configuredDays.length != 1 ? 's' : ''} salvo${configuredDays.length != 1 ? 's' : ''} com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawLabel = DateFormat("MMMM 'de' yyyy", 'pt_BR')
        .format(DateTime(widget.year, widget.month));
    final monthLabel = rawLabel[0].toUpperCase() + rawLabel.substring(1);
    final configured =
        _configs.values.where((c) => c.employeeIds.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Escala ï¿½ $monthLabel'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saveAll,
            icon: const Icon(Icons.save_outlined),
            label: Text(configured > 0
                ? 'Salvar ($configured dia${configured != 1 ? 's' : ''})'
                : 'Salvar Escala'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _days.length,
        itemBuilder: (context, i) {
          final day = _days[i];
          final key = _dateKey(day);
          final config = _configs[key];
          final hasConfig = config != null && config.employeeIds.isNotEmpty;
          final isWeekend = day.weekday == DateTime.saturday ||
              day.weekday == DateTime.sunday;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: hasConfig
                  ? Theme.of(context).colorScheme.primary
                  : isWeekend
                      ? Colors.orange.shade100
                      : Colors.grey.shade200,
              child: Text(
                day.day.toString(),
                style: TextStyle(
                  color: hasConfig
                      ? Colors.white
                      : isWeekend
                          ? Colors.orange.shade800
                          : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            title: Text(
              DateFormat('EEEE', 'pt_BR').format(day),
              style: TextStyle(
                fontWeight: hasConfig ? FontWeight.w600 : FontWeight.normal,
                color: isWeekend && !hasConfig ? Colors.orange.shade700 : null,
              ),
            ),
            subtitle: hasConfig
                ? Text(
                    config.employeeIds.map((id) {
                      try {
                        return widget.allUsers
                            .firstWhere((u) => u.id == id)
                            .name;
                      } catch (_) {
                        return id;
                      }
                    }).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.blueGrey),
                  )
                : Text(
                    'Toque para configurar',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
            trailing: hasConfig
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (config.startTime.isNotEmpty)
                        Text(
                          '${config.startTime}ï¿½${config.endTime}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blueGrey),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  )
                : Icon(Icons.add_circle_outline, color: Colors.grey.shade400),
            onTap: () => _editDay(day),
          );
        },
      ),
    );
  }
}
