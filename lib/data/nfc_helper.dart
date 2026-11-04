import 'package:nfc_manager/nfc_manager.dart';

class NfcHelper {
  /// Возвращает UID бейджа (hex-строку) или null, если скан отменён.
  /// Бросает Exception, если NFC недоступен.
  static Future<String?> scanBadge() async {
    String? result;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso18092,
          NfcPollingOption.iso15693,
        },
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
    // Пробуем получить UID через конкретные типы тегов.
    // В nfc_manager 4.x tag.data больше не Map, поэтому используем NfcA / IsoDep / MifareClassic.
    final nfca = NfcA.from(tag);
    if (nfca != null) {
      return nfca.identifier;
    }

    final isodep = IsoDep.from(tag);
    if (isodep != null) {
      return isodep.identifier;
    }

    final mifare = MifareClassic.from(tag);
    if (mifare != null) {
      return mifare.identifier;
    }

    return null;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}