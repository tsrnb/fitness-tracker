import 'package:flutter/material.dart';
import '../../../app/app_state.dart';
import '../../progress/presentation/next_kg_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/insight.dart';

/// Maps an insight's id (each id is prefixed by its rule name, see
/// `insight_rules.dart`) to what tapping its action button actually does —
/// kept in one place so the Dashboard slot, the Weight tab card, and the
/// Insights feed don't each reimplement the same routing. Returns null for
/// an insight with nothing sensible to jump to; [InsightCard] already only
/// renders an action button when both [Insight.actionLabel] and this are
/// non-null, so that's a silent, safe fallback rather than a dead button.
VoidCallback? insightAction(
  BuildContext context,
  Insight insight,
  AppState app,
  AppController controller, {
  required void Function(String tab) goTab,
}) {
  if (insight.id.startsWith('weight-log-gap:')) {
    return () => goTab('progress'); // Progress opens on its Weight tab, weigh-in logger right at the top
  }
  if (insight.id.startsWith('plateau:')) {
    return () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NextKgScreen(app: app, controller: controller)));
  }
  if (insight.id.startsWith('sustained-deficit:')) {
    return () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(app: app, controller: controller)));
  }
  return null;
}
