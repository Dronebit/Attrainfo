import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../../data/debug_log.dart';
import '../../theme.dart';

class ScanResult {
  final String raw;
  final ScanKind kind;
  final String code;
  const ScanResult(this.raw, this.kind, this.code);
}

enum ScanKind { location, item, unknown }

Future<ScanResult?> showScannerSheet(BuildContext context) {
  return showModalBottomSheet<ScanResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ScannerSheet(),
  );
}

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet();
  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  bool _handled = false;
  Code? _lastCode; // Для отрисовки AR-рамки

  // Конвертируем Position из ZXing в Rect для CustomPaint
  Rect? _positionToRect(Position? pos) {
  if (pos == null) return null;
  // Используем встроенный метод toRect() из flutter_zxing
  return pos.toRect();
}

  void _onScan(Code code) {
    if (_handled) return;
    if (!code.isValid || code.text == null || code.text!.isEmpty) return;

    // 1. Вибрация для отклика
    HapticFeedback.mediumImpact();

    // 2. Сохраняем код, чтобы AR-рамка нарисовалась
    setState(() {
      _lastCode = code;
    });

    // 3. Задержка 300мс, чтобы пользователь увидел зеленую рамку
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _handled = true;
        Navigator.pop(context, _makeResult(code.text!));
      }
    });
  }

  ScanResult _makeResult(String raw) {
    if (raw.startsWith('LOC:')) {
      return ScanResult(raw, ScanKind.location, raw.substring(4));
    }
    if (raw.startsWith('SKU:')) {
      return ScanResult(raw, ScanKind.item, raw.substring(4));
    }
    return ScanResult(raw, ScanKind.unknown, raw);
  }

  Future<void> _manualInput() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Ввести код вручную'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Код',
            hintText: 'P1-R2-P3 или BR-6204',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return;
    if (!mounted) return;
    Navigator.pop(context, _makeResult(ok));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Заголовок
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.amb),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Сканирование',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          
          // Камера и AR-рамка
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Камера (скрываем встроенные элементы ZXing)
                    ReaderWidget(
                      onScan: _onScan,
                      showScannerOverlay: false, 
                      showFlashlight: false,     
                      showGallery: false,
                      showToggleCamera: false,
                    ),
                    
                    // Наша статичная рамка (показывается, пока код не найден)
                    if (_lastCode == null)
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.amb, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      
                    // AR-рамка (появляется, когда код распознан)
                    if (_lastCode != null && _lastCode!.position != null)
                      Positioned.fill(
                        child: CustomPaint(
                          // Передаем сконвертированный Rect
                          painter: _ArOverlayPainter(
                            _positionToRect(_lastCode!.position),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Нижняя панель с кнопкой ручного ввода
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(children: [
              Text(
                _lastCode == null 
                  ? 'Наведите на QR полки или позиции'
                  : 'Код распознан!',
                style: TextStyle(
                  fontSize: 12, 
                  color: _lastCode == null ? AppColors.mut : AppColors.grn,
                  fontWeight: _lastCode == null ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _manualInput,
                  icon: const Icon(Icons.keyboard, size: 16),
                  label: const Text('Ввести код вручную'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AR-Оверлей для отрисовки зеленой рамки поверх кода
// ─────────────────────────────────────────────────────────────
class _ArOverlayPainter extends CustomPainter {
  final Rect? position;
  _ArOverlayPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    if (position == null) return;

    // Красивое свечение
    final glowPaint = Paint()
      ..color = AppColors.grn.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Четкая линия
    final paint = Paint()
      ..color = AppColors.grn
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Рисуем прямоугольник вокруг кода (с небольшим отступом)
    final rect = Rect.fromLTRB(
      position!.left - 4,
      position!.top - 4,
      position!.right + 4,
      position!.bottom + 4,
    );

    canvas.drawRect(rect, glowPaint);
    canvas.drawRect(rect, paint);

    // Рисуем AR-уголки
    _drawCorner(canvas, rect.topLeft, 1, 1, paint);
    _drawCorner(canvas, rect.topRight, -1, 1, paint);
    _drawCorner(canvas, rect.bottomLeft, 1, -1, paint);
    _drawCorner(canvas, rect.bottomRight, -1, -1, paint);
  }

  void _drawCorner(Canvas canvas, Offset p, double dx, double dy, Paint paint) {
    const len = 20.0;
    canvas.drawLine(p, p + Offset(len * dx, 0), paint);
    canvas.drawLine(p, p + Offset(0, len * dy), paint);
  }

  @override
  bool shouldRepaint(covariant _ArOverlayPainter oldDelegate) => oldDelegate.position != position;
}