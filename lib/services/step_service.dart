import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class StepService {
  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _stepStatusStream;

  // Initialize and check permissions
  Future<bool> init() async {
    // Request permission
    var status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      return true;
    } else {
      // On some Android versions, it might be 'sensors'
      var sensorStatus = await Permission.sensors.request();
      return sensorStatus.isGranted;
    }
  }

  Stream<StepCount> get stepStream {
    _stepCountStream ??= Pedometer.stepCountStream;
    return _stepCountStream!;
  }

  Stream<PedestrianStatus> get statusStream {
    _stepStatusStream ??= Pedometer.pedestrianStatusStream;
    return _stepStatusStream!;
  }
}