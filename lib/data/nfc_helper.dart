import 'package:nfc_manager/nfc_manager.dart';

class NfcHelper {
  /// Возвращает UID бейджа (hex-строку) или null, если скан отменён.
  /// Бросает Exception, если NFC недоступен.
  static Future<String?> scanBadge() async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      throw Exception('NFC выключен или не поддерживается на этом устройстве');
    }

    String? result;
    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        // UID (identifier) — есть у любого NFC-тега
        final nfca = tag.data['nfca'];
        final isodep = tag.data['isodep'];
        final mifare = tag.data['mifareclassic'];

        List<int>? id;
        if (nfca is Map && nfca['identifier'] is List) {
          id = List<int>.from(nfca['identifier']);
        } else if (isodep is Map && isodep['identifier'] is List) {
          id = List<int>.from(isodep['identifier']);
        } else if (mifare is Map && mifare['identifier'] is List) {
          id = List<int>.from(mifare['identifier']);
        }

        if (id != null) {
          result = _toHex(id);
        }
        await NfcManager.instance.stopSession();
      },
    );

    return result;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}