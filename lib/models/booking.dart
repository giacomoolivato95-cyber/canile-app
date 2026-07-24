import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'booking.g.dart';

@HiveType(typeId: 2)
class Booking extends HiveObject {
  @HiveField(0)
  String? supabaseId;

  @HiveField(1)
  String dogId;

  @HiveField(2)
  String boxId;

  @HiveField(3)
  DateTime startDate;

  @HiveField(4)
  DateTime endDate;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  DateTime? updatedAt;

  @HiveField(7)
  bool synced;

  Booking({
    this.supabaseId,
    required this.dogId,
    required this.boxId,
    required this.startDate,
    required this.endDate,
    this.notes,
    this.updatedAt,
    this.synced = false,
  });

  String get formattedStart => DateFormat('dd/MM/yyyy').format(startDate);
  String get formattedEnd => DateFormat('dd/MM/yyyy').format(endDate);
}