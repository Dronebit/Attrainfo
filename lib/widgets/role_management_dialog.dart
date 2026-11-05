import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../theme.dart';

/// Результат диалога управления ролями.
class RoleChangeResult {
  final EmployeeRole primary;
  final List<EmployeeRole> extras;
  const RoleChangeResult({required this.primary, required this.extras});
}

/// Открывает диалог управления ролями.
///
/// [selectableRoles] — роли для выбора «Основная» (radio).
/// [selectableExtras] — роли для выбора «Дополнительные» (checkbox).
/// [canChangePrimary] — если `false`, основную роль поменять нельзя
///   (будет показана как readonly-бейдж).
Future<RoleChangeResult?> showRoleManagementDialog({
  required BuildContext context,
  required Employee employee,
  required List<EmployeeRole> selectableRoles,
  required List<EmployeeRole> selectableExtras,
  bool canChangePrimary = true,
  String title = 'Роли',
}) {
  return showDialog<RoleChangeResult>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => _RoleManagementDialog(
      employee: employee,
      selectableRoles: selectableRoles,
      selectableExtras: selectableExtras,
      canChangePrimary: canChangePrimary,
      title: title,
    ),
  );
}

class _RoleManagementDialog extends StatefulWidget {
  final Employee employee;
  final List<EmployeeRole> selectableRoles;
  final List<EmployeeRole> selectableExtras;
  final bool canChangePrimary;
  final String title;

  const _RoleManagementDialog({
    required this.employee,
    required this.selectableRoles,
    required this.selectableExtras,
    required this.canChangePrimary,
    required this.title,
  });

  @override
  State<_RoleManagementDialog> createState() =>
      _RoleManagementDialogState();
}

class _RoleManagementDialogState extends State<_RoleManagementDialog> {
  late EmployeeRole _primary;
  late Set<EmployeeRole> _extras;

  @override
  void initState() {
    super.initState();
    _primary = widget.employee.role;
    _extras = Set.from(widget.employee.additionalRoles);
    // Убираем возможные дубли: primary не должен быть в extras
    _extras.remove(_primary);
  }

  void _selectPrimary(EmployeeRole r) {
    if (!widget.canChangePrimary) return;
    if (_primary == r) return;
    setState(() {
      // Старую primary — в extras (если она не админ, чтобы не плодить
      // админ-ролей в допах), новую — убираем из extras.
      if (!_primary.canBeAdmin) {
        _extras.add(_primary);
      }
      _primary = r;
      _extras.remove(r);
    });
  }

  void _toggleExtra(EmployeeRole r) {
    if (r == _primary) return;
    setState(() {
      if (_extras.contains(r)) {
        _extras.remove(r);
      } else {
        _extras.add(r);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: Text('${widget.title} · ${widget.employee.name}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Основная роль',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.dim,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (widget.canChangePrimary)
                for (final r in widget.selectableRoles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _primaryRow(r),
                  )
              else ...[
                _readonlyPrimaryRow(),
                const SizedBox(height: 4),
                const Text(
                  'Сменить основную роль можно через «Перевести» '
                  'в другой парк/регион или «Снять с должности».',
                  style: TextStyle(fontSize: 10.5, color: AppColors.dim),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Дополнительные роли',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.dim,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final r in widget.selectableExtras)
                if (r != _primary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _extraRow(r),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.amb,
              foregroundColor: const Color(0xFF1C1204)),
          onPressed: () => Navigator.pop(
            context,
            RoleChangeResult(
              primary: _primary,
              extras: _extras.toList(),
            ),
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _primaryRow(EmployeeRole r) {
    final active = _primary == r;
    return InkWell(
      onTap: () => _selectPrimary(r),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Color(r.colorValue).withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
              color: active
                  ? Color(r.colorValue).withValues(alpha: 0.4)
                  : AppColors.line2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(
              active
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color:
                  active ? Color(r.colorValue) : AppColors.dim),
          const SizedBox(width: 8),
          Text(r.label, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _readonlyPrimaryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color(_primary.colorValue).withValues(alpha: 0.12),
        border: Border.all(
            color: Color(_primary.colorValue).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.lock_outline, size: 16, color: AppColors.dim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_primary.label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _extraRow(EmployeeRole r) {
    final active = _extras.contains(r);
    return InkWell(
      onTap: () => _toggleExtra(r),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.cyn.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
              color: active
                  ? AppColors.cyn.withValues(alpha: 0.4)
                  : AppColors.line2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(
              active
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 18,
              color: active ? AppColors.cyn : AppColors.dim),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r.label,
                style: const TextStyle(fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}