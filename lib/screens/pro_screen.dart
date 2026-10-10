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

class _BuyButton extends StatelessWidget {
  final KickAudio audio;
  final StoreService store;
  final String label;
  final Future<void> Function() onBuy;
  const _BuyButton(
      {required this.audio,
      required this.store,
      required this.label,
      required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: store.purchaseInProgress,
      builder: (_, busy, __) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: busy
              ? null
              : () {
                  audio.click();
                  onBuy();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.black))
              : Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15)),
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
