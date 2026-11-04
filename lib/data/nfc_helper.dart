import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcHelper {
  /// Возвращает UID бейджа (hex-строку) или null, если скан отменён.
  static Future<String?> scanBadge() async {
    String? result;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          result = _readUid(tag);
          await NfcManager.instance.stopSession();
        },
      );
    } catch (e) {
      throw Exception('NFC недоступен или ошибка чтения: $e');
    }

    return result;
  }

  static String? _readUid(NfcTag tag) {
    // Пробуем по очереди разные типы. Первый совпавший — берёт свой UID.
    final nfcA = NfcAAndroid.from(tag);
    if (nfcA != null) {
      return _toHex(nfcA.tag.identifier);
    }

    final isoDep = IsoDepAndroid.from(tag);
    if (isoDep != null) {
      return _toHex(isoDep.tag.identifier);
    }

    final mifare = MifareClassicAndroid.from(tag);
    if (mifare != null) {
      return _toHex(mifare.tag.identifier);
    }

    return null;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}