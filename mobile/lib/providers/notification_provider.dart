import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  List<NotificationModel> _notifications = [];

  NotificationProvider(this._api);

  List<NotificationModel> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> loadForUser(String userId, String managerId) async {
    try {
      final data = await _api.getNotifications(userId);
      _notifications = data
          .map(NotificationModel.fromJson)
          .where((n) => n.managerId == null || n.managerId == managerId)
          .toList();
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('loadForUser notifications error: ${e.message}');
    }
  }

  Future<void> add(NotificationModel notification) async {
    try {
      final created = await _api.createNotification(notification.toJson());
      final model = NotificationModel.fromJson(created);
      if (_notifications.isEmpty ||
          _notifications.first.userId == model.userId) {
        _notifications.insert(0, model);
        notifyListeners();
      }
    } on DioException catch (e) {
      debugPrint('add notification error: ${e.message}');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0) return;
    try {
      await _api.markNotificationRead(id);
      _notifications[index] = _notifications[index].copyWith(read: true);
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('markAsRead error: ${e.message}');
    }
  }

  Future<void> markAllAsRead(String userId, String managerId) async {
    try {
      await _api.markAllNotificationsRead(userId);
      _notifications =
          _notifications.map((n) => n.copyWith(read: true)).toList();
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('markAllAsRead error: ${e.message}');
    }
  }
}
