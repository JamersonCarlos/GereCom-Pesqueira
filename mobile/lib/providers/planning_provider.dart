import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'notification_provider.dart';

class PlanningProvider extends ChangeNotifier {
  final ApiService _api;
  List<PlanningModel> _plannings = [];
  bool _loading = false;

  PlanningProvider(this._api);

  List<PlanningModel> get plannings => _plannings;
  bool get loading => _loading;

  Future<void> loadForManager(String managerId) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getPlannings(managerId);
      _plannings = data.map(PlanningModel.fromJson).toList();
    } on DioException catch (e) {
      debugPrint('loadForManager error: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(
    PlanningModel planning,
    NotificationProvider notifCtrl,
  ) async {
    try {
      final created = await _api.createPlanning(planning.toJson());
      _plannings.insert(0, PlanningModel.fromJson(created));

      await notifCtrl.add(
        NotificationModel(
          id: planning.id,
          userId: planning.managerId,
          managerId: planning.managerId,
          title: 'Novo Planejamento',
          message:
              '${planning.department ?? planning.serviceType} enviou um novo planejamento para ${planning.serviceType}.',
          createdAt: DateTime.now().toIso8601String(),
          type: NotificationType.service,
          relatedId: planning.id,
        ),
      );

      notifyListeners();
    } on DioException catch (e) {
      debugPrint('add planning error: ${e.message}');
      rethrow;
    }
  }

  Future<void> updateStatus(
    String id,
    ServiceStatus status, {
    String? rejectionReason,
    NotificationProvider? notifCtrl,
  }) async {
    try {
      final updated = await _api.updatePlanningStatus(
        id,
        status.name,
        rejectionReason: rejectionReason,
      );
      final model = PlanningModel.fromJson(updated);
      final listIndex = _plannings.indexWhere((p) => p.id == id);
      if (listIndex >= 0) _plannings[listIndex] = model;

      if (notifCtrl != null && model.secretaryId != null) {
        final action = status == ServiceStatus.APPROVED
            ? 'aprovado'
            : status == ServiceStatus.REJECTED
                ? 'rejeitado'
                : 'atualizado';
        await notifCtrl.add(
          NotificationModel(
            id: id,
            userId: model.secretaryId!,
            managerId: model.managerId,
            title: 'Status do Planejamento Atualizado',
            message: 'Seu planejamento para ${model.serviceType} foi $action.',
            createdAt: DateTime.now().toIso8601String(),
            type: NotificationType.service,
            relatedId: model.id,
          ),
        );
      }

      notifyListeners();
    } on DioException catch (e) {
      debugPrint('updateStatus planning error: ${e.message}');
      rethrow;
    }
  }

  Future<void> update(PlanningModel planning) async {
    try {
      final updated = await _api.updatePlanning(planning.id, planning.toJson());
      final model = PlanningModel.fromJson(updated);
      final listIndex = _plannings.indexWhere((p) => p.id == planning.id);
      if (listIndex >= 0) _plannings[listIndex] = model;
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('update planning error: ${e.message}');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _api.deletePlanning(id);
      _plannings.removeWhere((p) => p.id == id);
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('delete planning error: ${e.message}');
      rethrow;
    }
  }

  PlanningModel? getById(String id) {
    try {
      return _plannings.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
