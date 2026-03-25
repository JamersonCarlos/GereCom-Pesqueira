// ignore_for_file: constant_identifier_names

enum UserRole { SECRETARY, MANAGER, EMPLOYEE, GESTOR, GENERAL_MANAGER }

enum UserStatus { ACTIVE, INACTIVE }

class UserModel {
  final String id;
  final String username;
  final String? password;
  final String name;
  final UserRole role;
  final String? managerId;
  final String? generalManagerId;
  final String? department;
  final String? function;
  final UserStatus status;
  final String? email;
  final String? phone;
  final String createdAt;

  const UserModel({
    required this.id,
    required this.username,
    this.password,
    required this.name,
    required this.role,
    this.managerId,
    this.generalManagerId,
    this.department,
    this.function,
    this.status = UserStatus.ACTIVE,
    this.email,
    this.phone,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    username: json['username'] as String,
    password: json['password'] as String?,
    name: json['name'] as String,
    role: UserRole.values.firstWhere((e) => e.name == json['role']),
    managerId: json['managerId'] as String?,
    generalManagerId: json['generalManagerId'] as String?,
    department: json['department'] as String?,
    function: json['function'] as String?,
    status: json['status'] != null
        ? UserStatus.values.firstWhere((e) => e.name == json['status'])
        : UserStatus.ACTIVE,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    createdAt: json['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password': password,
    'name': name,
    'role': role.name,
    'managerId': managerId,
    'generalManagerId': generalManagerId,
    'department': department,
    'function': function,
    'status': status.name,
    'email': email,
    'phone': phone,
    'createdAt': createdAt,
  };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? department,
    String? function,
    UserStatus? status,
    String? password,
  }) => UserModel(
    id: id,
    username: username,
    password: password ?? this.password,
    name: name ?? this.name,
    role: role,
    managerId: managerId,
    generalManagerId: generalManagerId,
    department: department ?? this.department,
    function: function ?? this.function,
    status: status ?? this.status,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    createdAt: createdAt,
  );

  String get roleLabel {
    const labels = {
      UserRole.MANAGER: 'Gerente',
      UserRole.SECRETARY: 'Secretaria',
      UserRole.EMPLOYEE: 'Colaborador',
      UserRole.GESTOR: 'Gestor',
      UserRole.GENERAL_MANAGER: 'Gerente Geral',
    };
    return labels[role] ?? role.name;
  }
}
