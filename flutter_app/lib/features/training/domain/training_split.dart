import 'package:flutter/material.dart';
import 'program.dart';

/// A selectable weekly training split (e.g. Push/Pull/Legs, Upper/Lower).
/// Each split owns its own day-type -> [ProgramDay] map and default weekly
/// layout, so switching splits swaps the whole training experience (which
/// exercises show up, how many days/week, the calendar strip colors/labels)
/// without touching any other part of the app.
class TrainingSplit {
  final String id;
  final String name;
  final String shortTag; // e.g. "5 days/week"
  final int daysPerWeek;
  final String tagline;
  final String description;
  final IconData icon;

  final Map<String, ProgramDay> program;
  final List<String> dayOrder;

  /// Default schedule, keyed by `DateTime.now().weekday % 7` (0=Sun..6=Sat).
  /// Missing days are rest days.
  final Map<int, String> weekday;

  /// Short 2-letter code per day type, for the weekly calendar strip.
  final Map<String, String> dayAbbr;

  const TrainingSplit({
    required this.id,
    required this.name,
    required this.shortTag,
    required this.daysPerWeek,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.program,
    required this.dayOrder,
    required this.weekday,
    required this.dayAbbr,
  });

  List<String?> defaultSchedule() => List.generate(7, (i) => weekday[i]);
}
