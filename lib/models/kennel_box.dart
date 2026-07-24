import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'kennel_box.g.dart';

@HiveType(typeId: 1)
class KennelBox extends HiveObject {
  @HiveField(0)
  String? supabaseId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? notes;

  @HiveField(3)
  DateTime? updatedAt;

  @HiveField(4)
  bool synced;

  @HiveField(5)
  int capacity;

  KennelBox({
    this.supabaseId,
    required this.name,
    this.notes,
    this.updatedAt,
    this.synced = false,
    this.capacity = 2,  // Default: 2 cani per box
  }) {
    if (supabaseId == null || supabaseId!.isEmpty) {
      this.supabaseId = 'local_${const Uuid().v4()}';
    }
  }
}