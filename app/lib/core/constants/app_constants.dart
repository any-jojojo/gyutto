import 'package:flutter/material.dart';

class AppConstants {
  const AppConstants._();

  static const appName = 'ぎゅっと';
  static const logoAssetPath = 'assets/images/gyutto_logo.png';
  static const inviteValidityDuration = Duration(hours: 1);
  static const seedColor = Color(0xFF8BD8F7);
  static const inkColor = Color(0xFF143458);
  static const warmColor = Color(0xFFFFD9C7);
  static const kindnessColor = Color(0xFFFFE9D1);
  static const trustColor = Color(0xFFDCEFFF);
  static const connectionColor = Color(0xFFB8D8F7);
  static const hopeColor = Color(0xFFE6EFFF);

  static const softFamilyGradient = [
    warmColor,
    kindnessColor,
    trustColor,
    connectionColor,
  ];
}
