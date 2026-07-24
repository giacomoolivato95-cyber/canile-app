import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'dog.g.dart';

@HiveType(typeId: 0)
class Dog extends HiveObject {
  @HiveField(0)
  String? supabaseId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? owner;

  @HiveField(3)
  String? phone;

  @HiveField(4)
  String? notes;

  @HiveField(5)
  DateTime? updatedAt;

  @HiveField(6)
  bool synced;

  Dog({
    this.supabaseId,
    required this.name,
    this.owner,
    this.phone,
    this.notes,
    this.updatedAt,
    this.synced = false,
  }) {
    // Se non c'è un supabaseId, generane uno temporaneo
    if (supabaseId == null || supabaseId!.isEmpty) {
      this.supabaseId = 'local_${const Uuid().v4()}';
    }
  }
}