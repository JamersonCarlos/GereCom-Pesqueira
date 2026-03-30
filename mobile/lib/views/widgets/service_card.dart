import 'package:flutter/material.dart';
import '../../models/models.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final UserModel user;

  const ServiceCard({super.key, required this.service, required this.user});

  Future<void> _openMap() async {
    final addr = service.locationSnapshot?.address;
    if (addr == null || addr.isEmpty) return;
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service.serviceTypeSnapshot ?? 'Serviço s/ Tipo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Chip(
                  label: Text(
                    service.status.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (service.locationSnapshot?.address != null)
              InkWell(
                onTap: _openMap,
                child: Row(
                  children: [
                     const Icon(Icons.location_on, color: Colors.blue, size: 16),
                     const SizedBox(width: 4),
                     Expanded(
                        child: Text(
                          service.locationSnapshot!.address!,
                          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                     ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('Data: ${service.dateSnapshot ?? '-'} | Hora: ${service.timeSnapshot ?? '-'}'),
            const SizedBox(height: 4),
            Text('Departamento: ${service.departmentSnapshot ?? '-'}'),
            if (service.teamIds != null && service.teamIds!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Operadores alocados: ${service.teamIds!.length}', style: const TextStyle(color: Colors.grey)),
            ]
          ],
        ),
      ),
    );
  }
}
