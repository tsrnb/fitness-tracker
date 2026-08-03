import 'package:flutter/material.dart';

/// Shared animation constants for the `atoms/` widget set — kept in one
/// place so every atom's micro-interactions (press states, tab pills,
/// switchers) move at the same tempo.
const fastAnim = Duration(milliseconds: 180);
const medAnim = Duration(milliseconds: 260);
const easeCurve = Curves.easeOutCubic;
