class AppConstants {
  static const List<String> bodyweightExerciseNames = [
    "Книжка",
    "Планка",
    "Подъем ног в висе",
    "Приседания без веса",
    "Отжимания от пола",
    "Гиперэкстензия",
    "Подтягивания",
    "Отжимания на брусьях",
    "Отжимания от скамьи",
    "Скручивания",
  ];

  static String cleanName(String name) => name.replaceAll('"', '').trim();

  static bool isBodyweight(String? name, String? category) {
    if (name == null) return false;
    final normalizedName = cleanName(name);
    return bodyweightExerciseNames.contains(normalizedName);
  }

  static String getFormattedSet(String exerciseName, dynamic set) {
    final name = cleanName(exerciseName);
    
    if (name == "Планка") {
      return "${set.reps} мин"; 
    }
    
    // Check if bodyweight using the existing list + normalization
    if (bodyweightExerciseNames.contains(name)) {
      return "${set.reps} повт";
    }
    
    return "${set.weight} кг x ${set.reps}";
  }
}
