import 'ad_service.dart';

/// Implementación para web y escritorio: nunca se sirven anuncios.
AdService createAdService() => _StubAdService();

class _StubAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> showRewarded() async => false;
}
