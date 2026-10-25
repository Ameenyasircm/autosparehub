import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/phone_helper.dart';

/// Service managing dynamic store contact details from Firestore
/// (/CONTACT_DETAILS/1234PHONE) with fallback to "9048112233",
/// along with direct phone call and WhatsApp intents.
class ContactService {
  final FirebaseFirestore? _customFirestore;

  ContactService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'CONTACT_DETAILS';
  static const String documentId = '1234PHONE';
  static const String defaultPhoneNumber = '9048112233';

  String? _cachedPhoneNumber;

  /// Returns the cached phone number or default if not yet fetched
  String get activePhoneNumber => _cachedPhoneNumber ?? defaultPhoneNumber;

  /// Fetches contact phone dynamically from /CONTACT_DETAILS/1234PHONE
  Future<String> fetchContactPhone() async {
    try {
      final doc = await _firestore
          .collection(collectionName)
          .doc(documentId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final dynamic val = data['PHONE'] ??
            data['phone'] ??
            data['PHONE_NUMBER'] ??
            data['phoneNumber'] ??
            data['NUMBER'] ??
            data['number'] ??
            data['whatsapp'] ??
            data['WHATSAPP'] ??
            data['contact'] ??
            data['CONTACT'];

        if (val != null) {
          final digits = PhoneHelper.extract10Digits(val.toString());
          if (digits.isNotEmpty) {
            _cachedPhoneNumber = digits;
            return digits;
          }
        }
      }
    } catch (e) {
      debugPrint('ContactService.fetchContactPhone error: $e');
    }

    _cachedPhoneNumber ??= defaultPhoneNumber;
    return _cachedPhoneNumber!;
  }

  /// Updates the store contact phone number in /CONTACT_DETAILS/1234PHONE
  Future<bool> updateContactPhone(String newPhone) async {
    final clean = PhoneHelper.extract10Digits(newPhone);
    if (clean.length != 10) return false;
    try {
      await _firestore.collection(collectionName).doc(documentId).set({
        'PHONE': clean,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _cachedPhoneNumber = clean;
      return true;
    } catch (e) {
      debugPrint('ContactService.updateContactPhone error: $e');
      return false;
    }
  }

  /// Launch phone dialer intent
  Future<bool> launchPhoneCall([String? phone]) async {
    final raw = phone ?? activePhoneNumber;
    final clean = PhoneHelper.extract10Digits(raw);
    final finalNumber = clean.isNotEmpty ? clean : raw.replaceAll(RegExp(r'\D'), '');

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: finalNumber.isNotEmpty
          ? (finalNumber.length == 10 ? '+91$finalNumber' : finalNumber)
          : '+91$defaultPhoneNumber',
    );

    try {
      if (await canLaunchUrl(phoneUri)) {
        return await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(phoneUri);
    } catch (e) {
      debugPrint('ContactService.launchPhoneCall error: $e');
      return false;
    }
  }

  /// Launch WhatsApp chat intent
  Future<bool> launchWhatsApp([String? phone, String? initialMessage]) async {
    final raw = phone ?? activePhoneNumber;
    final clean = PhoneHelper.extract10Digits(raw);
    final final10 = clean.isNotEmpty ? clean : defaultPhoneNumber;
    final phoneWithCountry = '91$final10';

    final text = initialMessage != null && initialMessage.isNotEmpty
        ? Uri.encodeComponent(initialMessage)
        : Uri.encodeComponent('Hello Auto Spare Hub, I have an inquiry about spare parts.');

    // 1. Native WhatsApp scheme
    final Uri nativeUri = Uri.parse('whatsapp://send?phone=$phoneWithCountry&text=$text');

    // 2. Web redirect link fallback
    final Uri webUri = Uri.parse('https://wa.me/$phoneWithCountry?text=$text');

    try {
      if (await canLaunchUrl(nativeUri)) {
        final launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(webUri);
    } catch (e) {
      debugPrint('ContactService.launchWhatsApp error: $e');
      return false;
    }
  }

  /// Format phone number nicely for display (e.g. "+91 90481 12233")
  String formatForDisplay([String? phone]) {
    final raw = phone ?? activePhoneNumber;
    final digits = PhoneHelper.extract10Digits(raw);
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return raw;
  }
}
