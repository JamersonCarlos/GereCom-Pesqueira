import 'main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../providers/planning_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    var plannings = context.watch<PlanningProvider>().plannings;
    var services = context.watch<ServiceProvider>().services;
    final user = context.watch<AuthProvider>().currentUser;

    if (user == null ||
        (user.role != UserRole.MANAGER && user.role != UserRole.GESTOR)) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
          title: const Text('Relatórios'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
            child: Text('Acesso Restrito',
                style: TextStyle(fontSize: 18, color: Colors.grey))),
      );
    }

    if (_startDate != null && _endDate != null) {
      plannings = plannings.where((p) {
        if (p.createdAt.isEmpty) return true;
        try {
          final date = DateTime.parse(p.createdAt);
          return date.isAfter(_startDate!) &&
              date.isBefore(_endDate!.add(const Duration(days: 1)));
        } catch (_) {
          return true;
        }
      }).toList();

      services = services.where((s) {
        if (s.createdAt.isEmpty) return true;
        try {
          final date = DateTime.parse(s.createdAt);
          return date.isAfter(_startDate!) &&
              date.isBefore(_endDate!.add(const Duration(days: 1)));
        } catch (_) {
          return true;
        }
      }).toList();
    }

    final byType = <String, int>{};
    for (final p in plannings) {
      byType[p.serviceType] = (byType[p.serviceType] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
        title: const Text('Relatórios'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePdf(context, plannings, services),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateFilter(context),
            const SizedBox(height: 24),
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
              'Aguardando Aprovação',
              services
                  .where((s) => s.status == ServiceStatus.WAITING_APPROVAL)
                  .length,
              color: Colors.orange,
            ),
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
            const SizedBox(height: 24),
            _buildProductivitySection(services),
            const SizedBox(height: 24),
            _buildGestaoSection(plannings),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    final startText = _startDate != null
        ? DateFormat('dd/MM/yyyy').format(_startDate!)
        : 'Início';
    final endText =
        _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Fim';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrar por Período',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(startText),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _startDate = date);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(endText),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _endDate = date);
                    },
                  ),
                ),
                if (_startDate != null || _endDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
                  )
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductivitySection(List<ServiceModel> services) {
    final Map<String, int> funcCompleted = {};
    for (var s in services) {
      if (s.status == ServiceStatus.COMPLETED && s.completedBy != null) {
        funcCompleted[s.completedBy!] =
            (funcCompleted[s.completedBy!] ?? 0) + 1;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Produtividade (Serviços Concluídos)'),
        if (funcCompleted.isEmpty) const Text('Sem dados'),
        ...funcCompleted.entries
            .map((e) => _row('Funcionário #${e.key}', e.value)),
      ],
    );
  }

  Widget _buildGestaoSection(List<PlanningModel> plannings) {
    final Map<String, int> secApproved = {};
    for (var p in plannings) {
      if (p.status == ServiceStatus.APPROVED && p.secretaryId != null) {
        secApproved[p.secretaryId!] = (secApproved[p.secretaryId!] ?? 0) + 1;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gestão (Planejamentos Aprovados)'),
        if (secApproved.isEmpty) const Text('Sem dados'),
        ...secApproved.entries
            .map((e) => _row('Secretaria #${e.key}', e.value)),
      ],
    );
  }

  Future<void> _generatePdf(BuildContext context, List<PlanningModel> plannings,
      List<ServiceModel> services) async {
    final pdf = pw.Document();

    final Map<String, int> funcCompleted = {};
    for (var s in services) {
      if (s.status == ServiceStatus.COMPLETED && s.completedBy != null) {
        funcCompleted[s.completedBy!] =
            (funcCompleted[s.completedBy!] ?? 0) + 1;
      }
    }

    final Map<String, int> secApproved = {};
    for (var p in plannings) {
      if (p.status == ServiceStatus.APPROVED && p.secretaryId != null) {
        secApproved[p.secretaryId!] = (secApproved[p.secretaryId!] ?? 0) + 1;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Relatório Completo - GereCom'),
            if (_startDate != null && _endDate != null)
              pw.Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(_startDate!)} a ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                  style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            pw.Text('Resumo de Planejamentos',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Total: ${plannings.length}'),
            pw.Text(
                'Aprovados: ${plannings.where((p) => p.status == ServiceStatus.APPROVED).length}'),
            pw.Text(
                'Rejeitados: ${plannings.where((p) => p.status == ServiceStatus.REJECTED).length}'),
            pw.Text(
                'Pendentes: ${plannings.where((p) => p.status == ServiceStatus.PENDING).length}'),
            pw.SizedBox(height: 20),
            pw.Text('Resumo de Serviços',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Total: ${services.length}'),
            pw.Text(
                'Concluídos: ${services.where((s) => s.status == ServiceStatus.COMPLETED).length}'),
            pw.Text(
                'Aguardando Aprovação: ${services.where((s) => s.status == ServiceStatus.WAITING_APPROVAL).length}'),
            pw.Text(
                'Cancelados: ${services.where((s) => s.status == ServiceStatus.CANCELLED).length}'),
            pw.SizedBox(height: 20),
            pw.Text('Produtividade por Funcionário',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Funcionário ID', 'Serviços Concluídos'],
              data: funcCompleted.entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Gestão por Secretário',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Secretaria ID', 'Planejamentos Aprovados'],
              data: secApproved.entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Relatorio_Gerecom.pdf');
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
