import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../models/models.dart';
import '../widgets/service_modal.dart';
import '../widgets/service_card.dart';
import 'main_scaffold.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<UserModel> _allUsers = [];
  String? _selectedManagerId;
  String? _selectedCollaboratorId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadUsers();
      await _loadServices();
    });
  }

  Future<void> _loadUsers() async {
    try {
      final users = await context.read<AuthProvider>().getAllUsers();
      if (!mounted) return;
      setState(() => _allUsers = users);
    } catch (_) {
      // Ignore user list errors; services can still be shown without filters.
    }
  }

  Future<void> _loadServices() async {
    final auth = context.read<AuthProvider>();
    final svcProvider = context.read<ServiceProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    if (user.role == UserRole.EMPLOYEE) {
      await svcProvider.loadForEmployee(user.id);
    } else if (user.role == UserRole.SECRETARY) {
      await svcProvider.loadAll();
    } else {
      final managerId = auth.managerId;
      if (managerId != null) await svcProvider.loadForManager(managerId);
    }
  }

  List<UserModel> _managerOptions(List<ServiceModel> services) {
    final ids = services.map((s) => s.managerId).toSet();
    return _allUsers.where((u) => ids.contains(u.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<UserModel> _collaboratorOptions(
      List<ServiceModel> services, String? managerId) {
    final source = managerId == null
        ? services
        : services.where((s) => s.managerId == managerId);
    final teamIds = source.expand((s) => s.teamIds).toSet();
    return _allUsers
        .where((u) =>
            teamIds.contains(u.id) &&
            u.role == UserRole.EMPLOYEE &&
            (managerId == null || u.managerId == managerId))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ServiceModel> _applySecretaryFilters(List<ServiceModel> services) {
    return services.where((s) {
      final managerOk =
          _selectedManagerId == null || s.managerId == _selectedManagerId;
      final collaboratorOk = _selectedCollaboratorId == null ||
          s.teamIds.contains(_selectedCollaboratorId);
      return managerOk && collaboratorOk;
    }).toList();
  }

  Widget _buildSecretarySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<ServiceModel> items,
    required UserModel user,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(60)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title (${items.length})',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Nenhum serviço nesta categoria.'),
            )
          else
            ...items.map((service) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: ServiceCard(service: service, user: user),
                )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final isSecretary = user.role == UserRole.SECRETARY;

    bool canCreate = user.role == UserRole.GESTOR ||
        user.role == UserRole.MANAGER ||
        user.role == UserRole.GENERAL_MANAGER;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Serviços em Andamento'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServices,
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ServiceModal(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Novo Serviço'),
            )
          : null,
      body: Consumer<ServiceProvider>(
        builder: (context, provider, child) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allServices = provider.services;

          if (allServices.isEmpty) {
            return const Center(child: Text('Nenhum serviço encontrado.'));
          }

          if (isSecretary) {
            final managers = _managerOptions(allServices);
            final collaborators =
                _collaboratorOptions(allServices, _selectedManagerId);

            if (_selectedManagerId != null &&
                !managers.any((m) => m.id == _selectedManagerId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedManagerId = null;
                    _selectedCollaboratorId = null;
                  });
                }
              });
            }

            if (_selectedCollaboratorId != null &&
                !collaborators.any((c) => c.id == _selectedCollaboratorId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedCollaboratorId = null);
                }
              });
            }

            final filtered = _applySecretaryFilters(allServices);

            final realized = filtered
                .where((s) => s.status == ServiceStatus.IN_PROGRESS)
                .toList();
            final waiting = filtered
                .where((s) => s.status == ServiceStatus.WAITING_APPROVAL)
                .toList();
            final finished = filtered
                .where((s) => s.status == ServiceStatus.COMPLETED)
                .toList();

            return RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_loadUsers(), _loadServices()]);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtros do secretário',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedManagerId,
                            decoration: const InputDecoration(
                              labelText: 'Gestor',
                              prefixIcon: Icon(Icons.manage_accounts_outlined),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos os gestores'),
                              ),
                              ...managers.map((m) => DropdownMenuItem<String?>(
                                    value: m.id,
                                    child: Text(m.name),
                                  )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedManagerId = value;
                                _selectedCollaboratorId = null;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedCollaboratorId,
                            decoration: const InputDecoration(
                              labelText: 'Colaborador',
                              prefixIcon: Icon(Icons.people_outline),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos os colaboradores'),
                              ),
                              ...collaborators.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCollaboratorId = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildSecretarySection(
                    title: 'Serviços Realizados',
                    icon: Icons.construction_outlined,
                    color: Colors.blue,
                    items: realized,
                    user: user,
                  ),
                  _buildSecretarySection(
                    title: 'Aguardando Aprovação',
                    icon: Icons.hourglass_top_outlined,
                    color: Colors.orange,
                    items: waiting,
                    user: user,
                  ),
                  _buildSecretarySection(
                    title: 'Finalizados',
                    icon: Icons.verified_outlined,
                    color: Colors.green,
                    items: finished,
                    user: user,
                  ),
                  if (realized.isEmpty && waiting.isEmpty && finished.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'Nenhum serviço encontrado para os filtros aplicados.'),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadServices,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allServices.length,
              itemBuilder: (context, i) {
                return ServiceCard(service: allServices[i], user: user);
              },
            ),
          );
        },
      ),
    );
  }
}
