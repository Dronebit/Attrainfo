import 'package:nfc_manager/nfc_manager.dart';

class NfcHelper {
  /// Возвращает UID бейджа (hex-строку) или null, если скан отменён.
  /// Бросает Exception, если NFC недоступен.
  static Future<String?> scanBadge() async {
    String? result;

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final id = _extractUid(tag);
          if (id != null) {
            result = _toHex(id);
          }
          await NfcManager.instance.stopSession();
        },
      );
    } catch (e) {
      throw Exception('NFC недоступен или ошибка чтения: $e');
    }

    return result;
  }

  static List<int>? _extractUid(NfcTag tag) {
    final nfca = tag.data['nfca'];
    final isodep = tag.data['isodep'];
    final mifare = tag.data['mifareclassic'];

    if (nfca is Map && nfca['identifier'] is List) {
      return List<int>.from(nfca['identifier']);
    }
    if (isodep is Map && isodep['identifier'] is List) {
      return List<int>.from(isodep['identifier']);
    }
    if (mifare is Map && mifare['identifier'] is List) {
      return List<int>.from(mifare['identifier']);
    }
    return null;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}