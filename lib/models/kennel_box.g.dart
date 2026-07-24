// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kennel_box.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KennelBoxAdapter extends TypeAdapter<KennelBox> {
  @override
  final int typeId = 1;

  @override
  KennelBox read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KennelBox(
      supabaseId: fields[0] as String?,
      name: fields[1] as String,
      notes: fields[2] as String?,
      updatedAt: fields[3] as DateTime?,
      synced: fields[4] as bool,
      capacity: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, KennelBox obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.supabaseId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.synced)
      ..writeByte(5)
      ..write(obj.capacity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KennelBoxAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
