import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penaltykick/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'penaltykickstar'});
    expect(StoreService.starId, 'penaltykickstar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'penaltykickcoffee', 'penaltykickchocolate'});
    expect(StoreService.productIdsFor(TargetPlatform.android),
        isNot(contains('penaltykickstar')));
  });
}
