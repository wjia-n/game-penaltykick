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
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PRO unlocked — enjoy everything!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
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
    widget.store.proPurchased.removeListener(_onPro);
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
                _ComparisonCard(isPro: s.isPro),
                const SizedBox(height: 16),
                _BuyCard(
                  settings: s,
                  store: store,
                  audio: widget.audio,
                ),
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

class _ComparisonCard extends StatelessWidget {
  final bool isPro;
  const _ComparisonCard({required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium,
                  color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Free vs PRO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              _row('', 'FREE', 'PRO', header: true),
              _row('Full shootout game', true, true),
              _row('3 AI difficulties', 'Easy+Med', 'All 3'),
              _row('Pass-and-play 2 players', true, true),
              _row('Practice mode', true, true),
              _row('Stadium themes', '4', '12 + custom'),
              _row('Ball styles', '3', 'All 8'),
              _row('Kit colors', '3', 'All 8'),
              _row('Design-my-stadium', false, true),
              _row('Hard AI mode', false, true),
              _row('Stats & leaderboards', true, true),
            ],
          ),
          if (isPro)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('PRO is active on this device. Enjoy! 🎉',
                  style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  static TableRow _row(String label, Object free, Object pro,
      {bool header = false}) {
    Widget cell(Object v) {
      if (v is bool) {
        return Icon(v ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: v ? const Color(0xFF7ED957) : Colors.white24);
      }
      return Text('$v',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: header ? FontWeight.w900 : FontWeight.w600,
            fontSize: header ? 13 : 12,
          ));
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(label,
              style: TextStyle(
                color: header ? Colors.white54 : Colors.white,
                fontWeight:
                    header ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12.5,
              )),
        ),
        Center(child: cell(free)),
        Center(child: cell(pro)),
      ],
    );
  }
}

class _BuyCard extends StatelessWidget {
  final KickSettings settings;
  final StoreService store;
  final KickAudio audio;
  const _BuyCard(
      {required this.settings, required this.store, required this.audio});

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
          const Text('Unlock PRO',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'One-time purchase. Yours forever, on every device.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (settings.isPro)
            const Text('✅ PRO is active — thank you!',
                style: TextStyle(
                    color: Color(0xFF7ED957),
                    fontWeight: FontWeight.w800)),
          if (!settings.isPro) ...[
            if (!store.storeReady)
              Text(
                'Store: ${store.error ?? 'loading…'}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            if (store.proProduct != null)
              _BuyButton(
                audio: audio,
                store: store,
                label:
                    'Go PRO — ${store.proProduct!.price}',
                onBuy: store.buyPro,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                audio.click();
                store.restore();
              },
              child: const Text('Restore purchases',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, __) => err == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(err,
                        style: const TextStyle(
                            color: Color(0xFFEF476F), fontSize: 13)),
                  ),
          ),
        ],
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
