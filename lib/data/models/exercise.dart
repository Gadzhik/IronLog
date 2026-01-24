import 'package:isar_community/isar.dart';

part 'exercise.g.dart';

enum ExerciseType { strength, cardio }

@collection
class Exercise {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  @Index(type: IndexType.value, caseSensitive: false)
  late String category;
  
  @Enumerated(EnumType.ordinal)
  ExerciseType type = ExerciseType.strength; 
}
