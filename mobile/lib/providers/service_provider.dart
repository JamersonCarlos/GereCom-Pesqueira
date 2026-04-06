import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'notification_provider.dart';
import 'planning_provider.dart';

class ServiceProvider extends ChangeNotifier {
  final ApiService _api;
  List<ServiceModel> _services = [];
  bool _loading = false;

  ServiceProvider(this._api);

  List<ServiceModel> get services => _services;
  bool get loading => _loading;

  // Added createServiceDirectly for standalone Services without Planning
  Future<void> createServiceDirectly(
    Map<String, dynamic> data,
    NotificationProvider notifCtrl,
    String currentUserId,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      final created = await _api.createService(data);
      final service = ServiceModel.fromJson(created);
      _services.insert(0, service);

      // Notify every team member of the new assignment
      final teamIds = List<String>.from(data['teamIds'] as List? ?? []);
      final managerId = data['managerId'] as String? ?? currentUserId;
      final typeName = data['serviceTypeSnapshot'] as String? ?? 'Novo Serviço';
      final dateStr = data['dateSnapshot'] as String? ?? '';
      final timeStr = data['timeSnapshot'] as String? ?? '';
      final location = data['locationSnapshot'] as Map<String, dynamic>?;
      final addressStr = location?['address'] as String? ?? '';

      String msgDate = '';
      if (dateStr.isNotEmpty) {
        try {
          final dt = DateTime.parse(dateStr);
          msgDate =
              '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        } catch (_) {
          msgDate = dateStr;
        }
      }

      final msgLines = [
        '📋 Serviço: $typeName',
        if (msgDate.isNotEmpty)
          '📅 Data: $msgDate${timeStr.isNotEmpty ? ' às $timeStr' : ''}',
        if (addressStr.isNotEmpty) '📍 Local: $addressStr',
        '⚡ Status: Em Andamento',
      ];

      for (final tid in teamIds) {
        await notifCtrl.add(
          NotificationModel(
            id: const Uuid().v4(),
            userId: tid,
            managerId: managerId,
            title: '🔔 Novo Serviço Designado',
            message: msgLines.join('\n'),
            createdAt: DateTime.now().toIso8601String(),
            type: NotificationType.service,
            relatedId: service.id,
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint('createServiceDirectly error: ${e.message}');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForManager(String managerId) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getServices(managerId);
      _services = data.map(ServiceModel.fromJson).toList();
    } on DioException catch (e) {
      debugPrint('loadForManager services error: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForEmployee(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getServicesForEmployee(userId);
      _services = data.map(ServiceModel.fromJson).toList();
    } on DioException catch (e) {
      debugPrint('loadForEmployee services error: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getAllServices();
      _services = data.map(ServiceModel.fromJson).toList();
    } on DioException catch (e) {
      debugPrint('loadAll services error: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> create(
    String planningId,
    List<String> teamIds,
    String managerId,
    PlanningProvider planningCtrl,
    NotificationProvider notifCtrl,
  ) async {
    final planning = planningCtrl.getById(planningId);
    if (planning == null) return;

    try {
      final body = {
        'managerId': managerId,
        'createdById': managerId,
        'planningId': planningId,
        'teamIds': teamIds,
        'status': ServiceStatus.IN_PROGRESS.name,
        'serviceTypeSnapshot': planning.serviceType,
        'departmentSnapshot': planning.department,
        'dateSnapshot': planning.date,
        'timeSnapshot': planning.time,
        'secretaryIdSnapshot': planning.secretaryId,
        'locationSnapshot': planning.location?.toJson(),
        'descriptionSnapshot': planning.description,
        'observationsSnapshot': planning.observations,
      };

      final created = await _api.createService(body);
      final service = ServiceModel.fromJson(created);
      _services.add(service);

      await planningCtrl.updateStatus(
        planningId,
        ServiceStatus.APPROVED,
        notifCtrl: notifCtrl,
      );

      for (final tid in teamIds) {
        await notifCtrl.add(
          NotificationModel(
            id: service.id,
            userId: tid,
            managerId: managerId,
            title: 'Novo Serviço Atribuído',
            message: 'Novo serviço: ${planning.serviceType} – ${planning.date}'
                '${planning.time != null ? ' às ${planning.time}' : ''}.',
            createdAt: DateTime.now().toIso8601String(),
            type: NotificationType.service,
            relatedId: service.id,
          ),
        );
      }

      notifyListeners();
    } on DioException catch (e) {
      debugPrint('create service error: ${e.message}');
      rethrow;
    }
  }

  Future<void> updateService(
    String id,
    Map<String, dynamic> data,
    NotificationProvider notifCtrl,
    String currentUserId,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      final updated = await _api.updateService(id, data);
      final model = ServiceModel.fromJson(updated);
      final index = _services.indexWhere((s) => s.id == id);
      if (index >= 0) {
        _services[index] = model;
      }

      // Notify team members about the update
      final teamIds = model.teamIds;
      final managerId = model.managerId;
      final typeName = model.serviceTypeSnapshot ?? 'Serviço';

      for (final tid in teamIds) {
        await notifCtrl.add(
          NotificationModel(
            id: const Uuid().v4(),
            userId: tid,
            managerId: managerId,
            title: '✏️ Serviço Atualizado',
            message: 'O serviço "$typeName" foi atualizado pelo gestor.',
            createdAt: DateTime.now().toIso8601String(),
            type: NotificationType.service,
            relatedId: id,
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint('updateService error: ${e.message}');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(
    String id,
    ServiceStatus status,
    String currentUserId,
    String managerId,
    NotificationProvider notifCtrl,
    PlanningProvider planningCtrl, {
    String? reason,
  }) async {
    final index = _services.indexWhere((s) => s.id == id);
    if (index < 0) return;

    try {
      final body = {
        'status': status.name,
        'reason': reason,
        'completedBy':
            status == ServiceStatus.WAITING_APPROVAL ? currentUserId : null,
        'managerConfirmed': false,
      };

      final updated = await _api.updateServiceStatus(id, body);
      final model = ServiceModel.fromJson(updated);
      _services[index] = model;

      final planning = model.planningId != null
          ? planningCtrl.getById(model.planningId!)
          : null;
      final typeName =
          planning?.serviceType ?? model.serviceTypeSnapshot ?? 'Serviço';
      if (planning != null || model.serviceTypeSnapshot != null) {
        String title = 'Status de Serviço Atualizado';
        String message =
            "O serviço '$typeName' foi marcado como ${status.name}.";

        if (status == ServiceStatus.WAITING_APPROVAL) {
          title = 'Serviço Concluído (Aguardando Aprovação)';
          message = "O serviço '$typeName' aguarda confirmação do gerente.";
        } else if (status == ServiceStatus.CANCELLED) {
          title = 'Serviço Cancelado';
          message = "O serviço '$typeName' foi cancelado. Motivo: $reason";
        } else if (status == ServiceStatus.RESCHEDULED) {
          title = 'Serviço Reagendado';
          message = "O serviço '$typeName' foi reagendado. Motivo: $reason";
        }

        await notifCtrl.add(
          NotificationModel(
            id: id,
            userId: managerId,
            managerId: managerId,
            title: title,
            message: message,
            createdAt: DateTime.now().toIso8601String(),
            type: NotificationType.service,
            relatedId: id,
          ),
        );
      }

      notifyListeners();
    } on DioException catch (e) {
      debugPrint('updateStatus service error: ${e.message}');
      rethrow;
    }
  }

  Future<void> confirmCompletion(
    String id,
    String managerId,
    NotificationProvider notifCtrl,
    PlanningProvider planningCtrl,
  ) async {
    final index = _services.indexWhere((s) => s.id == id);
    if (index < 0) return;

    try {
      final body = {
        'status': ServiceStatus.COMPLETED.name,
        'managerConfirmed': true,
      };

      final updated = await _api.updateServiceStatus(id, body);
      final model = ServiceModel.fromJson(updated);
      _services[index] = model;

      final planning = model.planningId != null
          ? planningCtrl.getById(model.planningId!)
          : null;
      final typeName =
          planning?.serviceType ?? model.serviceTypeSnapshot ?? 'Serviço';
      if (planning != null || model.serviceTypeSnapshot != null) {
        for (final tid in model.teamIds) {
          await notifCtrl.add(
            NotificationModel(
              id: id,
              userId: tid,
              managerId: managerId,
              title: 'Serviço Confirmado',
              message: 'O gerente confirmou a conclusão do serviço $typeName.',
              createdAt: DateTime.now().toIso8601String(),
              type: NotificationType.service,
              relatedId: id,
            ),
          );
        }
      }

      notifyListeners();
    } on DioException catch (e) {
      debugPrint('confirmCompletion error: ${e.message}');
      rethrow;
    }
  }

  Future<void> requestReview(
    String id,
    String managerId,
    NotificationProvider notifCtrl,
    PlanningProvider planningCtrl,
  ) async {
    final index = _services.indexWhere((s) => s.id == id);
    if (index < 0) return;

    try {
      final body = {
        'status': ServiceStatus.IN_PROGRESS.name,
        'managerConfirmed': false,
      };

      final updated = await _api.updateServiceStatus(id, body);
      final model = ServiceModel.fromJson(updated);
      _services[index] = model;

      final planning = model.planningId != null
          ? planningCtrl.getById(model.planningId!)
          : null;
      if (planning != null) {
        for (final tid in model.teamIds) {
          await notifCtrl.add(
            NotificationModel(
              id: id,
              userId: tid,
              managerId: managerId,
              title: 'Revisão Solicitada',
              message:
                  'O gerente solicitou revisão do serviço ${planning.serviceType}.',
              createdAt: DateTime.now().toIso8601String(),
              type: NotificationType.service,
              relatedId: id,
            ),
          );
        }
      }

      notifyListeners();
    } on DioException catch (e) {
      debugPrint('requestReview error: ${e.message}');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _api.deleteService(id);
      _services.removeWhere((s) => s.id == id);
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('delete service error: ${e.message}');
      rethrow;
    }
  }

  ServiceModel? getById(String id) {
    try {
      return _services.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
