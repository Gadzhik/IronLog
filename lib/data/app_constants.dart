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

  static bool isMatch(String input, String target) {
    final cleanInput = input.replaceAll('"', '').replaceAll("'", "").trim().toLowerCase();
    final cleanTarget = target.toLowerCase();
    return cleanInput == cleanTarget;
  }

  static String cleanName(String name) => name.replaceAll('"', '').replaceAll("'", "").trim();

  static bool isBodyweight(String? name, String? category) {
    if (name == null) return false;
    for (var target in bodyweightExerciseNames) {
      if (isMatch(name, target)) return true;
    }
    return false;
  }

  static String getFormattedSet(String exerciseName, dynamic set) {
    if (isMatch(exerciseName, "планка")) {
      return "${set.reps} мин"; 
    }
    
    if (isBodyweight(exerciseName, null)) {
      return "${set.reps} повт";
    }
    
    return "${set.weight} кг x ${set.reps}";
  }
}
