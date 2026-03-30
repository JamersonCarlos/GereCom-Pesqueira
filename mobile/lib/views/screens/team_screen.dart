import 'main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/models.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<UserModel> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final managerId = auth.managerId;

    if (managerId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final members = await auth.getTeamMembers(managerId);
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar equipe: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleStatus(UserModel member) async {
    final auth = context.read<AuthProvider>();
    final newStatus = member.status == UserStatus.ACTIVE
        ? UserStatus.INACTIVE
        : UserStatus.ACTIVE;
    try {
      final updated = await auth.setUserStatus(member.id, newStatus);
      if (mounted) {
        setState(() {
          final idx = _members.indexWhere((m) => m.id == member.id);
          if (idx >= 0) _members[idx] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(UserModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover Membro'),
        content: Text('Remover ${member.name} da equipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().deleteUser(member.id);
      setState(() => _members.removeWhere((m) => m.id == member.id));
    }
  }

  void _showRegisterSheet(BuildContext context) {
    final usernameCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final functionCtrl = TextEditingController();
    UserRole selectedRole = UserRole.EMPLOYEE;
    final secretaryController = TextEditingController();
    String? selectedGestorId;

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
                const Text(
                  'Adicionar Membro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Usuário'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: functionCtrl,
                  decoration: const InputDecoration(labelText: 'Função/Cargo'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration:
                      const InputDecoration(labelText: 'Nível de Acesso'),
                  items: UserRole.values.where((role) {
// Apenas Secretario, Gestor e Funcionários (Employee) devem estar disponíveis para criação nesta tela.
// Isso oculta General_Manager e Manager, que não devem ser criados por aqui.
                    return role == UserRole.SECRETARY ||
                        role == UserRole.GESTOR ||
                        role == UserRole.EMPLOYEE;
                  }).map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_roleLabel(role)),
                    );
                  }).toList(),
                  onChanged: (v) => setModal(() => selectedRole = v!),
                ),
                const SizedBox(height: 16),
                if (selectedRole == UserRole.SECRETARY)
                  TextFormField(
                    controller: secretaryController,
                    decoration: const InputDecoration(labelText: 'Secretaria'),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Informe a secretaria';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 10),
                if ((selectedRole == UserRole.EMPLOYEE ||
                        selectedRole == UserRole.MANAGER) &&
                    context.read<AuthProvider>().currentUser?.role ==
                        UserRole.SECRETARY)
                  DropdownButtonFormField<String>(
                    value: selectedGestorId,
                    decoration:
                        const InputDecoration(labelText: 'Vincular a Gestor'),
                    items: _members
                        .where((m) => m.role == UserRole.GESTOR)
                        .map((gestor) {
                      return DropdownMenuItem(
                        value: gestor.id,
                        child: Text(gestor.name),
                      );
                    }).toList(),
                    onChanged: (val) => setModal(() => selectedGestorId = val),
                    hint: const Text('Selecionar Gestor'),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (usernameCtrl.text.isEmpty ||
                        nameCtrl.text.isEmpty ||
                        passwordCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Preencha os campos obrigatórios, incluindo senha.')),
                      );
                      return;
                    }

                    final auth = context.read<AuthProvider>();

                    await auth.register({
                      'username': usernameCtrl.text.trim(),
                      'password': passwordCtrl.text.trim(),
                      'name': nameCtrl.text.trim(),
                      'role': selectedRole.name,
                      'functionRole': functionCtrl.text.trim(),
                      'secretary': selectedRole == UserRole.SECRETARY
                          ? secretaryController.text.trim()
                          : null,
                      'managerId': selectedGestorId ??
                          auth.currentUser?.id ??
                          '', // Use selectedGestorId se existir, senão user autal
                    });

                    if (auth.error != null && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(auth.error!),
                            backgroundColor: Colors.red),
                      );
                      return; // Impede fechar a tela porque deu erro no backend
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _load(); // Recarrega a lista de time do zero
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(UserRole r) {
    const labels = {
      UserRole.MANAGER: 'Gerente',
      UserRole.SECRETARY: 'Secretaria',
      UserRole.EMPLOYEE: 'Colaborador',
      UserRole.GESTOR: 'Gestor',
      UserRole.GENERAL_MANAGER: 'Gerente Geral',
    };
    return labels[r] ?? r.name;
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.watch<AuthProvider>().currentUser?.role;
    final isManagerOrSecretary = userRole == UserRole.MANAGER ||
        userRole == UserRole.GESTOR ||
        userRole == UserRole.GENERAL_MANAGER ||
        userRole == UserRole.SECRETARY;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
        title: const Text('Equipe'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      floatingActionButton: isManagerOrSecretary
          ? FloatingActionButton(
              onPressed: () => _showRegisterSheet(context),
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? const Center(child: Text('Nenhum membro na equipe.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (context, i) {
                    final m = _members[i];
                    final isInactive = m.status == UserStatus.INACTIVE;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isInactive
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                          child: Text(
                            m.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          m.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isInactive ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          '@${m.username}'
                          '${m.function != null ? ' · ${m.function}' : ''}',
                        ),
                        trailing: isManagerOrSecretary
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isInactive
                                          ? Colors.grey.shade200
                                          : const Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isInactive ? 'Inativo' : m.roleLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isInactive
                                            ? Colors.grey
                                            : const Color(0xFF2E51A4),
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (v) {
                                      if (v == 'toggle') _toggleStatus(m);
                                      if (v == 'delete') _delete(m);
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          isInactive ? 'Ativar' : 'Inativar',
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          'Remover',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isInactive
                                      ? Colors.grey.shade200
                                      : const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isInactive ? 'Inativo' : m.roleLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E51A4),
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
