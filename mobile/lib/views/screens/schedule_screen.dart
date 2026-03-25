import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/shift_controller.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shifts = context.watch<ShiftController>().shifts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escalas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: shifts.isEmpty
          ? const Center(child: Text('Nenhuma escala cadastrada.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shifts.length,
              itemBuilder: (context, i) {
                final s = shifts[i];
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
                        Text(
                          s.date,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (s.observations != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              s.observations!,
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
                        ...s.employeeIds.map(
                          (id) => FutureBuilder(
                            future: context
                                .read<AuthController>()
                                .getAllUsers()
                                .then(
                                  (users) => users
                                      .firstWhere(
                                        (u) => u.id == id,
                                        orElse: () => users.first,
                                      )
                                      .name,
                                ),
                            builder: (_, snap) => Text(
                              '· ${snap.data ?? id}',
                              style: const TextStyle(fontSize: 14),
                            ),
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
}
