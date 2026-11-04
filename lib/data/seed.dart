import '../models/enums.dart';
import '../models/models.dart';
import '../models/employee.dart';
import '../models/operator_park_link.dart';
import '../models/region.dart';

Map<String, dynamic> buildSeed() {
  final now = DateTime.now();
  DateTime h(int n) => now.subtract(Duration(hours: n));
  DateTime d(int n) => now.subtract(Duration(days: n));

  return {
    'cities': [
      City(id: 'c1', name: 'Москва'),
      City(id: 'c2', name: 'Санкт-Петербург'),
      City(id: 'c3', name: 'Казань'),
      City(id: 'c4', name: 'Сочи'),
    ],
    'locations': [
      ParkLocation(id: 'l1', cityId: 'c1', name: 'ВДНХ'),
      ParkLocation(id: 'l2', cityId: 'c1', name: 'Нагатинская пойма'),
      ParkLocation(id: 'l3', cityId: 'c2', name: 'Приморский парк Победы'),
      ParkLocation(id: 'l4', cityId: 'c3', name: 'Озеро Кабан'),
      ParkLocation(id: 'l5', cityId: 'c4', name: 'Центральный район'),
    ],
    'parks': [
      Park(
        id: 'p1',
        locId: 'l1',
        name: 'Парк Чудес',
        openedAt: DateTime(2019, 6, 12),
        address: 'Москва, ВДНХ, аллея Космонавтов, 1',
        phone: '+7 495 123-45-67',
      ),
      Park(
        id: 'p2',
        locId: 'l2',
        name: 'Страна Мечты',
        openedAt: DateTime(2020, 5, 1),
        address: 'Москва, Нагатинская пойма, ул. Речная, 5',
      ),
      Park(
        id: 'p3',
        locId: 'l3',
        name: 'Остров Чудес',
        openedAt: DateTime(2018, 7, 15),
      ),
      Park(id: 'p4', locId: 'l4', name: 'Казань-Фан'),
      Park(id: 'p5', locId: 'l5', name: 'Южная Ривьера'),
    ],
    'rides': [
      Ride(id: 'r1', parkId: 'p1', name: 'Колесо обозрения «Горизонт»', type: RideType.ferris, year: 2019, status: RideStatus.active),
      Ride(id: 'r2', parkId: 'p1', name: 'Горки «Тайфун»', type: RideType.coaster, year: 2021, status: RideStatus.downtime),
      Ride(id: 'r3', parkId: 'p1', name: 'Карусель «Лебеди»', type: RideType.carousel, year: 2017, status: RideStatus.active),
      Ride(id: 'r4', parkId: 'p1', name: 'Башня «Комета»', type: RideType.drop, year: 2022, status: RideStatus.active),
      Ride(id: 'r5', parkId: 'p2', name: 'Водный спуск «Река»', type: RideType.water, year: 2018, status: RideStatus.active),
      Ride(id: 'r6', parkId: 'p2', name: 'Маятник «Орбита»', type: RideType.swing, year: 2020, status: RideStatus.active),
      Ride(id: 'r7', parkId: 'p2', name: 'Детская карусель «Солнышко»', type: RideType.carousel, year: 2016, status: RideStatus.active),
      Ride(id: 'r8', parkId: 'p2', name: 'Горки «Серпантин»', type: RideType.coaster, year: 2015, status: RideStatus.retired),
      Ride(id: 'r9', parkId: 'p3', name: 'Колесо обозрения «Балтика»', type: RideType.ferris, year: 2020, status: RideStatus.downtime),
      Ride(id: 'r10', parkId: 'p3', name: 'Цепная карусель «Ветер»', type: RideType.carousel, year: 2019, status: RideStatus.active),
      Ride(id: 'r11', parkId: 'p3', name: 'Семейные горки «Вихрь»', type: RideType.family, year: 2021, status: RideStatus.active),
      Ride(id: 'r12', parkId: 'p4', name: 'Качели «Тулпар»', type: RideType.swing, year: 2018, status: RideStatus.active),
      Ride(id: 'r13', parkId: 'p4', name: 'Экстрим-аттракцион «Вертикаль»', type: RideType.extreme, year: 2023, status: RideStatus.downtime),
      Ride(id: 'r14', parkId: 'p5', name: 'Волновые качели «Прибой»', type: RideType.swing, year: 2017, status: RideStatus.active),
      Ride(id: 'r15', parkId: 'p5', name: 'Колесо обозрения «Солнце»', type: RideType.ferris, year: 2016, status: RideStatus.active),
    ],
    'downtimes': [
      Downtime(id: 'd1', rideId: 'r2', reason: DowntimeReason.repair, techId: 't1', start: h(26), comment: 'Замена оси опорных катков, обнаружен износ сверх допуска'),
      Downtime(id: 'd2', rideId: 'r9', reason: DowntimeReason.parts, techId: 't2', start: d(3).subtract(const Duration(hours: 4)), planned: now.add(const Duration(days: 4)), comment: 'Ожидание подшипника главного узла'),
      Downtime(id: 'd3', rideId: 'r13', reason: DowntimeReason.diagnostics, techId: 't3', start: h(5), comment: 'Вибрация опорной конструкции, экспертное обследование'),
      Downtime(id: 'd4', rideId: 'r8', reason: DowntimeReason.retired, techId: 't4', start: d(18), comment: 'Выработка ресурса, планируется демонтаж'),
      Downtime(id: 'd5', rideId: 'r3', reason: DowntimeReason.diagnostics, techId: 't3', start: d(6), end: d(6).add(const Duration(hours: 3)), comment: 'Плановое обследование карусели', done: 'Осмотр выполнен'),
      Downtime(id: 'd6', rideId: 'r5', reason: DowntimeReason.repair, techId: 't1', start: d(12), end: d(11), comment: 'Течь насоса', done: 'Замена уплотнений'),
      Downtime(id: 'd7', rideId: 'r14', reason: DowntimeReason.parts, techId: 't2', start: d(20), end: d(16), comment: 'Износ цепей подвеса', done: 'Замена цепей'),
      Downtime(id: 'd8', rideId: 'r11', reason: DowntimeReason.diagnostics, techId: 't3', start: d(9), end: d(9).add(const Duration(hours: 5)), comment: 'Диагностика тормозов', done: 'Замечаний нет'),
    ],
    'incidents': [
      Incident(id: 'i1', rideId: 'r2', type: IncidentType.breakdown, severity: Severity.critical, status: IncidentStatus.inProgress, techId: 't1', ts: h(27), desc: 'Аварийная остановка состава, эвакуация'),
      Incident(id: 'i2', rideId: 'r9', type: IncidentType.noise, severity: Severity.major, status: IncidentStatus.inProgress, techId: 't2', ts: d(3).subtract(const Duration(hours: 6)), desc: 'Скрежет в узле крепления гондол'),
      Incident(id: 'i3', rideId: 'r13', type: IncidentType.defect, severity: Severity.major, status: IncidentStatus.isNew, techId: 't3', ts: h(6), desc: 'Трещина сварного шва опоры'),
      Incident(id: 'i4', rideId: 'r1', type: IncidentType.noise, severity: Severity.minor, status: IncidentStatus.resolved, techId: 't4', ts: d(2), desc: 'Скрип в кабине №7', resolvedTs: d(1)),
      Incident(id: 'i5', rideId: 'r3', type: IncidentType.minor, severity: Severity.minor, status: IncidentStatus.resolved, techId: 't1', ts: d(4), desc: 'Заедание фиксатора', resolvedTs: d(4).add(const Duration(hours: 2))),
      Incident(id: 'i6', rideId: 'r8', type: IncidentType.breakdown, severity: Severity.critical, status: IncidentStatus.resolved, techId: 't4', ts: d(18), desc: 'Отказ гидравлики', resolvedTs: d(17)),
      Incident(id: 'i7', rideId: 'r6', type: IncidentType.minor, severity: Severity.minor, status: IncidentStatus.resolved, techId: 't2', ts: d(8), desc: 'Сбой датчика', resolvedTs: d(8).add(const Duration(hours: 3))),
      Incident(id: 'i8', rideId: 'r5', type: IncidentType.breakdown, severity: Severity.major, status: IncidentStatus.resolved, techId: 't1', ts: d(12), desc: 'Течь насоса', resolvedTs: d(11)),
      Incident(id: 'i9', rideId: 'r11', type: IncidentType.defect, severity: Severity.minor, status: IncidentStatus.resolved, techId: 't3', ts: d(10), desc: 'Потёртость ремня безопасности', resolvedTs: d(9)),
      Incident(id: 'i10', rideId: 'r12', type: IncidentType.noise, severity: Severity.minor, status: IncidentStatus.resolved, techId: 't4', ts: d(15), desc: 'Стук в шарнире', resolvedTs: d(14)),
      Incident(id: 'i11', rideId: 'r14', type: IncidentType.defect, severity: Severity.major, status: IncidentStatus.resolved, techId: 't2', ts: d(20), desc: 'Износ звена цепи', resolvedTs: d(16)),
      Incident(id: 'i12', rideId: 'r15', type: IncidentType.minor, severity: Severity.minor, status: IncidentStatus.resolved, techId: 't1', ts: d(1), desc: 'Сбой иллюминации', resolvedTs: h(20)),
      Incident(id: 'i13', rideId: 'r7', type: IncidentType.defect, severity: Severity.minor, status: IncidentStatus.inProgress, techId: 't3', ts: d(5), desc: 'Люфт поручня'),
      Incident(id: 'i14', rideId: 'r1', type: IncidentType.minor, severity: Severity.minor, status: IncidentStatus.isNew, techId: 't2', ts: h(12), desc: 'Кратковременная остановка привода'),
    ],
    'employees': [
      // Super
      Employee(
        id: 'adm0',
        name: 'Владелец',
        pin: '9999',
        role: EmployeeRole.superAdmin,
      ),
      // Regional admin
      Employee(
        id: 'adm1',
        name: 'Ирина Соколова',
        phone: '+7 900 100-00-00',
        pin: '0000',
        role: EmployeeRole.regionalAdmin,
        regionId: 'reg1',
        jobTitle: 'Региональный директор',
      ),
      // Park admins
      Employee(
        id: 'adm2',
        name: 'Олег Кузнецов',
        phone: '+7 900 200-00-00',
        pin: '1000',
        role: EmployeeRole.parkAdmin,
        parkId: 'p1',
      ),
      Employee(
        id: 'adm3',
        name: 'Елена Морозова',
        phone: '+7 900 300-00-00',
        pin: '2000',
        role: EmployeeRole.parkAdmin,
        parkId: 'p2',
      ),
      // Operators
      Employee(
        id: 'op1',
        name: 'Алексей Смирнов',
        phone: '+7 900 555-11-22',
        pin: '1111',
        role: EmployeeRole.operator,
      ),
      Employee(
        id: 'op2',
        name: 'Мария Орлова',
        phone: '+7 900 555-33-44',
        pin: '2222',
        role: EmployeeRole.operator,
      ),
      Employee(
        id: 'op3',
        name: 'Денис Волков',
        phone: '+7 900 555-55-66',
        pin: '3333',
        role: EmployeeRole.operator,
      ),
      Employee(
        id: 'op4',
        name: 'Ольга Никитина',
        phone: '+7 900 555-77-88',
        pin: '4444',
        role: EmployeeRole.operator,
      ),
      // Technicians
      Employee(
        id: 't1',
        name: 'Иванов Иван',
        phone: '+7 900 111-22-33',
        pin: '0001',
        role: EmployeeRole.technician,
        jobTitle: 'Старший механик',
      ),
      Employee(
        id: 't2',
        name: 'Петров Пётр',
        phone: '+7 900 222-33-44',
        pin: '0002',
        role: EmployeeRole.technician,
        jobTitle: 'Электромеханик',
      ),
      Employee(
        id: 't3',
        name: 'Сидорова Анна',
        phone: '+7 900 333-44-55',
        pin: '0003',
        role: EmployeeRole.technician,
        jobTitle: 'Инженер по диагностике',
      ),
      Employee(
        id: 't4',
        name: 'Кузнецов Дмитрий',
        phone: '+7 900 444-55-66',
        pin: '0004',
        role: EmployeeRole.technician,
        jobTitle: 'Механик',
      ),
    ],
    'regions': [
      Region(id: 'reg1', name: 'Москва Юг', parkIds: ['p1', 'p2']),
      Region(id: 'reg2', name: 'Москва Север', parkIds: []),
      Region(id: 'reg3', name: 'Санкт-Петербург', parkIds: ['p3']),
      Region(id: 'reg4', name: 'Казань', parkIds: ['p4']),
      Region(id: 'reg5', name: 'Сочи', parkIds: ['p5']),
    ],
    'operatorLinks': [
      OperatorParkLink(id: 'lnk1', operatorId: 'op1', parkId: 'p1',
          status: LinkStatus.approved, initiatorAdminId: 'adm1',
          approverAdminId: 'adm2', approvedAt: DateTime.now()),
      OperatorParkLink(id: 'lnk2', operatorId: 'op2', parkId: 'p1',
          status: LinkStatus.approved, initiatorAdminId: 'adm1',
          approverAdminId: 'adm2', approvedAt: DateTime.now()),
      OperatorParkLink(id: 'lnk3', operatorId: 'op3', parkId: 'p2',
          status: LinkStatus.approved, initiatorAdminId: 'adm2',
          approvedAt: DateTime.now()),
      OperatorParkLink(id: 'lnk4', operatorId: 'op4', parkId: 'p3',
          status: LinkStatus.approved, approvedAt: DateTime.now()),
    ],
    'vacancies': [],
    'applications': [],
  };
}