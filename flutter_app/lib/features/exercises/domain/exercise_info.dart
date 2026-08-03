class ExerciseInfo {
  final String group;
  final String view;
  final List<String> primary;
  final List<String> secondary;
  final String target;
  final String desc;
  final List<String> cues;
  const ExerciseInfo(this.group, this.view, this.primary, this.secondary, this.target, this.desc, this.cues);
}

const List<String> groups = ['Chest', 'Back', 'Shoulders', 'Legs', 'Arms', 'Core'];
