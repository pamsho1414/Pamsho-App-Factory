import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const String _bannerAdUnitId = String.fromEnvironment(
  'ADMOB_BANNER_AD_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/9214589741',
);

class HomeBannerAd extends StatefulWidget {
  const HomeBannerAd({super.key});

  @override
  State<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<HomeBannerAd> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeAndLoad());
  }

  Future<void> _initializeAndLoad() async {
    try {
      await MobileAds.instance.initialize();
      if (!mounted) return;

      final ad = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('AdMob banner failed to load: $error');
            ad.dispose();
            if (mounted) {
              setState(() {
                _loaded = false;
                _banner = null;
              });
            }
          },
        ),
      );
      _banner = ad;
      await ad.load();
    } catch (error, stackTrace) {
      debugPrint('AdMob initialization or banner load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _banner;
    if (!_loaded || ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: ad.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
