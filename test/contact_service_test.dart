import 'package:flutter_test/flutter_test.dart';
import 'package:auto_spare_hub/services/contact_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactService Tests', () {
    test('defaults to 9048112233 when no cached phone exists', () {
      final service = ContactService();
      expect(service.activePhoneNumber, '9048112233');
    });

    test('formats 10-digit phone number cleanly for UI display', () {
      final service = ContactService();
      expect(service.formatForDisplay('9048112233'), '+91 90481 12233');
      expect(service.formatForDisplay('+919048112233'), '+91 90481 12233');
      expect(service.formatForDisplay('09048112233'), '+91 90481 12233');
    });

    test('verifies constant collection path /CONTACT_DETAILS/1234PHONE', () {
      expect(ContactService.collectionName, 'CONTACT_DETAILS');
      expect(ContactService.documentId, '1234PHONE');
      expect(ContactService.defaultPhoneNumber, '9048112233');
    });
  });
}
