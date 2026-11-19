import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/models/product_model.dart';
import 'package:auto_spare_hub/utils/product_search.dart';

ProductModel _product(String id, String name, String partNo) => ProductModel(
      id: id,
      name: name,
      imageUrl: '',
      companyId: 'C1',
      companyName: 'BOSCH',
      categoryId: 'CAT1',
      categoryName: 'Steering',
      application: partNo,
      isActive: true,
    );

void main() {
  final pump = _product('P1', 'Power Steering Pump', '44310-0K040');
  final filter = _product('P2', 'Oil Filter', 'OF 4431');
  final noPart = _product('P3', 'Brake Pad', '');

  test('matches part number ignoring case, spaces and hyphens', () {
    expect(ProductSearch.matches(pump, '44310-0K040'), isTrue);
    expect(ProductSearch.matches(pump, '443100k040'), isTrue);
    expect(ProductSearch.matches(pump, '44310 0k'), isTrue);
    expect(ProductSearch.matches(filter, 'of4431'), isTrue);
  });

  test('matches product name and brand', () {
    expect(ProductSearch.matches(pump, 'steering pump'), isTrue);
    expect(ProductSearch.matches(noPart, 'bosch'), isTrue);
    expect(ProductSearch.matches(noPart, 'xyz'), isFalse);
  });

  test('ranks part number matches first', () {
    final results = ProductSearch.search([filter, noPart, pump], '4431');
    expect(results.first.id, 'P1');
    expect(results.map((p) => p.id), containsAll(['P1', 'P2']));
    expect(results.any((p) => p.id == 'P3'), isFalse);
  });

  test('partNumber is null when not entered', () {
    expect(noPart.partNumber, isNull);
    expect(pump.partNumber, '44310-0K040');
  });
}
