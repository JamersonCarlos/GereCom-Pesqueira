import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  UserModel? _currentUser;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api) {
    _init();
  }

  UserModel? get currentUser => _currentUser;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  /// Retorna o managerId efectivo para filtrar dados da API.
  /// Para MANAGER retorna o próprio id; para outros retorna o managerId.
  String? get managerId {
    if (_currentUser == null) return null;
    return (_currentUser!.role == UserRole.MANAGER ||
            _currentUser!.role == UserRole.GESTOR ||
            _currentUser!.role == UserRole.GENERAL_MANAGER ||
            _currentUser!.role == UserRole.SECRETARY)
        ? _currentUser!.id
        : _currentUser!.managerId;
  }

  Future<void> _init() async {
    try {
      final userData = await _api.getMe();
      _currentUser = UserModel.fromJson(userData);
      notifyListeners();
    } catch (_) {
      // Token inválido ou expirado — exibe tela de login
    }
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.login(username, password);
      _currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Erro ao conectar ao servidor.';
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> register(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.register(data);
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Erro ao registrar usuário.';
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    if (_currentUser == null) return;
    try {
      final updated = await _api.updateProfile({
        'name': name ?? _currentUser!.name,
        'email': email ?? _currentUser!.email,
        'phone': phone ?? _currentUser!.phone,
      });
      _currentUser = UserModel.fromJson(updated);
      notifyListeners();
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Erro ao atualizar perfil.';
      notifyListeners();
    }
  }

  Future<List<UserModel>> getTeamMembers(String managerId) async {
    final list = await _api.getTeamMembers(managerId);
    return list.map(UserModel.fromJson).toList();
  }

  Future<List<UserModel>> getAllUsers() async {
    final list = await _api.getAllUsers();
    return list.map(UserModel.fromJson).toList();
  }

  Future<UserModel> updateUser(
    String id,
    Map<String, dynamic> data,
  ) async {
    final updated = await _api.updateUser(id, data);
    return UserModel.fromJson(updated);
  }

  Future<UserModel> setUserStatus(String id, UserStatus status) async {
    final updated = await _api.updateUserStatus(id, status.name);
    final model = UserModel.fromJson(updated);
    notifyListeners();
    return model;
  }

  Future<void> deleteUser(String id) async {
    await _api.deleteUser(id);
    notifyListeners();
  }

  Future<void> forgotPassword(String email) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.forgotPassword(email);
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Erro ao enviar e-mail.';
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(
      String email, String code, String newPassword) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.resetPassword(email, code, newPassword);
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Erro ao redefinir senha.';
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _api.changePassword(currentPassword, newPassword);
      _currentUser = UserModel.fromJson(updated);
      return true;
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Erro ao alterar senha.';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
