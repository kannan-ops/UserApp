class SecuritySessionModel {
  final int sessionCode;
  final String operation;
  final int selectedNumber;
  final int calculatedValue;

  SecuritySessionModel({
    required this.sessionCode,
    required this.operation,
    required this.selectedNumber,
    required this.calculatedValue,
  });

  factory SecuritySessionModel.fromJson(Map<String, dynamic> json) {
    return SecuritySessionModel(
      sessionCode: json['session_code'] ?? 0,
      operation: json['operation'] ?? '+',
      selectedNumber: json['selected_number'] ?? 0,
      calculatedValue: json['calculated_value'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_code': sessionCode,
      'operation': operation,
      'selected_number': selectedNumber,
      'calculated_value': calculatedValue,
    };
  }

  @override
  String toString() {
    return 'SecuritySessionModel(sessionCode: $sessionCode, operation: $operation, selectedNumber: $selectedNumber, calculatedValue: $calculatedValue)';
  }
}
