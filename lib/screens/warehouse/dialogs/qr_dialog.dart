import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../theme.dart';

Future<void> showQrDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String qrData,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: Row(children: [
        const Icon(Icons.qr_code, size: 20, color: AppColors.amb),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.dim)),
          const SizedBox(height: 8),
          SelectableText(
            qrData,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Копировать'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: qrData));
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Код скопирован')),
            );
          },
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amb,
            foregroundColor: const Color(0xFF1C1204),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}