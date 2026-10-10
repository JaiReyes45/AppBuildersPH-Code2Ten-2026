import 'package:gallery_helpdesk_ai/src/normalization.dart';
import 'package:test/test.dart';

void main() {
  test('canonicalizes amount representations', () {
    expect(normalizeAmount('P2,500'), '2500');
    expect(normalizeAmount('PHP 2,500.00'), '2500');
    expect(normalizeAmount('₱1,500'), '1500');
    expect(normalizeAmount('500'), '500');
    expect(normalizeAmount('1,234.50'), '1234.5');
  });
}
