import 'package:flutter/material.dart';

/// Stadium, ball and kit catalogs for Penalty Kick.
///
/// Every theme stays inside a real-stadium material world: grass pitches,
/// floodlit night skies, painted lines, netting, wooden/rubber seats.
/// No neon, no cyberpunk — the variety comes from time of day, weather,
/// venue character and kit colors.
class StadiumThemeDef {
  final String id;
  final String name;
  final bool isPro;
  final Color skyTop;
  final Color skyBottom;
  final Color standDark;
  final Color standLight;
  final Color grassLight;
  final Color grassDark;
  final Color lineColor;
  final Color netColor;
  final Color postColor;
  final Color accent;
  final Color panel;
  final Color panelDark;
  final Color textOn;
  final Color textDim;

  const StadiumThemeDef({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.skyTop,
    required this.skyBottom,
    required this.standDark,
    required this.standLight,
    required this.grassLight,
    required this.grassDark,
    required this.lineColor,
    required this.netColor,
    required this.postColor,
    required this.accent,
    required this.panel,
    required this.panelDark,
    required this.textOn,
    required this.textDim,
  });
}

class StadiumThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'daybreak',
    'sunset',
    'rainy',
    'grassroots',
  ];

  static const List<StadiumThemeDef> all = [
    StadiumThemeDef(
      id: 'daybreak',
      name: 'Daybreak Arena',
      skyTop: Color(0xFF6FA8DC),
      skyBottom: Color(0xFFDCECF7),
      standDark: Color(0xFF3A5A8C),
      standLight: Color(0xFF6E93C2),
      grassLight: Color(0xFF4E9A3D),
      grassDark: Color(0xFF3A7A2C),
      lineColor: Color(0xFFF4F7EF),
      netColor: Color(0xFFD9DEE2),
      postColor: Color(0xFFF8FAFC),
      accent: Color(0xFFE07A2B),
      panel: Color(0xFFF4EFE3),
      panelDark: Color(0xFF2E4A66),
      textOn: Color(0xFF20344C),
      textDim: Color(0xFF7C8DA0),
    ),
    StadiumThemeDef(
      id: 'sunset',
      name: 'Sunset Final',
      skyTop: Color(0xFF4A3A7A),
      skyBottom: Color(0xFFF0925A),
      standDark: Color(0xFF5A3A4A),
      standLight: Color(0xFF9A6A6A),
      grassLight: Color(0xFF5A9A3A),
      grassDark: Color(0xFF3E7028),
      lineColor: Color(0xFFF7F0E4),
      netColor: Color(0xFFE4DCCF),
      postColor: Color(0xFFFBF6EC),
      accent: Color(0xFFE07A2B),
      panel: Color(0xFFF6EBDA),
      panelDark: Color(0xFF4A3A5A),
      textOn: Color(0xFF3A2E4A),
      textDim: Color(0xFF9A8A9A),
    ),
    StadiumThemeDef(
      id: 'rainy',
      name: 'Rainy Derby',
      skyTop: Color(0xFF5A6A7A),
      skyBottom: Color(0xFFAAB4BC),
      standDark: Color(0xFF3E4A54),
      standLight: Color(0xFF6A7A88),
      grassLight: Color(0xFF3E8A34),
      grassDark: Color(0xFF2C6624),
      lineColor: Color(0xFFF2F5F0),
      netColor: Color(0xFFD2D8DC),
      postColor: Color(0xFFF4F8FA),
      accent: Color(0xFF3E8AC9),
      panel: Color(0xFFEDF2F4),
      panelDark: Color(0xFF3E4A54),
      textOn: Color(0xFF2E3A44),
      textDim: Color(0xFF7A8A96),
    ),
    StadiumThemeDef(
      id: 'grassroots',
      name: 'Grassroots Park',
      skyTop: Color(0xFF7AB8E0),
      skyBottom: Color(0xFFE8F4FA),
      standDark: Color(0xFF6A7A52),
      standLight: Color(0xFF9AA87E),
      grassLight: Color(0xFF5FA844),
      grassDark: Color(0xFF47802F),
      lineColor: Color(0xFFFFFFFF),
      netColor: Color(0xFFE2E6E8),
      postColor: Color(0xFFFFFFFF),
      accent: Color(0xFF5A8A2B),
      panel: Color(0xFFF6F3E8),
      panelDark: Color(0xFF4A5A3A),
      textOn: Color(0xFF2E4428),
      textDim: Color(0xFF7A8A6E),
    ),
    StadiumThemeDef(
      id: 'nightmatch',
      name: 'Floodlit Night',
      isPro: true,
      skyTop: Color(0xFF0E1A3A),
      skyBottom: Color(0xFF2A3E6A),
      standDark: Color(0xFF1A2440),
      standLight: Color(0xFF3A4E78),
      grassLight: Color(0xFF3E8A34),
      grassDark: Color(0xFF2C6624),
      lineColor: Color(0xFFF2F5F0),
      netColor: Color(0xFFE8ECEF),
      postColor: Color(0xFFFFFFFF),
      accent: Color(0xFFF0B429),
      panel: Color(0xFFF2EFE4),
      panelDark: Color(0xFF16224A),
      textOn: Color(0xFF1A2440),
      textDim: Color(0xFF7A86A0),
    ),
    StadiumThemeDef(
      id: 'tropical',
      name: 'Tropical Cup',
      isPro: true,
      skyTop: Color(0xFF2A9AC9),
      skyBottom: Color(0xFFBCE8F4),
      standDark: Color(0xFF2E7A6A),
      standLight: Color(0xFF5EAA9A),
      grassLight: Color(0xFF5EB844),
      grassDark: Color(0xFF43902F),
      lineColor: Color(0xFFFFFFFF),
      netColor: Color(0xFFE6EEEA),
      postColor: Color(0xFFFFFFFF),
      accent: Color(0xFFE08A2B),
      panel: Color(0xFFF8F2E4),
      panelDark: Color(0xFF1E5A4E),
      textOn: Color(0xFF1E4A42),
      textDim: Color(0xFF6E8A7E),
    ),
    StadiumThemeDef(
      id: 'desert',
      name: 'Desert Classic',
      isPro: true,
      skyTop: Color(0xFFC97A3A),
      skyBottom: Color(0xFFF4D89A),
      standDark: Color(0xFF8A5A3A),
      standLight: Color(0xFFC08A5A),
      grassLight: Color(0xFF6A9A34),
      grassDark: Color(0xFF4E7A22),
      lineColor: Color(0xFFF8F2E4),
      netColor: Color(0xFFE8E0CC),
      postColor: Color(0xFFFCF8EE),
      accent: Color(0xFFC9562B),
      panel: Color(0xFFF8EEDA),
      panelDark: Color(0xFF6A4A2E),
      textOn: Color(0xFF4A3422),
      textDim: Color(0xFF9A7A5A),
    ),
    StadiumThemeDef(
      id: 'arctic',
      name: 'Arctic Friendly',
      isPro: true,
      skyTop: Color(0xFF9AC2DC),
      skyBottom: Color(0xFFE8F2F8),
      standDark: Color(0xFF5A7A96),
      standLight: Color(0xFF8AAABC),
      grassLight: Color(0xFF7AAC5A),
      grassDark: Color(0xFF5C8A40),
      lineColor: Color(0xFFFFFFFF),
      netColor: Color(0xFFF0F4F6),
      postColor: Color(0xFFFFFFFF),
      accent: Color(0xFF2B8AC9),
      panel: Color(0xFFF0F6FA),
      panelDark: Color(0xFF3A5A76),
      textOn: Color(0xFF2E4A60),
      textDim: Color(0xFF7A94A8),
    ),
    StadiumThemeDef(
      id: 'champions',
      name: 'Champions Night',
      isPro: true,
      skyTop: Color(0xFF101C48),
      skyBottom: Color(0xFF2A3A78),
      standDark: Color(0xFF141F44),
      standLight: Color(0xFF32427A),
      grassLight: Color(0xFF479A38),
      grassDark: Color(0xFF337A26),
      lineColor: Color(0xFFF2F5F0),
      netColor: Color(0xFFE8ECEF),
      postColor: Color(0xFFFFFFFF),
      accent: Color(0xFFD4A72B),
      panel: Color(0xFFF4F0E2),
      panelDark: Color(0xFF101C48),
      textOn: Color(0xFF141F44),
      textDim: Color(0xFF6E7AA0),
    ),
    StadiumThemeDef(
      id: 'vintage',
      name: 'Vintage Ground',
      isPro: true,
      skyTop: Color(0xFF8A9AA8),
      skyBottom: Color(0xFFE0D8C2),
      standDark: Color(0xFF5A4A3A),
      standLight: Color(0xFF8A7A62),
      grassLight: Color(0xFF5E8A3A),
      grassDark: Color(0xFF466A2A),
      lineColor: Color(0xFFF4EEE0),
      netColor: Color(0xFFDCD4BE),
      postColor: Color(0xFFF8F4E8),
      accent: Color(0xFF8A5A2B),
      panel: Color(0xFFF4ECDA),
      panelDark: Color(0xFF4A3E2E),
      textOn: Color(0xFF3E3428),
      textDim: Color(0xFF8A7A62),
    ),
    StadiumThemeDef(
      id: 'street',
      name: 'Street Cage',
      isPro: true,
      skyTop: Color(0xFF3A4A5A),
      skyBottom: Color(0xFF8A9AA8),
      standDark: Color(0xFF2E3A44),
      standLight: Color(0xFF5A6A78),
      grassLight: Color(0xFF4E8A5A),
      grassDark: Color(0xFF3A6A44),
      lineColor: Color(0xFFF0E8D8),
      netColor: Color(0xFFC8CCCE),
      postColor: Color(0xFFF0F0E8),
      accent: Color(0xFFC9562B),
      panel: Color(0xFFF0EAE0),
      panelDark: Color(0xFF2E3A44),
      textOn: Color(0xFF2E3A44),
      textDim: Color(0xFF7A8A96),
    ),
    StadiumThemeDef(
      id: 'monsoon',
      name: 'Monsoon League',
      isPro: true,
      skyTop: Color(0xFF3A4A62),
      skyBottom: Color(0xFF7A8CA2),
      standDark: Color(0xFF2E3A50),
      standLight: Color(0xFF5A6E88),
      grassLight: Color(0xFF3A8A3E),
      grassDark: Color(0xFF2A682C),
      lineColor: Color(0xFFF2F5F0),
      netColor: Color(0xFFD2D8DC),
      postColor: Color(0xFFF4F8FA),
      accent: Color(0xFF2B9A8A),
      panel: Color(0xFFEDF2F0),
      panelDark: Color(0xFF2E3A50),
      textOn: Color(0xFF22304A),
      textDim: Color(0xFF6E82A0),
    ),
  ];

  static StadiumThemeDef byId(String id, {StadiumThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) =>
      all.any((t) => t.id == id && t.isPro);
}

/// Ball paint jobs. The first 3 are FREE; the rest are PRO.
/// Drawn procedurally as a real leather ball with panels of two colors.
class BallStyleDef {
  final String name;
  final Color panel; // main leather
  final Color patch; // panel patches
  final Color seam;
  final bool isPro;

  const BallStyleDef({
    required this.name,
    required this.panel,
    required this.patch,
    required this.seam,
    this.isPro = false,
  });
}

class BallStyles {
  static const List<BallStyleDef> all = [
    BallStyleDef(
        name: 'Classic',
        panel: Color(0xFFF8F8F4),
        patch: Color(0xFF22262A),
        seam: Color(0xFF8A8E92)),
    BallStyleDef(
        name: 'All White',
        panel: Color(0xFFFFFFFF),
        patch: Color(0xFFB8BCC0),
        seam: Color(0xFF8A8E92)),
    BallStyleDef(
        name: 'Vintage Leather',
        panel: Color(0xFFB07A3E),
        patch: Color(0xFF6E4A22),
        seam: Color(0xFF4A3016)),
    BallStyleDef(
        name: 'Red Flare',
        panel: Color(0xFFF2F2EE),
        patch: Color(0xFFC93A2B),
        seam: Color(0xFF8A8E92),
        isPro: true),
    BallStyleDef(
        name: 'Blue Flare',
        panel: Color(0xFFF2F2EE),
        patch: Color(0xFF2B6AC9),
        seam: Color(0xFF8A8E92),
        isPro: true),
    BallStyleDef(
        name: 'Gold Cup',
        panel: Color(0xFFF2E4B8),
        patch: Color(0xFFB8860B),
        seam: Color(0xFF8A6D1A),
        isPro: true),
    BallStyleDef(
        name: 'Midnight',
        panel: Color(0xFF2A3040),
        patch: Color(0xFF10141E),
        seam: Color(0xFF5A6478),
        isPro: true),
    BallStyleDef(
        name: 'Street',
        panel: Color(0xFFD8D2C4),
        patch: Color(0xFFC9562B),
        seam: Color(0xFF6E5A4A),
        isPro: true),
  ];

  static bool isPro(int i) => i >= 0 && i < all.length && all[i].isPro;
}

/// Kit colors for the keeper/striker figures. First 3 FREE; rest PRO.
class KitStyles {
  static const List<Color> all = [
    Color(0xFFC93A2B), // Red
    Color(0xFF2B6AC9), // Blue
    Color(0xFF2B9A4E), // Green
    Color(0xFFF0B429), // Gold
    Color(0xFF22262A), // Black
    Color(0xFFF2F2EE), // White
    Color(0xFFE07A2B), // Orange
    Color(0xFF7A3EB8), // Purple
  ];

  static const List<String> names = [
    'Red',
    'Blue',
    'Green',
    'Gold',
    'Black',
    'White',
    'Orange',
    'Purple',
  ];

  static bool isPro(int i) => i >= 3;
}
