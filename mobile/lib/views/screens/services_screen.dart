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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadServices());
  }

  Future<void> _loadServices() async {
    final auth = context.read<AuthProvider>();
    final svcProvider = context.read<ServiceProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    if (user.role == UserRole.EMPLOYEE) {
      await svcProvider.loadForEmployee(user.id);
    } else {
      final managerId = auth.managerId;
      if (managerId != null) await svcProvider.loadForManager(managerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

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
          if (provider.services.isEmpty) {
            return const Center(child: Text('Nenhum serviço em andamento.'));
          }
          return RefreshIndicator(
            onRefresh: _loadServices,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.services.length,
              itemBuilder: (context, i) {
                return ServiceCard(service: provider.services[i], user: user);
              },
            ),
          );
        },
      ),
    );
  }
}
