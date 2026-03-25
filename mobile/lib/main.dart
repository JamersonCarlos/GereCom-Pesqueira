import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/planning_controller.dart';
import 'controllers/service_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/shift_controller.dart';
import 'services/api_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService();
  await api.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(api)),
        ChangeNotifierProvider(create: (_) => PlanningController(api)),
        ChangeNotifierProvider(create: (_) => ServiceController(api)),
        ChangeNotifierProvider(create: (_) => NotificationController(api)),
        ChangeNotifierProvider(create: (_) => ShiftController(api)),
      ],
      child: const GereComApp(),
    ),
  );
}
