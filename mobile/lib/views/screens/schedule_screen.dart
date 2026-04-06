import 'main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

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

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final shiftCtrl = context.read<ShiftProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final isSecretary = user.role == UserRole.SECRETARY;
    await Future.wait([
      _loadUsers(),
      if (isSecretary)
        shiftCtrl.loadAll()
      else
        shiftCtrl.loadForManager(user.id),
    ]);
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
    final currentUser = context.read<AuthProvider>().currentUser;

    final assignableUsers = _allUsers
        .where((member) =>
            currentUser != null &&
            member.role == UserRole.EMPLOYEE &&
            member.managerId == currentUser.id)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Selecionar MÃªs da Escala'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
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
                  initialValue: selectedYear,
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
            assignableUsers: assignableUsers,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allShifts = context.watch<ShiftProvider>().shifts;
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isManager = user.role == UserRole.MANAGER ||
        user.role == UserRole.GESTOR ||
        user.role == UserRole.GENERAL_MANAGER;

    final isSecretary = user.role == UserRole.SECRETARY;
    final isEmployee = user.role == UserRole.EMPLOYEE;

    final shifts = isManager
        ? allShifts
        : isSecretary
            ? allShifts
            : allShifts.where((s) => s.employeeIds.contains(user.id)).toList();

    // ── Visão exclusiva do colaborador: calendário ──────────────────────
    if (isEmployee) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
          title: const Text('Minha Escala'),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: _EmployeeCalendarView(shifts: shifts, userName: user.name),
        ),
      );
    }

    // ── Visão de gestores / secretários: lista agrupada por mês ─────────
    final grouped = _groupByMonth(shifts);
    final assignableUsers = _allUsers
        .where((member) =>
            member.role == UserRole.EMPLOYEE && member.managerId == user.id)
        .toList();

    final listBody = RefreshIndicator(
      onRefresh: _refresh,
      child: grouped.isEmpty
          ? const CustomScrollView(
              slivers: [
                SliverFillRemaining(
                    child: Center(child: Text('Nenhuma escala encontrada.')))
              ],
            )
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
                  assignableUsers: assignableUsers,
                  isManager: isManager,
                  isSecretary: isSecretary,
                );
              },
            ),
    );

    // ── Secretário: visão com abas (Lista + Calendário) ──────────────────
    if (isSecretary) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
            title: const Text('Escalas'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.list_alt_outlined), text: 'Lista'),
                Tab(
                    icon: Icon(Icons.calendar_month_outlined),
                    text: 'Calendário'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              listBody,
              RefreshIndicator(
                onRefresh: _refresh,
                child:
                    _SecretaryCalendarView(shifts: shifts, allUsers: _allUsers),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
        title: const Text('Escalas'),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              heroTag: 'fab_schedule',
              onPressed: () => _pickMonthAndCreate(context),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Nova Escala do Mês'),
            )
          : null,
      body: listBody,
    );
  }
}

// -- Employee calendar view -------------------------------------------------

class _EmployeeCalendarView extends StatefulWidget {
  final List<ShiftModel> shifts;
  final String userName;

  const _EmployeeCalendarView({
    required this.shifts,
    required this.userName,
  });

  @override
  State<_EmployeeCalendarView> createState() => _EmployeeCalendarViewState();
}

class _EmployeeCalendarViewState extends State<_EmployeeCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Marca como "dia todo" se hora de início for 00:xx e fim for 23:xx
  bool _isFullDay(ShiftModel s) {
    final start = s.startTime ?? '';
    final end = s.endTime ?? '';
    return (start.startsWith('00') || start.isEmpty) &&
        (end.startsWith('23') || end.isEmpty && start.isEmpty);
  }

  // Turnos do dia selecionado
  List<ShiftModel> _shiftsForDay(DateTime day) => widget.shifts.where((s) {
        final dt = DateTime.tryParse(s.date);
        if (dt == null) return false;
        return dt.year == day.year &&
            dt.month == day.month &&
            dt.day == day.day;
      }).toList();

  // Constrói mapa de datas com marcadores
  Map<DateTime, List<ShiftModel>> get _eventMap {
    final map = <DateTime, List<ShiftModel>>{};
    for (final s in widget.shifts) {
      final dt = DateTime.tryParse(s.date);
      if (dt == null) continue;
      final key = DateTime.utc(dt.year, dt.month, dt.day);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  List<ShiftModel> _getEvents(DateTime day) =>
      _eventMap[DateTime.utc(day.year, day.month, day.day)] ?? [];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedShifts =
        _selectedDay != null ? _shiftsForDay(_selectedDay!) : <ShiftModel>[];

    return Column(
      children: [
        // ── Legenda ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _LegendDot(
                color: colorScheme.primary,
                label: 'Turno parcial',
              ),
              const SizedBox(width: 16),
              const _LegendDot(
                color: Colors.deepOrange,
                label: 'Dia todo (plantão)',
              ),
            ],
          ),
        ),

        // ── Calendário ────────────────────────────────────────────────────
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: TableCalendar<ShiftModel>(
            locale: 'pt_BR',
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            eventLoader: _getEvents,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay =
                    isSameDay(_selectedDay, selected) ? null : selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) => setState(() => _focusedDay = focused),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              markerSize: 7,
              markerDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 1.5),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                  fontWeight: FontWeight.bold, color: colorScheme.primary),
              weekendTextStyle: const TextStyle(color: Colors.redAccent),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            // marcadores coloridos por tipo
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                final isFullDay = events.any((e) => _isFullDay(e));
                return Positioned(
                  bottom: 4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isFullDay ? Colors.deepOrange : colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Detalhe do dia selecionado ────────────────────────────────────
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.event_note_outlined,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat("EEEE, d 'de' MMMM", 'pt_BR')
                      .format(_selectedDay!),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        Expanded(
          child: _selectedDay == null
              ? _EmptyCalendarHint()
              : selectedShifts.isEmpty
                  ? _NothingOnDay()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: selectedShifts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = selectedShifts[i];
                        final full = _isFullDay(s);
                        return _ShiftDetailCard(shift: s, isFullDay: full);
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Cartão de detalhe de turno ──────────────────────────────────────────────

class _ShiftDetailCard extends StatelessWidget {
  final ShiftModel shift;
  final bool isFullDay;

  const _ShiftDetailCard({required this.shift, required this.isFullDay});

  @override
  Widget build(BuildContext context) {
    final color =
        isFullDay ? Colors.deepOrange : Theme.of(context).colorScheme.primary;
    final bgColor = color.withAlpha(18);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone lateral colorido
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFullDay ? Icons.wb_sunny_outlined : Icons.access_time_outlined,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFullDay ? 'Plantão — Dia Todo' : 'Turno Parcial',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (shift.startTime != null || shift.endTime != null)
                  _InfoRow(
                    icon: Icons.schedule_outlined,
                    label: 'Horário',
                    value: isFullDay
                        ? 'Dia inteiro'
                        : '${shift.startTime ?? '--'} → ${shift.endTime ?? '--'}',
                    color: color,
                  ),
                if (shift.observations != null &&
                    shift.observations!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.notes_outlined,
                    label: 'Observações',
                    value: shift.observations!,
                    color: color,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color.withAlpha(180)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class _EmptyCalendarHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Toque em um dia marcado\npara ver sua escala',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _NothingOnDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Nenhuma escala neste dia',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// -- Secretary calendar view ------------------------------------------------

class _SecretaryCalendarView extends StatefulWidget {
  final List<ShiftModel> shifts;
  final List<UserModel> allUsers;

  const _SecretaryCalendarView({required this.shifts, required this.allUsers});

  @override
  State<_SecretaryCalendarView> createState() => _SecretaryCalendarViewState();
}

class _SecretaryCalendarViewState extends State<_SecretaryCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedManagerId;

  static const List<Color> _palette = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00695C),
    Color(0xFF4527A0),
    Color(0xFFAD1457),
    Color(0xFF558B2F),
    Color(0xFF00838F),
    Color(0xFF4E342E),
    Color(0xFF37474F),
  ];

  List<ShiftModel> get _filteredShifts => _selectedManagerId == null
      ? widget.shifts
      : widget.shifts.where((s) => s.managerId == _selectedManagerId).toList();

  Map<String, Color> _buildColorMap() {
    final ids = _filteredShifts.expand((s) => s.employeeIds).toSet().toList()
      ..sort();
    return {
      for (var i = 0; i < ids.length; i++) ids[i]: _palette[i % _palette.length]
    };
  }

  Map<DateTime, List<ShiftModel>> get _eventMap {
    final map = <DateTime, List<ShiftModel>>{};
    for (final s in _filteredShifts) {
      final dt = DateTime.tryParse(s.date);
      if (dt == null) continue;
      final key = DateTime.utc(dt.year, dt.month, dt.day);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  List<ShiftModel> _getEvents(DateTime day) =>
      _eventMap[DateTime.utc(day.year, day.month, day.day)] ?? [];

  String _userName(String id) {
    try {
      return widget.allUsers.firstWhere((u) => u.id == id).name;
    } catch (_) {
      return id;
    }
  }

  String _managerName(String id) {
    try {
      return widget.allUsers.firstWhere((u) => u.id == id).name;
    } catch (_) {
      return 'Gestor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorMap = _buildColorMap();
    final colorScheme = Theme.of(context).colorScheme;
    final selectedShifts =
        _selectedDay != null ? _getEvents(_selectedDay!) : <ShiftModel>[];

    final legendIds =
        _filteredShifts.expand((s) => s.employeeIds).toSet().toList()..sort();

    // Gestores únicos presentes nas escalas
    final managerIds = widget.shifts.map((s) => s.managerId).toSet().toList()
      ..sort();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filtro por gestor ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedManagerId,
              decoration: const InputDecoration(
                labelText: 'Filtrar por gestor',
                prefixIcon: Icon(Icons.manage_accounts_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos os gestores'),
                ),
                ...managerIds.map(
                  (id) => DropdownMenuItem<String?>(
                    value: id,
                    child: Text(_managerName(id)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedManagerId = value);
              },
            ),
          ),

          // Legenda de cores por colaborador
          if (legendIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: legendIds.map((id) {
                  final color = colorMap[id] ?? Colors.grey;
                  return _LegendDot(color: color, label: _userName(id));
                }).toList(),
              ),
            ),

          // Calendário
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: TableCalendar<ShiftModel>(
              locale: 'pt_BR',
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              eventLoader: _getEvents,
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay =
                      isSameDay(_selectedDay, selected) ? null : selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) => setState(() => _focusedDay = focused),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                markerSize: 0,
                selectedDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary, width: 1.5),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                    fontWeight: FontWeight.bold, color: colorScheme.primary),
                weekendTextStyle: const TextStyle(color: Colors.redAccent),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (ctx, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  final ids = events
                      .expand((e) => e.employeeIds)
                      .toSet()
                      .toList()
                    ..sort();
                  return Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ids.take(6).map((id) {
                        final color = colorMap[id] ?? Colors.grey;
                        return Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),

          // Cabeçalho do dia selecionado
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.event_note_outlined,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat("EEEE, d 'de' MMMM", 'pt_BR')
                        .format(_selectedDay!),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),

          if (_selectedDay != null && selectedShifts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nenhuma escala neste dia',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),

          // Cards por colaborador no dia selecionado
          if (selectedShifts.isNotEmpty)
            ...selectedShifts.expand((shift) {
              return shift.employeeIds.map((empId) {
                final color = colorMap[empId] ?? Colors.grey;
                final name = _userName(empId);
                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color,
                        radius: 16,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if (shift.startTime != null)
                              Text(
                                '${shift.startTime} → ${shift.endTime ?? '--'}',
                                style: TextStyle(fontSize: 12, color: color),
                              ),
                            if (shift.observations != null &&
                                shift.observations!.isNotEmpty)
                              Text(
                                shift.observations!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              });
            }),

          // Dica quando nenhum dia está selecionado
          if (_selectedDay == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'Toque em um dia marcado\npara ver as escalas',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// -- Month summary card -----------------------------------------------------

class _MonthCard extends StatelessWidget {
  final String label;
  final List<ShiftModel> shifts;
  final List<UserModel> allUsers;
  final List<UserModel> assignableUsers;
  final bool isManager;
  final bool isSecretary;

  const _MonthCard({
    required this.label,
    required this.shifts,
    required this.allUsers,
    required this.assignableUsers,
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

  Future<void> _openMonthEditor(BuildContext context) async {
    if (shifts.isEmpty) return;

    final firstDate = DateTime.tryParse(shifts.first.date);
    if (firstDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir esta escala.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MonthBuilderScreen(
          year: firstDate.year,
          month: firstDate.month,
          allUsers: allUsers,
          assignableUsers: assignableUsers,
          existingShifts: shifts,
        ),
      ),
    );
  }

  Future<void> _deleteMonth(BuildContext context) async {
    if (shifts.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir escala do mês'),
        content: Text(
          'Deseja realmente remover toda a escala de $label? Esta ação excluirá ${shifts.length} dia${shifts.length == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir mês'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final shiftCtrl = context.read<ShiftProvider>();
      for (final shift in List<ShiftModel>.from(shifts)) {
        await shiftCtrl.delete(shift.id);
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Escala de $label removida com sucesso!')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao remover a escala do mês.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editShift(BuildContext context, ShiftModel shift) async {
    final startCtrl = TextEditingController(text: shift.startTime ?? '');
    final endCtrl = TextEditingController(text: shift.endTime ?? '');
    final obsCtrl = TextEditingController(text: shift.observations ?? '');
    final selectedIds = List<String>.from(shift.employeeIds);

    final dt = DateTime.tryParse(shift.date);
    final String dayTitle;
    if (dt != null) {
      final raw = DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(dt);
      dayTitle = raw[0].toUpperCase() + raw.substring(1);
    } else {
      dayTitle = shift.date;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                Row(
                  children: [
                    const Icon(Icons.edit_calendar_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dayTitle,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
                                  minute: int.tryParse(parts[1]) ?? 0)
                              : const TimeOfDay(hour: 0, minute: 0);
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
                              labelText: 'Início',
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
                    labelText: 'Observações',
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
                const SizedBox(height: 4),
                ...assignableUsers.map((u) => CheckboxListTile(
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final updated = shift.copyWith(
                        startTime:
                            startCtrl.text.isEmpty ? null : startCtrl.text,
                        endTime: endCtrl.text.isEmpty ? null : endCtrl.text,
                        employeeIds: List.from(selectedIds),
                        observations:
                            obsCtrl.text.isEmpty ? null : obsCtrl.text,
                      );
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      try {
                        await context.read<ShiftProvider>().update(updated);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Escala atualizada com sucesso!')),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Erro ao atualizar escala.'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar Alterações'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSecretary) {
      final Map<String, List<ShiftModel>> byManager = {};
      for (final s in shifts) {
        byManager.putIfAbsent(s.managerId, () => []).add(s);
      }
      final managerNames = byManager.keys.map(_managerName).join(' · ');

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${shifts.length} dia${shifts.length != 1 ? 's' : ''} escalado${shifts.length != 1 ? 's' : ''}',
              ),
              if (managerNames.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.person_pin_outlined,
                        size: 12, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Gestor responsável: $managerNames',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isManager)
              IconButton(
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                tooltip: 'Configurar mês',
                onPressed: () => _openMonthEditor(context),
              ),
            if (isManager)
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 20,
                  color: Colors.red,
                ),
                tooltip: 'Excluir mês',
                onPressed: () => _deleteMonth(context),
              ),
          ],
        ),
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
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: Colors.blueGrey),
                        onPressed: () => _editShift(context, shift),
                        tooltip: 'Editar escala',
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
  final List<UserModel> assignableUsers;
  final List<ShiftModel> existingShifts;

  const _MonthBuilderScreen({
    required this.year,
    required this.month,
    required this.allUsers,
    required this.assignableUsers,
    this.existingShifts = const [],
  });

  @override
  State<_MonthBuilderScreen> createState() => _MonthBuilderScreenState();
}

class _MonthBuilderScreenState extends State<_MonthBuilderScreen> {
  final Map<String, _DayConfig> _configs = {};
  final Map<String, ShiftModel> _existingShiftByDate = {};
  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final lastDay = DateTime(widget.year, widget.month + 1, 0).day;
    _days = List.generate(
      lastDay,
      (i) => DateTime(widget.year, widget.month, i + 1),
    );

    for (final shift in widget.existingShifts) {
      final date = DateTime.tryParse(shift.date);
      if (date == null) continue;

      final key = _dateKey(date);
      _existingShiftByDate[key] = shift;
      _configs[key] = _DayConfig(
        employeeIds: List<String>.from(shift.employeeIds),
        startTime: shift.startTime ?? '',
        endTime: shift.endTime ?? '',
        observations: shift.observations ?? '',
      );
    }
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
                  ...widget.assignableUsers.map((u) => CheckboxListTile(
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
      final configuredKeys = configuredDays.map((entry) => entry.key).toSet();

      for (final entry in configuredDays) {
        final existingShift = _existingShiftByDate[entry.key];

        if (existingShift != null) {
          await shiftCtrl.update(
            existingShift.copyWith(
              startTime:
                  entry.value.startTime.isEmpty ? null : entry.value.startTime,
              endTime: entry.value.endTime.isEmpty ? null : entry.value.endTime,
              employeeIds: entry.value.employeeIds,
              observations: entry.value.observations.isEmpty
                  ? null
                  : entry.value.observations,
            ),
          );
        } else {
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
      }

      final removedDays = _existingShiftByDate.entries
          .where((entry) => !configuredKeys.contains(entry.key))
          .map((entry) => entry.value)
          .toList();

      for (final shift in removedDays) {
        await shiftCtrl.delete(shift.id);
      }

      if (mounted) {
        Navigator.pop(context); // close loading
        Navigator.pop(context); // back to list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.existingShifts.isEmpty
                  ? '${configuredDays.length} dia${configuredDays.length != 1 ? 's' : ''} salvo${configuredDays.length != 1 ? 's' : ''} com sucesso!'
                  : 'Escala do mês atualizada com sucesso!')),
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
    final isEditingMonth = widget.existingShifts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditingMonth
            ? 'Editar Escala - $monthLabel'
            : 'Escala - $monthLabel'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saveAll,
            icon: const Icon(Icons.save_outlined),
            label: Text(configured > 0
                ? '${isEditingMonth ? 'Atualizar' : 'Salvar'} ($configured dia${configured != 1 ? 's' : ''})'
                : isEditingMonth
                    ? 'Atualizar Escala'
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
