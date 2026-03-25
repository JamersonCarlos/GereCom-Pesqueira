import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  final ApiService _api;
  UserModel? _currentUser;
  bool _loading = false;
  String? _error;

  AuthController(this._api) {
    _init();
  }

  UserModel? get currentUser => _currentUser;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  String? get managerId {
    if (_currentUser == null) return null;
    return _currentUser!.role == UserRole.MANAGER
        ? _currentUser!.id
        : _currentUser!.managerId;
  }

  Future<void> _init() async {
    // Tenta restaurar sessão com o token salvo
    try {
      final userData = await _api.getMe();
      _currentUser = UserModel.fromJson(userData);
      notifyListeners();
    } catch (_) {
      // Token inválido ou expirado — ignora e exibe tela de login
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
}
