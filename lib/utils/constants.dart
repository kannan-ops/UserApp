import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'CircuitPoint';
  static const String appSubtitle = 'Intelligent Inquiry & Lead Management';

  static const Color accentColor = Color(0xFF10B981);

  static const double tabletBreakpoint = 600.0;

  static final BorderRadius cardBorderRadius = BorderRadius.circular(24.0);
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(16.0);
  static final BorderRadius inputBorderRadius = BorderRadius.circular(16.0);

  static const LinearGradient primaryPurpleGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Colors.white10, Colors.white30],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const EdgeInsets screenPadding = EdgeInsets.all(20.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);

  static const List<String> profileRoles = [
    'Principal Security Lead',
    'Lead Security Analyst',
    'System Administrator',
    'Senior DevSecOps Architect',
    'Guest User',
  ];

  static const List<String> profileLocations = [
    'San Francisco, CA',
    'New York, NY',
    'London, UK',
    'Tokyo, Japan',
    'Berlin, Germany',
    'Remote Space',
  ];

  static const List<String> availableLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Japanese',
    'Mandarin',
  ];

  static const List<String> avatarOptions = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=200',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=200',
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=200',
  ];
}
