// ignore_for_file: constant_identifier_names

enum UrgencyLevel { LOW, MEDIUM, HIGH, URGENT }

enum PlanningPeriod { WEEKLY, MONTHLY, ANNUAL, UNPLANNED }

enum ServiceStatus {
  PENDING,
  APPROVED,
  REJECTED,
  IN_PROGRESS,
  COMPLETED,
  CANCELLED,
  RESCHEDULED,
  WAITING_APPROVAL,
}

class PlanningLocation {
  final String address;
  final double? lat;
  final double? lng;

  const PlanningLocation({required this.address, this.lat, this.lng});

  factory PlanningLocation.fromJson(Map<String, dynamic> json) =>
      PlanningLocation(
        address: json['address'] as String,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {'address': address, 'lat': lat, 'lng': lng};
}

class PlanningModel {
  final String id;
  final String managerId;
  final String secretaryId;
  final String department;
  final String serviceType;
  final String date;
  final String time;
  final PlanningLocation location;
  final String description;
  final String? observations;
  final UrgencyLevel urgency;
  final PlanningPeriod period;
  final ServiceStatus status;
  final String? rejectionReason;
  final List<String> responsibleEmployeeIds;
  final String? responsibleSecretaryId;
  final String createdAt;

  const PlanningModel({
    required this.id,
    required this.managerId,
    required this.secretaryId,
    required this.department,
    required this.serviceType,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    this.observations,
    required this.urgency,
    required this.period,
    required this.status,
    this.rejectionReason,
    this.responsibleEmployeeIds = const [],
    this.responsibleSecretaryId,
    required this.createdAt,
  });

  factory PlanningModel.fromJson(Map<String, dynamic> json) => PlanningModel(
    id: json['id'] as String,
    managerId: json['managerId'] as String,
    secretaryId: json['secretaryId'] as String,
    department: json['department'] as String,
    serviceType: json['serviceType'] as String,
    date: json['date'] as String,
    time: json['time'] as String,
    location: PlanningLocation.fromJson(
      json['location'] as Map<String, dynamic>,
    ),
    description: json['description'] as String,
    observations: json['observations'] as String?,
    urgency: UrgencyLevel.values.firstWhere((e) => e.name == json['urgency']),
    period: PlanningPeriod.values.firstWhere((e) => e.name == json['period']),
    status: ServiceStatus.values.firstWhere((e) => e.name == json['status']),
    rejectionReason: json['rejectionReason'] as String?,
    responsibleEmployeeIds:
        (json['responsibleEmployeeIds'] as List<dynamic>?)?.cast<String>() ??
        [],
    responsibleSecretaryId: json['responsibleSecretaryId'] as String?,
    createdAt: json['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'managerId': managerId,
    'secretaryId': secretaryId,
    'department': department,
    'serviceType': serviceType,
    'date': date,
    'time': time,
    'location': location.toJson(),
    'description': description,
    'observations': observations,
    'urgency': urgency.name,
    'period': period.name,
    'status': status.name,
    'rejectionReason': rejectionReason,
    'responsibleEmployeeIds': responsibleEmployeeIds,
    'responsibleSecretaryId': responsibleSecretaryId,
    'createdAt': createdAt,
  };

  PlanningModel copyWith({
    ServiceStatus? status,
    String? rejectionReason,
    List<String>? responsibleEmployeeIds,
  }) => PlanningModel(
    id: id,
    managerId: managerId,
    secretaryId: secretaryId,
    department: department,
    serviceType: serviceType,
    date: date,
    time: time,
    location: location,
    description: description,
    observations: observations,
    urgency: urgency,
    period: period,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    responsibleEmployeeIds:
        responsibleEmployeeIds ?? this.responsibleEmployeeIds,
    responsibleSecretaryId: responsibleSecretaryId,
    createdAt: createdAt,
  );

  String get statusLabel {
    const labels = {
      ServiceStatus.PENDING: 'Pendente',
      ServiceStatus.APPROVED: 'Aprovado',
      ServiceStatus.REJECTED: 'Rejeitado',
      ServiceStatus.IN_PROGRESS: 'Em Andamento',
      ServiceStatus.COMPLETED: 'Concluído',
      ServiceStatus.CANCELLED: 'Cancelado',
      ServiceStatus.RESCHEDULED: 'Reagendado',
      ServiceStatus.WAITING_APPROVAL: 'Aguardando Aprovação',
    };
    return labels[status] ?? status.name;
  }
}
