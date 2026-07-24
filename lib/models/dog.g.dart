// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DogAdapter extends TypeAdapter<Dog> {
  @override
  final int typeId = 0;

  @override
  Dog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dog(
      supabaseId: fields[0] as String?,
      name: fields[1] as String,
      owner: fields[2] as String?,
      phone: fields[3] as String?,
      notes: fields[4] as String?,
      updatedAt: fields[5] as DateTime?,
      synced: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Dog obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.supabaseId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.owner)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
