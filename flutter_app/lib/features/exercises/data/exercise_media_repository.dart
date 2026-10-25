import '../../../shared/lib/cloud/api_client.dart';
import '../domain/exercise_media.dart';

/// Resolves an exercise name to its animation.
///
///  * [_vitalAsset] — bundled Vital Animations clips (compressed MP4s in
///    `assets/exercises/`). Move to a CDN later by returning an https URL with
///    `isAsset: false`.
///  * [_gifFallback] — everything else, a remote GIF from a public
///    exercise-animation dataset (media © Gym visual — gymvisual.com) until the
///    full Vital library is licensed.
///
/// Returns null when neither has the exercise — callers treat that as "don't
/// show one", never an error.
/// Where the compressed Vital clips are served from. They live in
/// `assets/exercises/` in this repo and the gh-pages deploy publishes them at
/// this URL (`video/mp4`, CORS `*`) — served over the network rather than as a
/// Flutter asset because `VideoPlayerController.asset` doesn't resolve reliably
/// on Flutter web under a non-root base-href. Point this at a real CDN later.
String get _vitalBase => CloudConfig.cdnUrl.isNotEmpty
    ? '${CloudConfig.cdnUrl}/v1/exercises/'
    : _vitalBaseFallback;
const String _vitalBaseFallback =
    'https://tsrnb.github.io/fitness-tracker/assets/assets/exercises/';

ExerciseMedia? exerciseMediaFor(String exerciseName) {
  final file = _vitalAsset[exerciseName];
  if (file != null) {
    return ExerciseMedia(
      source: '$_vitalBase$file',
      kind: ExerciseMediaKind.mp4,
    );
  }
  final gif = _gifFallback[exerciseName];
  if (gif != null) {
    return ExerciseMedia(
      source: '$_gifCdnBase$gif',
      kind: ExerciseMediaKind.gif,
      attribution: '© Gym visual — gymvisual.com',
    );
  }
  return null;
}

bool hasExerciseAnimation(String exerciseName) =>
    _vitalAsset.containsKey(exerciseName) ||
    _gifFallback.containsKey(exerciseName);

// ── Vital Animations (MP4) — curated from the "50 gym workouts" pack ──────────
const Map<String, String> _vitalAsset = {
  'Arnold Press': 'arnold-press.mp4',
  'Barbell Squat': 'barbell-squat.mp4',
  'Bulgarian Split Squat': 'bulgarian-split-squat.mp4',
  'Cable Lateral Raise': 'cable-lateral-raise.mp4',
  'Dumbbell Lateral Raise': 'dumbbell-lateral-raise.mp4',
  'Dumbbell Shoulder Press': 'dumbbell-shoulder-press.mp4',
  'Front Raise': 'front-raise.mp4',
  'Front Squat': 'front-squat.mp4',
  'Goblet Squat': 'goblet-squat.mp4',
  'Hack Squat': 'hack-squat.mp4',
  'Hip Thrust': 'hip-thrust.mp4',
  'Leg Extension': 'leg-extension.mp4',
  'Leg Press': 'leg-press.mp4',
  'Lying Leg Curl': 'lying-leg-curl.mp4',
  'Machine Hip Abduction': 'machine-hip-abduction.mp4',
  'Machine Lateral Raise': 'machine-lateral-raise.mp4',
  'Machine Shoulder Press': 'machine-shoulder-press.mp4',
  'Overhead Press': 'overhead-press.mp4',
  'Pec Deck Fly': 'pec-deck-fly.mp4',
  'Rear Delt Fly': 'rear-delt-fly.mp4',
  'Rope Tricep Pushdown': 'rope-tricep-pushdown.mp4',
  'Seated Leg Curl': 'seated-leg-curl.mp4',
  'Upright Row': 'upright-row.mp4',
  'Walking Step-Up': 'walking-step-up.mp4',
};

// ── GIF fallback (remote) ────────────────────────────────────────────────────
const String _gifCdnBase = 'https://raw.githubusercontent.com/hasaneyldrm/';

const Map<String, String> _gifFallback = {
  'Ab Wheel Rollout': 'exercises-dataset/main/videos/0857-NAgVB3t.gif',
  'Assisted Pull-Up': 'exercises-dataset/main/videos/0017-kiJ4Z2K.gif',
  'Barbell Bench Press': 'exercises-dataset/main/videos/0025-EIeI8Vf.gif',
  'Barbell Curl': 'exercises-dataset/main/videos/0031-25GPyDY.gif',
  'Barbell Row': 'exercises-dataset/main/videos/0027-eZyBC3j.gif',
  'Cable Crossover': 'exercises-dataset/main/videos/0155-0CXGHya.gif',
  'Cable Crunch': 'exercises-dataset/main/videos/0175-WW95auq.gif',
  'Cable Curl': 'exercises-dataset/main/videos/0868-G08RZcQ.gif',
  'Cable Woodchop': 'exercises-dataset/main/videos/0242-TXtXc84.gif',
  'Chest Supported Row': 'exercises-dataset/main/videos/0574-X3cqyXz.gif',
  'Close Grip Bench Press': 'exercises-dataset/main/videos/0030-J6Dx1Mu.gif',
  'Decline Dumbbell Press': 'exercises-dataset/main/videos/0301-DwhEmmE.gif',
  'Diamond Push-Up': 'exercises-dataset/main/videos/0283-soIB2rj.gif',
  'Dips': 'exercises-dataset/main/videos/0814-X6C6i5Y.gif',
  'EZ Bar Curl': 'exercises-dataset/main/videos/0447-6TG6x2w.gif',
  'Face Pull': 'exercises-dataset/main/videos/0233-ZfyAGhK.gif',
  'Flat Dumbbell Press': 'exercises-dataset/main/videos/0289-SpYC0Kp.gif',
  'Glute Bridge': 'exercises-dataset/main/videos/1409-qKBpF7I.gif',
  'Hammer Curl': 'exercises-dataset/main/videos/0313-slDvUAU.gif',
  'Hanging Leg Raise': 'exercises-dataset/main/videos/0472-I3tsCnC.gif',
  'Hollow Body Hold': 'exercises-dataset/main/videos/0262-rbu5UUb.gif',
  'Incline Barbell Press': 'exercises-dataset/main/videos/0047-3TZduzM.gif',
  'Incline Cable Fly': 'exercises-dataset/main/videos/0171-tBWXbIT.gif',
  'Incline Dumbbell Curl': 'exercises-dataset/main/videos/0318-ae9UoXQ.gif',
  'Incline Dumbbell Press': 'exercises-dataset/main/videos/0314-ns0SIbU.gif',
  'Landmine Press': 'exercises-dataset/main/videos/0562-QYysSLV.gif',
  'Lat Pulldown': 'exercises-dataset/main/videos/0197-qdRxqCj.gif',
  'Machine Ab Crunch': 'exercises-dataset/main/videos/1452-Wgaz7pm.gif',
  'Machine Chest Press': 'exercises-dataset/main/videos/0576-DOoWcnA.gif',
  'Machine High Row': 'exercises-dataset/main/videos/0581-nZZZy9m.gif',
  'Machine Tricep Extension': 'exercises-dataset/main/videos/0607-Ser9eQp.gif',
  'Overhead Cable Tricep Extension':
      'exercises-dataset/main/videos/1722-1xHyxys.gif',
  'Plank': 'exercises-dataset/main/videos/0464-CosupLu.gif',
  'Preacher Curl': 'exercises-dataset/main/videos/0070-qOgPVf6.gif',
  'Pull-Up': 'exercises-dataset/main/videos/0652-lBDjFxJ.gif',
  'Push-Up': 'exercises-dataset/main/videos/0662-I4hDWkc.gif',
  'Reverse Grip Cable Row': 'exercises-dataset/main/videos/0208-PNtsX17.gif',
  'Russian Twist': 'exercises-dataset/main/videos/0687-XVDdcoj.gif',
  'Seated Cable Row': 'exercises-dataset/main/videos/0861-fUBheHs.gif',
  'Seated Calf Raise': 'exercises-dataset/main/videos/0594-bOOdeyc.gif',
  'Single Arm Lat Pulldown': 'exercises-dataset/main/videos/3563-U5INZY6.gif',
  'Skull Crushers': 'exercises-dataset/main/videos/0061-iZop9xO.gif',
  'Smith Machine Bench Press': 'exercises-dataset/main/videos/0748-trqKQv2.gif',
  'Smith Machine Squat': 'exercises-dataset/main/videos/0770-jFtipLl.gif',
  'Standing Calf Raise': 'exercises-dataset/main/videos/1372-8ozhUIZ.gif',
  'Straight Arm Pulldown': 'exercises-dataset/main/videos/0238-x69MAlq.gif',
  'T-Bar Row': 'exercises-dataset/main/videos/0606-aaXr7ld.gif',
  'Weighted Dips': 'exercises-dataset/main/videos/1767-K1vlode.gif',
  'Wide Grip Lat Pulldown': 'exercises-dataset/main/videos/0150-eYnzaCm.gif',
};
