// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'footprint_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FootprintModelAdapter extends TypeAdapter<FootprintModel> {
  @override
  final int typeId = 1;

  @override
  FootprintModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FootprintModel(
      id: fields[0] as String,
      poiId: fields[1] as String,
      poiName: fields[2] as String,
      category: fields[3] as String,
      longitude: fields[4] as double,
      latitude: fields[5] as double,
      note: fields[6] as String?,
      checkedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FootprintModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.poiId)
      ..writeByte(2)
      ..write(obj.poiName)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.checkedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FootprintModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
