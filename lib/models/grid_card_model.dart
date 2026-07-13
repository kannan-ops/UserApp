class GridCardModel {
  final String userMainId;
  final String cardSerialNumber;
  final Map<String, String> gridData;

  GridCardModel({
    required this.userMainId,
    required this.cardSerialNumber,
    required this.gridData,
  });

  factory GridCardModel.fromJson(Map<String, dynamic> json) {
    final root = json['data'] ?? json;
    final data = root['data'] ?? root;

    final gridRaw = data['grid_data'] as Map? ?? {};
    final Map<String, String> parsedGrid = {};
    gridRaw.forEach((k, v) {
      parsedGrid[k.toString()] = v.toString();
    });

    return GridCardModel(
      userMainId: (data['user_main_id'] ?? '').toString(),
      cardSerialNumber: (data['card_serial_number'] ?? '').toString(),
      gridData: parsedGrid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "user_main_id": userMainId,
      "card_serial_number": cardSerialNumber,
      "grid_data": gridData,
    };
  }
}
