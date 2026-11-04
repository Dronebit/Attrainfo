import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'debug_log.dart';

class NfcHelper {
  static Future<String?> scanBadge() async {
    final log = DebugLog.instance;
    log.nfc('--- scanBadge: start ---');

    String? result;

    try {
      log.nfc('startSession (iso14443)');
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          log.nfc('tag discovered');

          // Определяем все совпадающие типы
          final types = <String>[];
          try { if (NfcAAndroid.from(tag) != null) types.add('NfcA'); } catch (_) {}
          try { if (NfcBAndroid.from(tag) != null) types.add('NfcB'); } catch (_) {}
          try { if (NfcFAndroid.from(tag) != null) types.add('NfcF'); } catch (_) {}
          try { if (NfcVAndroid.from(tag) != null) types.add('NfcV'); } catch (_) {}
          try { if (IsoDepAndroid.from(tag) != null) types.add('IsoDep'); } catch (_) {}
          try { if (MifareClassicAndroid.from(tag) != null) types.add('MifareClassic'); } catch (_) {}
          try { if (MifareUltralightAndroid.from(tag) != null) types.add('MifareUltralight'); } catch (_) {}
          try { if (NfcBarcodeAndroid.from(tag) != null) types.add('NfcBarcode'); } catch (_) {}
          try { if (NdefAndroid.from(tag) != null) types.add('Ndef'); } catch (_) {}

          log.nfc('types: ${types.isEmpty ? "(none)" : types.join(", ")}');

          result = _readUid(tag, log);
          log.nfc('uid: ${result ?? "(null)"}');

          try {
            await NfcManager.instance.stopSession();
            log.nfc('session stopped');
          } catch (e) {
            log.warn('stopSession error: $e');
          }
        },
      );
    } catch (e, st) {
      log.error('scanBadge exception: $e');
      final stShort = st.toString().split('\n').take(3).join(' | ');
      log.error('  stack: $stShort');
      throw Exception('NFC: $e');
    }

    log.nfc('--- scanBadge: end (${result ?? "no result"}) ---');
    return result;
  }

  static String? _readUid(NfcTag tag, DebugLog log) {
    try {
      final nfcA = NfcAAndroid.from(tag);
      if (nfcA != null) {
        final hex = _toHex(nfcA.tag.id);
        log.nfc('  NfcA.id = $hex');
        return hex;
      }
    } catch (e) {
      log.warn('  NfcA read failed: $e');
    }

    try {
      final isoDep = IsoDepAndroid.from(tag);
      if (isoDep != null) {
        final hex = _toHex(isoDep.tag.id);
        log.nfc('  IsoDep.id = $hex');
        return hex;
      }
    } catch (e) {
      log.warn('  IsoDep read failed: $e');
    }

    try {
      final mifare = MifareClassicAndroid.from(tag);
      if (mifare != null) {
        final hex = _toHex(mifare.tag.id);
        log.nfc('  MifareClassic.id = $hex');
        return hex;
      }
    } catch (e) {
      log.warn('  MifareClassic read failed: $e');
    }

    log.warn('  no supported tag type');
    return null;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}