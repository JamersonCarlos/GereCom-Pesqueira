class ShiftModel {
  final String id;
  final String managerId;
  final String date;
  final List<String> employeeIds;
  final String? observations;
  final String createdAt;
  final bool notifyEmployees;

  const ShiftModel({
    required this.id,
    required this.managerId,
    required this.date,
    required this.employeeIds,
    this.observations,
    required this.createdAt,
    this.notifyEmployees = false,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) => ShiftModel(
    id: json['id'] as String,
    managerId: json['managerId'] as String,
    date: json['date'] as String,
    employeeIds: (json['employeeIds'] as List<dynamic>).cast<String>(),
    observations: json['observations'] as String?,
    createdAt: json['createdAt'] as String,
    notifyEmployees: json['notifyEmployees'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'managerId': managerId,
    'date': date,
    'employeeIds': employeeIds,
    'observations': observations,
    'createdAt': createdAt,
    'notifyEmployees': notifyEmployees,
  };
}
