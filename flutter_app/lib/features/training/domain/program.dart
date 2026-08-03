class ProgramItem {
  final String name;
  final int sets;
  final String reps;
  const ProgramItem(this.name, this.sets, this.reps);
}

class ProgramDay {
  final String focus;
  final List<ProgramItem> items;
  const ProgramDay(this.focus, this.items);
}
