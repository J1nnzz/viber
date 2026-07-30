import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// Implementación móvil (Android/iOS) con AdMob. En escritorio (también pasa por
/// aquí vía `dart.library.io`) hace no-op, porque google_mobile_ads solo soporta
/// Android e iOS.
AdService createAdService() => _MobileAdService();

class _MobileAdService implements AdService {
  bool _initialized = false;
  RewardedAd? _rewarded;

  // IDs de PRUEBA públicos de Google (no generan ingresos).
  // TODO: sustituir por los ad unit IDs reales de tu cuenta AdMob.
  static String get _rewardedUnitId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> initialize() async {
    if (!_supported || _initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _preload();
  }

  /// Carga un rewarded en segundo plano para que esté listo cuando se pida.
  void _preload() {
    if (!_supported) return;
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  @override
  Future<bool> showRewarded() async {
    if (!_supported) return false;

    final ad = _rewarded;
    if (ad == null) {
      _preload(); // no había uno listo; intenta tenerlo para la próxima
      return false;
    }
    _rewarded = null;

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preload();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _preload();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return completer.future;
  }
}
