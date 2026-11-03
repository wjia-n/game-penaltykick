import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/stadium_themes.dart';

/// Penalty Kick PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final KickAudio audio;
  final KickSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  StadiumThemeDef get _t => StadiumThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.lastThanks.addListener(_onThanks);
  }

  
  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _IosGoldStarScreen(store: widget.store);
    }
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      backgroundColor: t.panelDark,
      appBar: AppBar(
        backgroundColor: t.panelDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('PENALTY KICK PRO',
            style: TextStyle(
                color: t.accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              children: [
                const SizedBox(height: 16),
                                _TipsCard(store: store, audio: widget.audio),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _TipsCard extends StatelessWidget {
  final StoreService store;
  final KickAudio audio;
  const _TipsCard({required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('☕ Tip jar',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Penalty Kick is free forever. If it made you smile, a tip keeps the stadium lights on!',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text('Store: ${store.error ?? 'loading…'}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13)),
          Row(
            children: [
              if (store.coffeeProduct != null)
                Expanded(
                  child: _tipButton(store.coffeeProduct!, '☕ Coffee',
                      store.coffeeProduct!.price),
                ),
              if (store.coffeeProduct != null &&
                  store.chocolateProduct != null)
                const SizedBox(width: 10),
              if (store.chocolateProduct != null)
                Expanded(
                  child: _tipButton(store.chocolateProduct!,
                      '🍫 Chocolate', store.chocolateProduct!.price),
                ),
            ],
          ),
          ValueListenableBuilder<String?>(
            valueListenable: store.lastThanks,
            builder: (_, msg, __) => msg == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(msg,
                        style: const TextStyle(
                            color: Color(0xFF7ED957),
                            fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tipButton(ProductDetails product, String label, String price) {
    return ValueListenableBuilder<bool>(
      valueListenable: store.purchaseInProgress,
      builder: (_, busy, __) => OutlinedButton(
        onPressed: busy
            ? null
            : () {
                audio.click();
                store.buyTip(product);
              },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white30),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text('$label\n$price',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// iOS-only Gold Star screen: exactly one button, plus a badge once owned.
/// The game stays fully unlocked; the star is cosmetic only.
/// Android keeps the original screen below, byte-identical.
class _IosGoldStarScreen extends StatelessWidget {
  final StoreService store;
  const _IosGoldStarScreen({required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Gold Star'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'This game is fully unlocked.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: store.goldStarOwned,
                  builder: (_, owned, _) => Text(
                    owned
                        ? '⭐ Gold Star earned — thank you!'
                        : 'Get a Gold Star to show your support!',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                if (!store.storeReady)
                  Text(store.error ?? 'Available after store setup.',
                      textAlign: TextAlign.center)
                else if (store.starProduct == null)
                  const Text('Gold Star coming soon.',
                      textAlign: TextAlign.center)
                else
                  ValueListenableBuilder<bool>(
                    valueListenable: store.goldStarOwned,
                    builder: (_, owned, _) => owned
                        ? const Text('⭐', style: TextStyle(fontSize: 48))
                        : ElevatedButton(
                            onPressed: () =>
                                store.buyStar(store.starProduct!),
                            child: Text(
                                '⭐ Gold Star ${store.starProduct!.price}'),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
