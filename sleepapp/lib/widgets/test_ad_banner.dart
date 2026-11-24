import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import '../models/rest_style.dart';

class TestAdBanner extends StatefulWidget {
  const TestAdBanner({super.key});

  static bool get enabled =>
      kDebugMode &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      const bool.fromEnvironment('REST_TEST_BANNERS');

  @override
  State<TestAdBanner> createState() => _TestAdBannerState();
}

class _TestAdBannerState extends State<TestAdBanner> {
  static const _size = AdSize.banner;
  static const _testUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static Future<void>? _initialization;

  BannerAd? _banner;
  Timer? _loadDeadline;
  bool _loaded = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _loadDeadline = Timer(const Duration(seconds: 12), _hideUnavailable);
    unawaited(_load());
  }

  static Future<void> _initialize() async {
    final ads = MobileAds.instance;
    await ads.initialize();
    await ads.setAppMuted(true);
  }

  Future<void> _load() async {
    try {
      final initialization = _initialization ??= _initialize();
      try {
        await initialization;
      } catch (_) {
        if (identical(_initialization, initialization)) _initialization = null;
        rethrow;
      }
      if (!mounted || _unavailable) return;

      final banner = BannerAd(
        adUnitId: _testUnitId,
        size: _size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted || ad != _banner) return;
            _loadDeadline?.cancel();
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            if (ad == _banner) _hideUnavailable();
          },
        ),
      );
      _banner = banner;
      await banner.load();
    } catch (_) {
      _hideUnavailable();
    }
  }

  void _hideUnavailable() {
    if (!mounted || _unavailable) return;
    _loadDeadline?.cancel();
    final banner = _banner;
    setState(() {
      _banner = null;
      _unavailable = true;
    });
    if (banner != null) unawaited(banner.dispose());
  }

  @override
  void dispose() {
    _loadDeadline?.cancel();
    final banner = _banner;
    _banner = null;
    if (banner != null) unawaited(banner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return const SizedBox.shrink();

    final style = RestStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.surface.withValues(alpha: 0.84),
        border: Border.symmetric(horizontal: BorderSide(color: style.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: _size.width.toDouble(),
            height: _size.height.toDouble(),
            child: _loaded ? AdWidget(ad: _banner!) : null,
          ),
        ),
      ),
    );
  }
}
