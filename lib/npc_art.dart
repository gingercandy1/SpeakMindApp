/// Real artwork assets: world scene illustrations and NPC portraits.
///
/// The scenes are watercolour-style travel illustrations (one per world);
/// the portraits are thick-outline flat-colour cartoons in the same style
/// as the Carmen / Pablo / Don José reference drawings the user supplied.
/// Both replace the earlier code-drawn vector scenes where they exist; the
/// vector art stays as a fallback when an asset cannot load (e.g. in
/// widget tests, which do not bundle assets).
library;

import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// World id → scene illustration.
String worldSceneAsset(int worldId) {
  const slugs = {
    1: 'madrid',
    2: 'barcelona',
    3: 'mexico',
    4: 'andes',
    5: 'buenosaires',
    6: 'camino',
    7: 'filmcity',
    8: 'globe',
  };
  return 'assets/worlds/w${worldId}_${slugs[worldId] ?? 'globe'}.webp';
}

/// NPC display name (as parsed from `npc_prompt`, e.g. "Don José") →
/// portrait asset, or null when there is no portrait for the name.
String? npcPortraitAsset(String npcName) {
  final key = _normalize(npcName);
  const portraits = {
    'carmen',
    'pablo',
    'don_jose',
    'lucia',
    'sofia',
    'elena',
    'valentina',
    'diego',
    'mateo',
    'martin',
    'andres',
    'camila',
    'mariana',
    'marta',
    'raul',
    'rosa',
    'teresa',
    'tono',
  };
  if (!portraits.contains(key)) return null;
  return 'assets/npc/$key.webp';
}

/// Lowercase, strip accents, spaces → underscores ("Don José" → "don_jose").
String _normalize(String name) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final lower = name.toLowerCase().trim();
  final buf = StringBuffer();
  for (final ch in lower.characters) {
    buf.write(accents[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), '_');
}

/// An NPC portrait in a rounded frame; falls back to the initial-letter
/// avatar when the asset is missing (unknown NPC, or widget tests).
class NpcPortrait extends StatelessWidget {
  const NpcPortrait({
    super.key,
    required this.npcName,
    this.size = 56,
    this.radius = 12,
  });

  final String npcName;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final asset = npcPortraitAsset(npcName);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SpeakMindColors.deepTeal,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        npcName.isEmpty ? '?' : npcName.characters.first,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (asset == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
