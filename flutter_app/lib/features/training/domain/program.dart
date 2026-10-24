class ProgramItem {
  final String name;
  final int sets;
  final String reps;
  /// Target working weight in kg; only custom plans set it.
  final double? kg;
  const ProgramItem(this.name, this.sets, this.reps, [this.kg]);
}

class ProgramDay {
  final String focus;
  final List<ProgramItem> items;
  const ProgramDay(this.focus, this.items);
}
