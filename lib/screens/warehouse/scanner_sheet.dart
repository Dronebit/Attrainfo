import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../../data/app_database.dart';
import '../../models/inventory.dart';
import '../../theme.dart';

class ScanResult {
  final String raw;
  final ScanKind kind;
  final String code;
  const ScanResult(this.raw, this.kind, this.code);
}

enum ScanKind { location, item, unknown }

// Теперь передаем db, чтобы сканер мог найти название
Future<ScanResult?> showScannerSheet(BuildContext context, AppDatabase db) {
  return showModalBottomSheet<ScanResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScannerSheet(db: db),
  );
}

class _ScannerSheet extends StatefulWidget {
  final AppDatabase db;
  const _ScannerSheet({required this.db});
  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  bool _isProcessing = false;
  Code? _lastCode;
  
  // Найденные объекты для карточки
  InventoryItem? _foundItem;
  StorageLocation? _foundLoc;
  String? _rawCodeString;

  // Конвертируем Position из ZXing в Rect
  Rect? _positionToRect(Position? pos) {
    if (pos == null) return null;
    final left = [pos.topLeftX, pos.bottomLeftX].reduce((a, b) => a < b ? a : b).toDouble();
    final right = [pos.topRightX, pos.bottomRightX].reduce((a, b) => a > b ? a : b).toDouble();
    final top = [pos.topLeftY, pos.topRightY].reduce((a, b) => a < b ? a : b).toDouble();
    final bottom = [pos.bottomLeftY, pos.bottomRightY].reduce((a, b) => a > b ? a : b).toDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _onScan(Code code) {
    if (_isProcessing) return; // Игнорируем, если карточка уже открыта
    if (!code.isValid || code.text == null || code.text!.isEmpty) return;

    HapticFeedback.mediumImpact();

    final raw = code.text!;
    String searchCode = raw;
    ScanKind kind = ScanKind.unknown;

    if (raw.startsWith('LOC:')) {
      searchCode = raw.substring(4);
      kind = ScanKind.location;
    } else if (raw.startsWith('SKU:')) {
      searchCode = raw.substring(4);
      kind = ScanKind.item;
    }

    // Ищем в базе
    InventoryItem? item;
    StorageLocation? loc;

    if (kind == ScanKind.location) {
      loc = widget.db.storageLocations.where((l) => l.code.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
    } else if (kind == ScanKind.item) {
      item = widget.db.inventoryItems.where((i) => i.sku.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
    } else {
      // Если без префикса - ищем везде
      loc = widget.db.storageLocations.where((l) => l.code.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
      if (loc == null) {
        item = widget.db.inventoryItems.where((i) => i.sku.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
      }
    }

    setState(() {
      _isProcessing = true;
      _lastCode = code;
      _rawCodeString = raw;
      _foundItem = item;
      _foundLoc = loc;
    });
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _lastCode = null;
      _foundItem = null;
      _foundLoc = null;
      _rawCodeString = null;
    });
  }

  void _confirmSelection() {
    if (_rawCodeString == null) return;
    ScanKind kind = ScanKind.unknown;
    String code = _rawCodeString!;
    if (code.startsWith('LOC:')) {
      kind = ScanKind.location;
      code = code.substring(4);
    } else if (code.startsWith('SKU:')) {
      kind = ScanKind.item;
      code = code.substring(4);
    }
    Navigator.pop(context, ScanResult(_rawCodeString!, kind, code));
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.amb, foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return;
    if (!mounted) return;
    
    // Эмулируем скан для ручного ввода
    Navigator.pop(context, ScanResult(
      ok, 
      ok.startsWith('LOC:') ? ScanKind.location : (ok.startsWith('SKU:') ? ScanKind.item : ScanKind.unknown), 
      ok.replaceAll(RegExp(r'^(LOC:|SKU:)'), '')
    ));
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
            decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.amb),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Сканирование', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          
          // Камера и оверлеи
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ReaderWidget(
                      onScan: _onScan,
                      showScannerOverlay: false,
                      showFlashlight: true, // Фонарик
                      showGallery: false,
                      showToggleCamera: false,
                    ),
                    
                    // Статичная рамка (когда ничего не сканируется)
                    if (!_isProcessing)
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.amb, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      
                    // AR-рамка (когда код найден)
                    if (_isProcessing && _lastCode?.position != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ArOverlayPainter(_positionToRect(_lastCode!.position)),
                        ),
                      ),

                    // ВСПЛЫВАЮЩАЯ КАРТОЧКА ВНИЗУ
                    if (_isProcessing)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 20,
                        child: _buildFloatingCard(),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Нижняя панель
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(children: [
              Text(
                _isProcessing ? 'Подтвердите выбор' : 'Наведите на QR полки или позиции',
                style: TextStyle(
                  fontSize: 12, 
                  color: _isProcessing ? AppColors.amb : AppColors.mut,
                  fontWeight: _isProcessing ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? _resetScanner : _manualInput,
                  icon: Icon(_isProcessing ? Icons.refresh : Icons.keyboard, size: 16),
                  label: Text(_isProcessing ? 'Сканировать другое' : 'Ввести код вручную'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─── ВСПЛЫВАЮЩАЯ КАРТОЧКА ───
  Widget _buildFloatingCard() {
    final isFound = _foundItem != null || _foundLoc != null;
    final title = _foundItem?.name ?? _foundLoc?.name ?? 'Не найдено в базе';
    
    final subtitle = _foundItem != null 
        ? '${_foundItem!.sku} · Остаток: ${widget.db.stockTotal(_foundItem!.id)} ${_foundItem!.unit.label}'
        : (_foundLoc != null 
            ? 'Локация: ${_foundLoc!.code}' 
            : (_rawCodeString ?? 'Неизвестный код'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFound ? AppColors.grn.withValues(alpha: 0.5) : AppColors.red.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isFound ? ( _foundLoc != null ? Icons.inventory_2_outlined : Icons.check_circle_outline) : Icons.error_outline,
                color: isFound ? AppColors.grn : AppColors.red,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(subtitle, 
                      style: const TextStyle(fontSize: 11, color: AppColors.dim),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isFound)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amb,
                  foregroundColor: const Color(0xFF1C1204),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _confirmSelection,
                child: const Text('Выбрать', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
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