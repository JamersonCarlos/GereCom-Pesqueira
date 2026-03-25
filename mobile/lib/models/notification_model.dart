// ignore_for_file: constant_identifier_names

enum NotificationType { service, schedule, general }

class NotificationModel {
  final String id;
  final String userId;
  final String managerId;
  final String title;
  final String message;
  final bool read;
  final String createdAt;
  final NotificationType type;
  final String? relatedId;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.managerId,
    required this.title,
    required this.message,
    this.read = false,
    required this.createdAt,
    this.type = NotificationType.general,
    this.relatedId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        managerId: json['managerId'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        read: json['read'] as bool? ?? false,
        createdAt: json['createdAt'] as String,
        type: json['type'] != null
            ? NotificationType.values.firstWhere(
                (e) => e.name == json['type'],
                orElse: () => NotificationType.general,
              )
            : NotificationType.general,
        relatedId: json['relatedId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'managerId': managerId,
    'title': title,
    'message': message,
    'read': read,
    'createdAt': createdAt,
    'type': type.name,
    'relatedId': relatedId,
  };

  NotificationModel copyWith({bool? read}) => NotificationModel(
    id: id,
    userId: userId,
    managerId: managerId,
    title: title,
    message: message,
    read: read ?? this.read,
    createdAt: createdAt,
    type: type,
    relatedId: relatedId,
  );
}
