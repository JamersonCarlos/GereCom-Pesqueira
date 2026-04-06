import 'main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/planning_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _primary = Color(0xFF2E51A4);
const _bg = Color(0xFFF4F6FB);

const _colorCompleted = Color(0xFF388E3C);
const _colorInProgress = Color(0xFF1976D2);
const _colorWaiting = Color(0xFFF57C00);
const _colorCancelled = Color(0xFFD32F2F);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  DateTime? _startDate;
  DateTime? _endDate;
  late TabController _tabCtrl;

  List<UserModel> _teamUsers = [];
  bool _usersLoaded = false;

  // ── Dados para secretário: todos os gestores + seus serviços/planejamentos ──
  List<UserModel> _managers = [];
  // Map: managerId -> {services, plannings}
  Map<String, List<ServiceModel>> _servicesByManager = {};
  Map<String, List<PlanningModel>> _planningsByManager = {};
  bool _loadingAll = false;

  // ── Para gestor único selecionado (detalhe) ────────────────────────────────
  String? _selectedManagerId;

  @override
  void initState() {
    super.initState();
    // Determina o número de abas com base no papel já disponível no contexto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final me = context.read<AuthProvider>().currentUser;
      final count = (me?.role == UserRole.SECRETARY ||
              me?.role == UserRole.GENERAL_MANAGER)
          ? 4
          : 3;
      if (_tabCtrl.length != count) {
        _tabCtrl.dispose();
        setState(() {
          _tabCtrl = TabController(length: count, vsync: this);
        });
      }
      _loadAll();
    });
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser;
    if (me == null) return;

    setState(() => _loadingAll = true);

    final all = await auth.getAllUsers();
    if (!mounted) return;

    List<UserModel> managers = [];
    if (me.role == UserRole.SECRETARY) {
      managers = all
          .where((u) =>
              (u.role == UserRole.MANAGER ||
                  u.role == UserRole.GESTOR ||
                  u.role == UserRole.GENERAL_MANAGER) &&
              u.status == UserStatus.ACTIVE)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } else if (me.role == UserRole.GENERAL_MANAGER) {
      managers = all
          .where((u) =>
              (u.role == UserRole.MANAGER || u.role == UserRole.GESTOR) &&
              u.status == UserStatus.ACTIVE)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }

    setState(() {
      _teamUsers = all;
      _usersLoaded = true;
      _managers = managers;
    });

    // Para secretário/generalManager: carrega dados de TODOS os gestores em paralelo
    if (managers.isNotEmpty) {
      final api = context.read<ApiService>();
      final results = await Future.wait(
        managers.map((m) async {
          try {
            final svc = await api.getServices(m.id);
            final pln = await api.getPlannings(m.id);
            return MapEntry(m.id, (svc, pln));
          } catch (_) {
            return MapEntry(m.id, (<dynamic>[], <dynamic>[]));
          }
        }),
      );
      if (!mounted) return;
      final svcMap = <String, List<ServiceModel>>{};
      final plnMap = <String, List<PlanningModel>>{};
      for (final entry in results) {
        svcMap[entry.key] = (entry.value.$1)
            .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
            .toList();
        plnMap[entry.key] = (entry.value.$2)
            .map((e) => PlanningModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      setState(() {
        _servicesByManager = svcMap;
        _planningsByManager = plnMap;
        _selectedManagerId = managers.first.id;
      });
    }

    if (mounted) {
      setState(() => _loadingAll = false);
    }
  }

  // Todos os serviços consolidados (todos os gestores)
  List<ServiceModel> get _allServices =>
      _servicesByManager.values.expand((l) => l).toList();

  List<PlanningModel> get _allPlannings =>
      _planningsByManager.values.expand((l) => l).toList();

  // Serviços do gestor selecionado
  List<ServiceModel> get _selectedServices => _selectedManagerId != null
      ? (_servicesByManager[_selectedManagerId] ?? [])
      : _allServices;

  List<PlanningModel> get _selectedPlannings => _selectedManagerId != null
      ? (_planningsByManager[_selectedManagerId] ?? [])
      : _allPlannings;

  String _userName(String id) {
    try {
      return _teamUsers.firstWhere((u) => u.id == id).name.split(' ').first;
    } catch (_) {
      return id.length >= 6 ? id.substring(0, 6) : id;
    }
  }

  String _managerName(String id) {
    try {
      return _teamUsers.firstWhere((u) => u.id == id).name.split(' ').first;
    } catch (_) {
      return 'Gestor';
    }
  }

  List<ServiceModel> _applyDateFilter(List<ServiceModel> all) {
    if (_startDate == null && _endDate == null) return all;
    return all.where((s) {
      if (s.createdAt.isEmpty) return true;
      try {
        final d = DateTime.parse(s.createdAt);
        if (_startDate != null && d.isBefore(_startDate!)) return false;
        if (_endDate != null &&
            d.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
        return true;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  List<PlanningModel> _applyDateFilterPln(List<PlanningModel> all) {
    if (_startDate == null && _endDate == null) return all;
    return all.where((p) {
      if (p.createdAt.isEmpty) return true;
      try {
        final d = DateTime.parse(p.createdAt);
        if (_startDate != null && d.isBefore(_startDate!)) return false;
        if (_endDate != null &&
            d.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
        return true;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isSecretary = user.role == UserRole.SECRETARY;
    final isGeneralManager = user.role == UserRole.GENERAL_MANAGER;
    final isManager = user.role == UserRole.MANAGER ||
        user.role == UserRole.GESTOR ||
        user.role == UserRole.GENERAL_MANAGER;
    final hasAccess = isManager || isSecretary;

    if (!hasAccess) {
      return Scaffold(
        appBar: _buildAppBar(context, [], []),
        backgroundColor: _bg,
        body: const Center(
          child: Text('Acesso Restrito',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ),
      );
    }

    final useManagerFilter = isSecretary || isGeneralManager;

    // ── Dados baseados no papel ─────────────────────────────────────────────
    // Secretário/GM: usa dados carregados por gestor
    // Gestor comum: usa provider (já filtrado pelo seu ID)
    List<ServiceModel> rawAllSvc;
    List<PlanningModel> rawAllPln;
    List<ServiceModel> rawSelSvc;
    List<PlanningModel> rawSelPln;

    if (useManagerFilter) {
      rawAllSvc = _allServices;
      rawAllPln = _allPlannings;
      rawSelSvc = _selectedServices;
      rawSelPln = _selectedPlannings;
    } else {
      rawAllSvc = context.watch<ServiceProvider>().services;
      rawAllPln = context.watch<PlanningProvider>().plannings;
      rawSelSvc = rawAllSvc;
      rawSelPln = rawAllPln;
    }

    final allServices = _applyDateFilter(rawAllSvc);
    final allPlannings = _applyDateFilterPln(rawAllPln);
    final selServices = _applyDateFilter(rawSelSvc);
    final selPlannings = _applyDateFilterPln(rawSelPln);
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context, allServices, allPlannings),
      body: _loadingAll
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateFilter(context),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabCtrl,
                    labelColor: _primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: _primary,
                    indicatorWeight: 3,
                    isScrollable: useManagerFilter,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: [
                      const Tab(text: 'Visão Geral'),
                      if (useManagerFilter) const Tab(text: 'Por Gestor'),
                      const Tab(text: 'Equipe'),
                      const Tab(text: 'Mensal'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // Tab 0 — Visão Geral (consolidado para secretário,
                      // próprio gestor para manager)
                      _OverviewTab(
                          services: allServices, plannings: allPlannings),

                      // Tab 1 — Por Gestor (só para secretário/GM)
                      if (useManagerFilter)
                        _ManagersComparisonTab(
                          managers: _managers,
                          servicesByManager: {
                            for (final e in _servicesByManager.entries)
                              e.key: _applyDateFilter(e.value),
                          },
                          planningsByManager: {
                            for (final e in _planningsByManager.entries)
                              e.key: _applyDateFilterPln(e.value),
                          },
                          managerName: _managerName,
                          selectedManagerId: _selectedManagerId,
                          onSelectManager: (id) =>
                              setState(() => _selectedManagerId = id),
                          // Detail data for selected manager
                          selServices: selServices,
                          selPlannings: selPlannings,
                          userName: _userName,
                          usersLoaded: _usersLoaded,
                          teamUsers: _teamUsers,
                        ),

                      // Tab 2 — Equipe
                      _TeamTab(
                        services: useManagerFilter ? selServices : allServices,
                        userName: _userName,
                        usersLoaded: _usersLoaded,
                        teamUsers: _teamUsers,
                      ),

                      // Tab 3 — Mensal
                      _MonthlyTab(
                          services:
                              useManagerFilter ? selServices : allServices),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  AppBar _buildAppBar(BuildContext context, List<ServiceModel> services,
      List<PlanningModel> plannings) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
      ),
      title: const Text('Relatórios'),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          tooltip: 'Exportar PDF',
          onPressed: () => _generatePdf(context, plannings, services),
        ),
      ],
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: _primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _startDate = d);
              },
              child: Text(
                  _startDate != null ? fmt.format(_startDate!) : 'Início',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('—', style: TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _endDate = d);
              },
              child: Text(_endDate != null ? fmt.format(_endDate!) : 'Fim',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          if (_startDate != null || _endDate != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              onPressed: () => setState(() => _startDate = _endDate = null),
            ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, List<PlanningModel> plannings,
      List<ServiceModel> services) async {
    final pdf = pw.Document();

    final Map<String, int> memberCompleted = {};
    for (final s in services) {
      if (s.status == ServiceStatus.COMPLETED) {
        for (final tid in s.teamIds) {
          final name = _userName(tid);
          memberCompleted[name] = (memberCompleted[name] ?? 0) + 1;
        }
      }
    }

    final Map<String, int> monthly = {};
    for (final s in services) {
      if (s.status == ServiceStatus.COMPLETED && s.createdAt.isNotEmpty) {
        try {
          final d = DateTime.parse(s.createdAt);
          final key = DateFormat('MM/yyyy').format(d);
          monthly[key] = (monthly[key] ?? 0) + 1;
        } catch (_) {}
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(level: 0, text: 'Relatório GereCom Pesqueira'),
          if (_startDate != null && _endDate != null)
            pw.Text(
              'Período: ${DateFormat('dd/MM/yyyy').format(_startDate!)} a ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
            ),
          pw.SizedBox(height: 16),
          pw.Text('SERVIÇOS',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total: ${services.length}'),
          pw.Text(
              'Concluídos: ${services.where((s) => s.status == ServiceStatus.COMPLETED).length}'),
          pw.Text(
              'Em Andamento: ${services.where((s) => s.status == ServiceStatus.IN_PROGRESS).length}'),
          pw.Text(
              'Aguardando Aprovação: ${services.where((s) => s.status == ServiceStatus.WAITING_APPROVAL).length}'),
          pw.Text(
              'Cancelados: ${services.where((s) => s.status == ServiceStatus.CANCELLED).length}'),
          pw.SizedBox(height: 16),
          pw.Text('PLANEJAMENTOS',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total: ${plannings.length}'),
          pw.Text(
              'Aprovados: ${plannings.where((p) => p.status == ServiceStatus.APPROVED).length}'),
          pw.Text(
              'Pendentes: ${plannings.where((p) => p.status == ServiceStatus.PENDING).length}'),
          pw.Text(
              'Rejeitados: ${plannings.where((p) => p.status == ServiceStatus.REJECTED).length}'),
          pw.SizedBox(height: 16),
          pw.Text('PRODUTIVIDADE POR MEMBRO',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          if (memberCompleted.isEmpty)
            pw.Text('Sem dados de conclusão.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Membro', 'Serviços Concluídos'],
              data: (memberCompleted.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map((e) => [e.key, '${e.value}'])
                  .toList(),
            ),
          pw.SizedBox(height: 16),
          pw.Text('CONCLUSÕES POR MÊS',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          if (monthly.isEmpty)
            pw.Text('Sem dados.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Mês/Ano', 'Concluídos'],
              data: (monthly.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key)))
                  .map((e) => [e.key, '${e.value}'])
                  .toList(),
            ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Relatorio_GereCom.pdf',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB — Por Gestor (exclusiva do Secretário e General Manager)
// Mostra comparativo de todos os gestores + detalhe do selecionado
// ══════════════════════════════════════════════════════════════════════════════
class _ManagersComparisonTab extends StatelessWidget {
  final List<UserModel> managers;
  final Map<String, List<ServiceModel>> servicesByManager;
  final Map<String, List<PlanningModel>> planningsByManager;
  final String Function(String) managerName;
  final String? selectedManagerId;
  final void Function(String) onSelectManager;
  final List<ServiceModel> selServices;
  final List<PlanningModel> selPlannings;
  final String Function(String) userName;
  final bool usersLoaded;
  final List<UserModel> teamUsers;

  const _ManagersComparisonTab({
    required this.managers,
    required this.servicesByManager,
    required this.planningsByManager,
    required this.managerName,
    required this.selectedManagerId,
    required this.onSelectManager,
    required this.selServices,
    required this.selPlannings,
    required this.userName,
    required this.usersLoaded,
    required this.teamUsers,
  });

  @override
  Widget build(BuildContext context) {
    if (managers.isEmpty) {
      return const Center(
          child: Text('Nenhum gestor encontrado.',
              style: TextStyle(color: Colors.grey)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPIs consolidados ─────────────────────────────────────────────
          const _SectionTitle('Resumo Geral da Secretaria'),
          const SizedBox(height: 10),
          _buildConsolidatedKpis(),
          const SizedBox(height: 24),

          // ── Ranking de gestores ───────────────────────────────────────────
          const _SectionTitle('Desempenho por Gestor'),
          const SizedBox(height: 10),
          _buildManagerRankingChart(),
          const SizedBox(height: 16),
          ...managers.map((m) => _buildManagerCard(context, m)),
          const SizedBox(height: 24),

          // ── Detalhe do gestor selecionado ─────────────────────────────────
          if (selectedManagerId != null) ...[
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_pin, color: _primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Detalhe: ${managerName(selectedManagerId!)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailKpis(),
            const SizedBox(height: 16),
            _buildDetailTeam(),
          ],
        ],
      ),
    );
  }

  Widget _buildConsolidatedKpis() {
    final allSvc = servicesByManager.values.expand((l) => l).toList();
    final allPln = planningsByManager.values.expand((l) => l).toList();
    final total = allSvc.length;
    final completed =
        allSvc.where((s) => s.status == ServiceStatus.COMPLETED).length;
    final inProgress =
        allSvc.where((s) => s.status == ServiceStatus.IN_PROGRESS).length;
    final pending =
        allPln.where((p) => p.status == ServiceStatus.PENDING).length;

    return Column(
      children: [
        Row(children: [
          _KpiCard(
              label: 'Total Serviços',
              value: total,
              icon: Icons.build_circle_outlined,
              color: _primary),
          const SizedBox(width: 12),
          _KpiCard(
              label: 'Concluídos',
              value: completed,
              icon: Icons.check_circle_outline,
              color: _colorCompleted),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _KpiCard(
              label: 'Em Andamento',
              value: inProgress,
              icon: Icons.timelapse,
              color: _colorInProgress),
          const SizedBox(width: 12),
          _KpiCard(
              label: 'Planos Pendentes',
              value: pending,
              icon: Icons.hourglass_top_outlined,
              color: _colorWaiting),
        ]),
      ],
    );
  }

  Widget _buildManagerRankingChart() {
    if (managers.isEmpty) return const SizedBox.shrink();

    // Ordena gestores por serviços concluídos
    final sorted = managers.toList()
      ..sort((a, b) {
        final cA = (servicesByManager[a.id] ?? [])
            .where((s) => s.status == ServiceStatus.COMPLETED)
            .length;
        final cB = (servicesByManager[b.id] ?? [])
            .where((s) => s.status == ServiceStatus.COMPLETED)
            .length;
        return cB.compareTo(cA);
      });

    final maxVal = sorted.fold<int>(0, (prev, m) {
      final c = (servicesByManager[m.id] ?? [])
          .where((s) => s.status == ServiceStatus.COMPLETED)
          .length;
      return c > prev ? c : prev;
    });

    return Column(
      children: sorted.map((m) {
        final svc = servicesByManager[m.id] ?? [];
        final completed =
            svc.where((s) => s.status == ServiceStatus.COMPLETED).length;
        final total = svc.length;
        final inProgress =
            svc.where((s) => s.status == ServiceStatus.IN_PROGRESS).length;
        final ratio = maxVal > 0 ? completed / maxVal : 0.0;
        final isSelected = selectedManagerId == m.id;

        return GestureDetector(
          onTap: () => onSelectManager(m.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? _primary.withOpacity(0.07) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _primary : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _primary.withOpacity(0.12),
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                          color: isSelected ? _primary : Colors.black87,
                        ),
                      ),
                    ),
                    _MiniTag(
                        label: '$completed concluídos', color: _colorCompleted),
                    const SizedBox(width: 6),
                    _MiniTag(
                        label: '$inProgress andamento',
                        color: _colorInProgress),
                    const SizedBox(width: 6),
                    _MiniTag(label: '$total total', color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_colorCompleted),
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Toque para ver detalhes ↓',
                        style: TextStyle(
                            fontSize: 11, color: _primary.withOpacity(0.7))),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManagerCard(BuildContext context, UserModel m) =>
      const SizedBox.shrink(); // cards handled inline in ranking

  Widget _buildDetailKpis() {
    final completed =
        selServices.where((s) => s.status == ServiceStatus.COMPLETED).length;
    final inProgress =
        selServices.where((s) => s.status == ServiceStatus.IN_PROGRESS).length;
    final waiting = selServices
        .where((s) => s.status == ServiceStatus.WAITING_APPROVAL)
        .length;
    final cancelled =
        selServices.where((s) => s.status == ServiceStatus.CANCELLED).length;
    final approvedP =
        selPlannings.where((p) => p.status == ServiceStatus.APPROVED).length;
    final pendingP =
        selPlannings.where((p) => p.status == ServiceStatus.PENDING).length;

    return Column(
      children: [
        Row(children: [
          _KpiCard(
              label: 'Total',
              value: selServices.length,
              icon: Icons.build_circle_outlined,
              color: _primary),
          const SizedBox(width: 12),
          _KpiCard(
              label: 'Concluídos',
              value: completed,
              icon: Icons.check_circle_outline,
              color: _colorCompleted),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _KpiCard(
              label: 'Em Andamento',
              value: inProgress,
              icon: Icons.timelapse,
              color: _colorInProgress),
          const SizedBox(width: 12),
          _KpiCard(
              label: 'Aguardando',
              value: waiting,
              icon: Icons.hourglass_top_outlined,
              color: _colorWaiting),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _KpiCard(
              label: 'Cancelados',
              value: cancelled,
              icon: Icons.cancel_outlined,
              color: _colorCancelled),
          const SizedBox(width: 12),
          _KpiCard(
              label: 'Planos',
              value: selPlannings.length,
              icon: Icons.calendar_month_outlined,
              color: _primary,
              subtitle: '$approvedP apr · $pendingP pend'),
        ]),
      ],
    );
  }

  Widget _buildDetailTeam() {
    if (!usersLoaded) return const CircularProgressIndicator();
    final Map<String, int> completed = {};
    final Map<String, int> inProgress = {};
    for (final s in selServices) {
      for (final tid in s.teamIds) {
        if (s.status == ServiceStatus.COMPLETED) {
          completed[tid] = (completed[tid] ?? 0) + 1;
        } else if (s.status == ServiceStatus.IN_PROGRESS) {
          inProgress[tid] = (inProgress[tid] ?? 0) + 1;
        }
      }
    }
    final allIds = {...completed.keys, ...inProgress.keys}.toList()
      ..sort((a, b) => (completed[b] ?? 0).compareTo(completed[a] ?? 0));
    if (allIds.isEmpty) {
      return const Text('Nenhum membro com atividades.',
          style: TextStyle(color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Membros da Equipe'),
        const SizedBox(height: 8),
        ...allIds.map((id) => _MemberDetailCard(
              name: userName(id),
              completed: completed[id] ?? 0,
              inProgress: inProgress[id] ?? 0,
            )),
      ],
    );
  }
}

// Small colored tag widget
class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Visão Geral
// ══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final List<ServiceModel> services;
  final List<PlanningModel> plannings;

  const _OverviewTab({required this.services, required this.plannings});

  @override
  Widget build(BuildContext context) {
    final completed =
        services.where((s) => s.status == ServiceStatus.COMPLETED).length;
    final inProgress =
        services.where((s) => s.status == ServiceStatus.IN_PROGRESS).length;
    final waiting = services
        .where((s) => s.status == ServiceStatus.WAITING_APPROVAL)
        .length;
    final cancelled =
        services.where((s) => s.status == ServiceStatus.CANCELLED).length;
    final total = services.length;

    final approvedP =
        plannings.where((p) => p.status == ServiceStatus.APPROVED).length;
    final pendingP =
        plannings.where((p) => p.status == ServiceStatus.PENDING).length;
    final rejectedP =
        plannings.where((p) => p.status == ServiceStatus.REJECTED).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _KpiCard(
                label: 'Total',
                value: total,
                icon: Icons.build_circle_outlined,
                color: _primary),
            const SizedBox(width: 12),
            _KpiCard(
                label: 'Concluídos',
                value: completed,
                icon: Icons.check_circle_outline,
                color: _colorCompleted),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _KpiCard(
                label: 'Em Andamento',
                value: inProgress,
                icon: Icons.timelapse,
                color: _colorInProgress),
            const SizedBox(width: 12),
            _KpiCard(
                label: 'Aguardando',
                value: waiting,
                icon: Icons.hourglass_top_outlined,
                color: _colorWaiting),
          ]),
          const SizedBox(height: 24),
          if (total > 0) ...[
            const _SectionTitle('Distribuição de Status'),
            const SizedBox(height: 12),
            _StatusPieChart(
              completed: completed,
              inProgress: inProgress,
              waiting: waiting,
              cancelled: cancelled,
            ),
            const SizedBox(height: 24),
          ],
          const _SectionTitle('Planejamentos'),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Total', value: plannings.length, color: _primary),
          _SummaryRow(
              label: 'Aprovados', value: approvedP, color: _colorCompleted),
          _SummaryRow(
              label: 'Pendentes', value: pendingP, color: _colorWaiting),
          _SummaryRow(
              label: 'Rejeitados', value: rejectedP, color: _colorCancelled),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Equipe
// ══════════════════════════════════════════════════════════════════════════════
class _TeamTab extends StatelessWidget {
  final List<ServiceModel> services;
  final String Function(String) userName;
  final bool usersLoaded;
  final List<UserModel> teamUsers;

  const _TeamTab({
    required this.services,
    required this.userName,
    required this.usersLoaded,
    required this.teamUsers,
  });

  @override
  Widget build(BuildContext context) {
    if (!usersLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<String, int> memberCompleted = {};
    final Map<String, int> memberInProgress = {};

    for (final s in services) {
      for (final tid in s.teamIds) {
        if (s.status == ServiceStatus.COMPLETED) {
          memberCompleted[tid] = (memberCompleted[tid] ?? 0) + 1;
        } else if (s.status == ServiceStatus.IN_PROGRESS) {
          memberInProgress[tid] = (memberInProgress[tid] ?? 0) + 1;
        }
      }
    }

    final allIds = <String>{
      ...memberCompleted.keys,
      ...memberInProgress.keys,
    };

    if (allIds.isEmpty) {
      return const Center(
        child: Text('Nenhum dado de equipe disponível.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final sorted = allIds.toList()
      ..sort((a, b) =>
          (memberCompleted[b] ?? 0).compareTo(memberCompleted[a] ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Serviços Concluídos por Membro'),
          const SizedBox(height: 12),
          _MemberBarChart(
            memberIds: sorted,
            memberCompleted: memberCompleted,
            userName: userName,
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Detalhes por Membro'),
          const SizedBox(height: 8),
          ...sorted.map((id) => _MemberDetailCard(
                name: userName(id),
                completed: memberCompleted[id] ?? 0,
                inProgress: memberInProgress[id] ?? 0,
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Mensal
// ══════════════════════════════════════════════════════════════════════════════
class _MonthlyTab extends StatelessWidget {
  final List<ServiceModel> services;

  const _MonthlyTab({required this.services});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> monthly = {};
    for (final s in services) {
      if (s.status == ServiceStatus.COMPLETED && s.createdAt.isNotEmpty) {
        try {
          final d = DateTime.parse(s.createdAt);
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
          monthly[key] = (monthly[key] ?? 0) + 1;
        } catch (_) {}
      }
    }

    final sortedMonths = monthly.keys.toList()..sort();
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prevDate = DateTime(now.year, now.month - 1, 1);
    final prevKey =
        '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';

    final thisMonth = monthly[currentKey] ?? 0;
    final lastMonth = monthly[prevKey] ?? 0;
    final diff = thisMonth - lastMonth;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _KpiCard(
              label: 'Este Mês',
              value: thisMonth,
              icon: Icons.calendar_month,
              color: _primary,
              subtitle: DateFormat('MMMM yyyy', 'pt_BR').format(now),
            ),
            const SizedBox(width: 12),
            _KpiCard(
              label: 'Mês Anterior',
              value: lastMonth,
              icon: Icons.history,
              color: Colors.blueGrey,
              subtitle: diff >= 0 ? '+$diff vs anterior' : '$diff vs anterior',
              subtitleColor: diff >= 0 ? _colorCompleted : _colorCancelled,
            ),
          ]),
          const SizedBox(height: 24),
          if (sortedMonths.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nenhum serviço concluído ainda.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            const _SectionTitle('Serviços Concluídos por Mês'),
            const SizedBox(height: 12),
            _MonthlyBarChart(monthly: monthly, sortedMonths: sortedMonths),
            const SizedBox(height: 24),
            const _SectionTitle('Histórico Mensal'),
            const SizedBox(height: 8),
            ...sortedMonths.reversed.map((key) {
              final parts = key.split('-');
              final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
              return _SummaryRow(
                label: DateFormat('MMMM yyyy', 'pt_BR').format(dt),
                value: monthly[key]!,
                color: _colorCompleted,
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHART WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StatusPieChart extends StatefulWidget {
  final int completed, inProgress, waiting, cancelled;
  const _StatusPieChart({
    required this.completed,
    required this.inProgress,
    required this.waiting,
    required this.cancelled,
  });

  @override
  State<_StatusPieChart> createState() => _StatusPieChartState();
}

class _StatusPieChartState extends State<_StatusPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final sections = <_PieEntry>[
      _PieEntry('Concluído', widget.completed, _colorCompleted),
      _PieEntry('Em Andamento', widget.inProgress, _colorInProgress),
      _PieEntry('Aguardando', widget.waiting, _colorWaiting),
      _PieEntry('Cancelado', widget.cancelled, _colorCancelled),
    ].where((e) => e.value > 0).toList();

    if (sections.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (ev, resp) {
                      setState(() {
                        if (!ev.isInterestedForInteractions ||
                            resp == null ||
                            resp.touchedSection == null) {
                          _touched = -1;
                          return;
                        }
                        _touched = resp.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: sections.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final isTouched = i == _touched;
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      color: e.color,
                      radius: isTouched ? 82 : 68,
                      title: isTouched ? '${e.value}' : '',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    );
                  }).toList(),
                  centerSpaceRadius: 48,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: sections
                  .map((e) => _LegendDot(color: e.color, label: e.label))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberBarChart extends StatelessWidget {
  final List<String> memberIds;
  final Map<String, int> memberCompleted;
  final String Function(String) userName;

  const _MemberBarChart({
    required this.memberIds,
    required this.memberCompleted,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    if (memberIds.isEmpty) return const SizedBox.shrink();
    final maxVal = memberCompleted.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxVal + 1).toDouble(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${userName(memberIds[group.x])}\n',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '${rod.toY.toInt()} concluído(s)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      )
                    ],
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= memberIds.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          userName(memberIds[idx]),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.blueGrey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (val, meta) => Text(
                      val.toInt().toString(),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.blueGrey),
                    ),
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: memberIds.asMap().entries.map((entry) {
                final i = entry.key;
                final id = entry.value;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: (memberCompleted[id] ?? 0).toDouble(),
                      color: _colorCompleted,
                      width: 18,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    )
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, int> monthly;
  final List<String> sortedMonths;

  const _MonthlyBarChart({required this.monthly, required this.sortedMonths});

  @override
  Widget build(BuildContext context) {
    final maxVal = monthly.values.fold(0, (a, b) => a > b ? a : b);
    final displayMonths = sortedMonths.length > 6
        ? sortedMonths.sublist(sortedMonths.length - 6)
        : sortedMonths;
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxVal + 1).toDouble(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gi, rod, ri) {
                    final key = displayMonths[group.x];
                    final parts = key.split('-');
                    final dt =
                        DateTime(int.parse(parts[0]), int.parse(parts[1]));
                    return BarTooltipItem(
                      '${DateFormat('MMM/yy', 'pt_BR').format(dt)}\n',
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toInt()} concluído(s)',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        )
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= displayMonths.length) {
                        return const SizedBox.shrink();
                      }
                      final key = displayMonths[idx];
                      final parts = key.split('-');
                      final dt =
                          DateTime(int.parse(parts[0]), int.parse(parts[1]));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM/yy', 'pt_BR').format(dt),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.blueGrey),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (val, meta) => Text(
                      val.toInt().toString(),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.blueGrey),
                    ),
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: displayMonths.asMap().entries.map((entry) {
                final i = entry.key;
                final key = entry.value;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: (monthly[key] ?? 0).toDouble(),
                      color: key == currentKey ? _primary : _colorCompleted,
                      width: 20,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    )
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blueGrey)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor ?? Colors.blueGrey)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberDetailCard extends StatelessWidget {
  final String name;
  final int completed;
  final int inProgress;

  const _MemberDetailCard({
    required this.name,
    required this.completed,
    required this.inProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _primary.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: _primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            _Badge(value: completed, color: _colorCompleted, label: 'Conc.'),
            const SizedBox(width: 8),
            _Badge(value: inProgress, color: _colorInProgress, label: 'And.'),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int value;
  final Color color;
  final String label;

  const _Badge({required this.value, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(12)),
          child: Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.blueGrey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(12)),
              child: Text('$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        ],
      );
}

class _PieEntry {
  final String label;
  final int value;
  final Color color;
  const _PieEntry(this.label, this.value, this.color);
}
