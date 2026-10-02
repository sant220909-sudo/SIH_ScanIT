import 'package:cyber_nova/models/inspection_model.dart';

class InspectionSession {
  InspectionSession._();
  static final InspectionSession instance = InspectionSession._();

  InspectionModel? current;

  void save(InspectionModel inspection) {
    current = inspection;
  }

  void clear() {
    current = null;
  }
}
