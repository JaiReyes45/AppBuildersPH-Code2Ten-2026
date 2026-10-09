import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_helpdesk/query_normalizer.dart';
import 'package:gallery_helpdesk_ai/gallery_helpdesk_ai.dart';

void main() {
  test('the requested natural-language query parses as an exact amount', () {
    final query = GalleryHelpdeskAi().parseQuery(
      normalizeAmountWords('give me gcash receipt that sent 1000 pesos'),
    );
    expect(query.category, HelpdeskCategory.gcashReceipt);
    expect(query.amount, '1000.00');
  });
  test('currency words are case-insensitive and comma amounts survive', () {
    expect(
      normalizeAmountWords('1,000 PeSoS; 20 peso; 30 PISO'),
      '1,000 PHP; 20 PHP; 30 PHP',
    );
  });
  test('identifiers and substrings remain literal', () {
    const query = 'REF-peso-1234 piso_777 pesos123 megapiso';
    expect(normalizeAmountWords(query), query);
  });
}
