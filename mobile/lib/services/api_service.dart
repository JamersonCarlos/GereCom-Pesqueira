import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Endereço base da API.
/// 10.0.2.2 é o host do emulador Android apontando para localhost da máquina.
const String _baseUrl = 'http://10.0.2.2:3000/api';
const String _tokenKey = 'gerecom_token';

class ApiService {
  late final Dio _dio;
  SharedPreferences? _prefs;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          final msg =
              e.response?.data?['error'] ?? e.message ?? 'Erro de conexão.';
          handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: msg,
              type: e.type,
              response: e.response,
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Token
  // ──────────────────────────────────────────────

  Future<void> _loadToken() async {
    _prefs ??= await SharedPreferences.getInstance();
    final token = _prefs!.getString(_tokenKey);
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<void> saveToken(String token) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_tokenKey, token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> clearToken() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_tokenKey);
    _dio.options.headers.remove('Authorization');
  }

  Future<void> init() async {
    await _loadToken();
  }

  // ──────────────────────────────────────────────
  // Auth
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    await saveToken(res.data['token'] as String);
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await clearToken();
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final res = await _dio.post('/auth/register', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _dio.put('/auth/profile', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data as Map<String, dynamic>;
  }

  // ──────────────────────────────────────────────
  // Usuários
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final res = await _dio.get('/users');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(String managerId) async {
    final res = await _dio.get('/users/team/$managerId');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  // ──────────────────────────────────────────────
  // Planejamentos
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPlannings(String managerId) async {
    final res =
        await _dio.get('/plannings', queryParameters: {'managerId': managerId});
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<Map<String, dynamic>> createPlanning(Map<String, dynamic> data) async {
    final res = await _dio.post('/plannings', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePlanningStatus(
    String id,
    String status, {
    String? rejectionReason,
  }) async {
    final res = await _dio.patch('/plannings/$id/status', data: {
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePlanning(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _dio.put('/plannings/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deletePlanning(String id) async {
    await _dio.delete('/plannings/$id');
  }

  // ──────────────────────────────────────────────
  // Serviços
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getServices(String managerId) async {
    final res =
        await _dio.get('/services', queryParameters: {'managerId': managerId});
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<Map<String, dynamic>> createService(Map<String, dynamic> data) async {
    final res = await _dio.post('/services', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateServiceStatus(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.patch('/services/$id/status', data: body);
    return res.data as Map<String, dynamic>;
  }

  // ──────────────────────────────────────────────
  // Notificações
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final res =
        await _dio.get('/notifications', queryParameters: {'userId': userId});
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<Map<String, dynamic>> createNotification(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/notifications', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _dio
        .patch('/notifications/read-all', queryParameters: {'userId': userId});
  }

  // ──────────────────────────────────────────────
  // Escalas
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getShifts(String managerId) async {
    final res =
        await _dio.get('/shifts', queryParameters: {'managerId': managerId});
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<Map<String, dynamic>> createShift(Map<String, dynamic> data) async {
    final res = await _dio.post('/shifts', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateShift(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _dio.put('/shifts/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteShift(String id) async {
    await _dio.delete('/shifts/$id');
  }
}
