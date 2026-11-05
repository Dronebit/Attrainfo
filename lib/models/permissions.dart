import 'employee.dart';

class RoleAssignmentPermissions {
  final bool canChangePrimary;
  final List<EmployeeRole> availablePrimaryRoles;
  final List<EmployeeRole> availableExtraRoles;

  const RoleAssignmentPermissions({
    required this.canChangePrimary,
    required this.availablePrimaryRoles,
    required this.availableExtraRoles,
  });
}