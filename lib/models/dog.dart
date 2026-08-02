import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';  // 🔥 AGGIUNGI QUESTO IMPORT

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

  @HiveField(7)
  String? breed;

  @HiveField(8)
  String serviceType;

  Dog({
    this.supabaseId,
    required this.name,
    this.owner,
    this.phone,
    this.notes,
    this.breed,
    this.serviceType = 'pensione',
    this.updatedAt,
    this.synced = false,
  }) {
    if (supabaseId == null || supabaseId!.isEmpty) {
      this.supabaseId = 'local_${const Uuid().v4()}';
    }
  }

  Color get serviceColor {
    return serviceType == 'asilo' ? Colors.orange : Colors.blue;
  }

  String get serviceLabel {
    return serviceType == 'asilo' ? '🎨 Asilo' : '🏠 Pensione';
  }

  IconData get serviceIcon {
    return serviceType == 'asilo' ? Icons.school : Icons.home;
  }
}