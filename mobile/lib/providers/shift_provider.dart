import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class ShiftProvider extends ChangeNotifier {
  final ApiService _api;
  List<ShiftModel> _shifts = [];
  bool _loading = false;

  ShiftProvider(this._api);

  List<ShiftModel> get shifts => _shifts;
  bool get loading => _loading;

  Future<void> loadForManager(String managerId) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getShifts(managerId);
      _shifts = data.map(ShiftModel.fromJson).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } on DioException catch (e) {
      debugPrint('loadForManager shifts error: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(ShiftModel shift) async {
    try {
      final created = await _api.createShift({
        'managerId': shift.managerId,
        'date': shift.date,
        'startTime': shift.startTime,
        'endTime': shift.endTime,
        'employeeIds': shift.employeeIds,
        'observations': shift.observations,
      });
      final model = ShiftModel.fromJson(created);
      _shifts.add(model);
      _shifts.sort((a, b) => a.date.compareTo(b.date));
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('add shift error: ${e.message}');
      rethrow;
    }
  }

  Future<void> update(ShiftModel shift) async {
    try {
      final updated = await _api.updateShift(shift.id, {
        'date': shift.date,
        'startTime': shift.startTime,
        'endTime': shift.endTime,
        'employeeIds': shift.employeeIds,
        'observations': shift.observations,
      });
      final model = ShiftModel.fromJson(updated);
      final listIndex = _shifts.indexWhere((s) => s.id == shift.id);
      if (listIndex >= 0) _shifts[listIndex] = model;
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('update shift error: ${e.message}');
      rethrow;
    }
  }

  Future<ShiftModel> createShift({
    required String managerId,
    required String date,
    String? startTime,
    String? endTime,
    required List<String> employeeIds,
    String? observations,
  }) async {
    final body = {
      'managerId': managerId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'employeeIds': employeeIds,
      'observations': observations,
    };
    final created = await _api.createShift(body);
    final model = ShiftModel.fromJson(created);
    _shifts.add(model);
    _shifts.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    return model;
  }

  Future<void> delete(String id) async {
    try {
      await _api.deleteShift(id);
      _shifts.removeWhere((s) => s.id == id);
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('delete shift error: ${e.message}');
      rethrow;
    }
  }
}
