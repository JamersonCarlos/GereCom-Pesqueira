import 'planning_model.dart';

class ServiceModel {
  final String id;
  final String managerId;
  final String planningId;
  final List<String> teamIds;
  final ServiceStatus status;
  final String? executionDate;
  final String? notes;
  final String updatedAt;
  final bool managerConfirmed;
  final String? reason;
  final String? completedBy;

  // Snapshots históricos
  final String? serviceTypeSnapshot;
  final String? secretaryIdSnapshot;
  final String? dateSnapshot;
  final String? timeSnapshot;
  final PlanningLocation? locationSnapshot;
  final String? descriptionSnapshot;
  final String? observationsSnapshot;

  const ServiceModel({
    required this.id,
    required this.managerId,
    required this.planningId,
    required this.teamIds,
    required this.status,
    this.executionDate,
    this.notes,
    required this.updatedAt,
    this.managerConfirmed = false,
    this.reason,
    this.completedBy,
    this.serviceTypeSnapshot,
    this.secretaryIdSnapshot,
    this.dateSnapshot,
    this.timeSnapshot,
    this.locationSnapshot,
    this.descriptionSnapshot,
    this.observationsSnapshot,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
    id: json['id'] as String,
    managerId: json['managerId'] as String,
    planningId: json['planningId'] as String,
    teamIds: (json['teamIds'] as List<dynamic>).cast<String>(),
    status: ServiceStatus.values.firstWhere((e) => e.name == json['status']),
    executionDate: json['executionDate'] as String?,
    notes: json['notes'] as String?,
    updatedAt: json['updatedAt'] as String,
    managerConfirmed: json['managerConfirmed'] as bool? ?? false,
    reason: json['reason'] as String?,
    completedBy: json['completedBy'] as String?,
    serviceTypeSnapshot: json['serviceTypeSnapshot'] as String?,
    secretaryIdSnapshot: json['secretaryIdSnapshot'] as String?,
    dateSnapshot: json['dateSnapshot'] as String?,
    timeSnapshot: json['timeSnapshot'] as String?,
    locationSnapshot: json['locationSnapshot'] != null
        ? PlanningLocation.fromJson(
            json['locationSnapshot'] as Map<String, dynamic>,
          )
        : null,
    descriptionSnapshot: json['descriptionSnapshot'] as String?,
    observationsSnapshot: json['observationsSnapshot'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'managerId': managerId,
    'planningId': planningId,
    'teamIds': teamIds,
    'status': status.name,
    'executionDate': executionDate,
    'notes': notes,
    'updatedAt': updatedAt,
    'managerConfirmed': managerConfirmed,
    'reason': reason,
    'completedBy': completedBy,
    'serviceTypeSnapshot': serviceTypeSnapshot,
    'secretaryIdSnapshot': secretaryIdSnapshot,
    'dateSnapshot': dateSnapshot,
    'timeSnapshot': timeSnapshot,
    'locationSnapshot': locationSnapshot?.toJson(),
    'descriptionSnapshot': descriptionSnapshot,
    'observationsSnapshot': observationsSnapshot,
  };

  ServiceModel copyWith({
    ServiceStatus? status,
    bool? managerConfirmed,
    String? reason,
    String? completedBy,
    String? updatedAt,
    List<String>? teamIds,
  }) => ServiceModel(
    id: id,
    managerId: managerId,
    planningId: planningId,
    teamIds: teamIds ?? this.teamIds,
    status: status ?? this.status,
    executionDate: executionDate,
    notes: notes,
    updatedAt: updatedAt ?? this.updatedAt,
    managerConfirmed: managerConfirmed ?? this.managerConfirmed,
    reason: reason ?? this.reason,
    completedBy: completedBy ?? this.completedBy,
    serviceTypeSnapshot: serviceTypeSnapshot,
    secretaryIdSnapshot: secretaryIdSnapshot,
    dateSnapshot: dateSnapshot,
    timeSnapshot: timeSnapshot,
    locationSnapshot: locationSnapshot,
    descriptionSnapshot: descriptionSnapshot,
    observationsSnapshot: observationsSnapshot,
  );

  String get displayName => serviceTypeSnapshot ?? 'Serviço';
}
