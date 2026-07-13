import 'package:flutter/material.dart';

class SecuritySetting {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isEnabled;

  SecuritySetting({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isEnabled,
  });

  SecuritySetting copyWith({bool? isEnabled}) {
    return SecuritySetting(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: icon,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
