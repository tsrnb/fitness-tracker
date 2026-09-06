# Vital Animations Integration Plan — Flutter Gym App

## 1. Objective

Integrate the Vital Animations exercise library into the existing Flutter gym app so that each exercise can display its corresponding animation.

The implementation should provide:

- Vital exercise animation assets
- Exercise → animation mapping
- Self-hosted animation files
- CDN delivery
- Flutter video rendering
- Animation loading/error handling
- Caching
- A reusable animation widget
- Ability to search/filter exercises using Vital metadata
- Architecture that allows Vital to be replaced later

### Out of scope

- Exercise detail screen
- Workout screen
- Workout tracking
- Sets/reps
- Workout plans
- Exercise progression
- Exercise-specific business logic

---

## 2. Architecture

```text
                 VITAL ANIMATIONS
                       │
                       │ ZIP
                       ▼
              ┌─────────────────┐
              │ MP4 + JSON      │
              └────────┬────────┘
                       │
                  Import / Validate
                       │
                       ▼
              ┌─────────────────┐
              │ Backend / DB    │
              │ Exercise Data   │
              └────────┬────────┘
                       │
                       ├──────────────┐
                       │              │
                       ▼              ▼
                Exercise API       CDN
                       │              │
                       │              │ MP4
                       ▼              ▼
                  Flutter App ◄───────┘
                       │
                       ▼
             Exercise Animation
                   Widget
```

---

## 3. Vital Dataset Ingestion

### 3.1 Obtain the Vital pack

Download the Vital Animations pack and keep the original ZIP as the source asset.

Do not assume a specific filename/folder structure until the actual pack is inspected.

### 3.2 Extract

Extract:

- JSON metadata
- MP4 animations
- Any provided thumbnails/posters
- Any provided licensing/readme information

### 3.3 Validate

Create a validation script that checks:

- Every exercise has an ID.
- Every exercise has a name.
- Every animation has an identifiable exercise mapping.
- Every referenced MP4 exists.
- No duplicate IDs.
- No duplicate exercises.
- No orphaned MP4s.
- No malformed JSON.

---

## 4. Create Our Own Exercise Schema

Do not make Flutter depend directly on Vital's JSON structure.

Create an internal model.

```dart
class Exercise {
  final String id;
  final String name;

  final String? bodyPart;
  final String? equipment;
  final String? target;

  final List<String> secondaryMuscles;

  final String? difficulty;
  final String? category;

  final String? description;
  final List<String> instructions;

  final ExerciseMedia? media;
}
```

Media:

```dart
class ExerciseMedia {
  final String? videoUrl;
  final String? thumbnailUrl;
}
```

---

## 5. Provider Abstraction

Do not couple the application directly to Vital throughout the codebase.

Use generic application-level models:

```text
Exercise
ExerciseMedia
ExerciseRepository
ExerciseAnimationWidget
```

Internally:

```text
ExerciseRepository
       │
       ▼
Vital Provider
```

Later this can support:

```text
ExerciseRepository
       │
       ├── Vital
       ├── Custom
       └── Other Provider
```

The rest of the application should not care where the animation came from.

---

## 6. Store Animations Outside the Flutter Application

Do not put MP4 files inside Flutter's `assets/` directory.

Avoid:

```text
flutter_app/
└── assets/
    └── exercises/
        ├── bench_press.mp4
        ├── squat.mp4
        ├── deadlift.mp4
        └── ...
```

Instead:

```text
Object Storage
       ↓
CDN
       ↓
https://cdn.yourapp.com/exercises/...
```

This prevents the app binary from becoming unnecessarily large.

---

## 7. CDN Structure

Use a predictable structure:

```text
cdn.yourapp.com/
└── exercises/
    ├── bench_press_barbell/
    │   ├── animation.mp4
    │   └── thumbnail.jpg
    │
    ├── barbell_squat/
    │   ├── animation.mp4
    │   └── thumbnail.jpg
    │
    └── conventional_deadlift/
        ├── animation.mp4
        └── thumbnail.jpg
```

The actual IDs should be generated from your internal exercise IDs.

---

## 8. Backend API

Expose normalized exercise data through the existing backend.

Example:

```http
GET /api/exercises
```

Response:

```json
{
  "data": [
    {
      "id": "bench_press_barbell",
      "name": "Barbell Bench Press",
      "bodyPart": "chest",
      "equipment": "barbell",
      "target": "pectorals",
      "videoUrl": "https://cdn.yourapp.com/exercises/bench_press_barbell/animation.mp4",
      "thumbnailUrl": "https://cdn.yourapp.com/exercises/bench_press_barbell/thumbnail.jpg"
    }
  ]
}
```

Flutter should consume this normalized API rather than Vital's raw JSON.

---

## 9. Flutter Animation Component

Create one reusable component:

```text
ExerciseAnimationWidget
```

Usage:

```dart
ExerciseAnimationWidget(
  exercise: exercise,
)
```

It should handle:

### Initial state

Display thumbnail/poster while the animation loads.

### Loaded

Automatically play the MP4.

### Error

Display a non-blocking error state with retry.

The animation component should be reusable anywhere in the existing app.

---

## 10. Animation Behavior

For Vital exercise animations:

- Autoplay
- Loop continuously
- Muted
- No visible playback controls
- Preserve aspect ratio
- Do not stretch the character
- Do not crop important parts of the exercise
- Stop playback when the widget leaves the screen where appropriate

Example:

```dart
ExerciseAnimationWidget(
  exercise: exercise,
  autoPlay: true,
  loop: true,
  muted: true,
)
```

These should have sensible defaults so callers do not need to specify them every time.

---

## 11. Exercise List Optimization

If the existing gym app has an exercise list/grid, do not load all MP4s simultaneously.

Use:

```text
Exercise List
     │
     ├── Thumbnail
     ├── Thumbnail
     ├── Thumbnail
     ├── Thumbnail
     └── Thumbnail
```

Only load the animation when the relevant exercise is actually being viewed/selected.

This is especially important when the library grows to hundreds of exercises.

---

## 12. Caching

Implement video caching.

First visit:

```text
Exercise
   ↓
CDN
   ↓
Play
   ↓
Cache
```

Next visit:

```text
Exercise
   ↓
Local cache
   ↓
Play
```

Use an LRU-style cache so old videos are automatically removed.

Suggested initial limit:

**500 MB–1 GB**

The cache limit should be configurable rather than hardcoded.

---

## 13. Network Behavior

The animation component should handle:

### Good connection

```text
Thumbnail
   ↓
MP4 loads
   ↓
Autoplay
```

### Slow connection

```text
Thumbnail
   ↓
Loading indicator
   ↓
MP4 begins playback
```

### No connection

```text
Cached?
 ├── YES → Play cached animation
 └── NO  → Show unavailable state
```

### Failed request

```text
Unable to load animation

[Retry]
```

A failed animation must never crash or block the rest of the exercise UI.

---

## 14. Search and Filter Metadata

If the existing app has an exercise catalogue, import Vital's metadata so it can be used for:

- Exercise name
- Muscle group
- Equipment
- Target muscle
- Secondary muscles
- Difficulty
- Category

Example:

```text
Chest
 ├── Barbell Bench Press
 ├── Incline Bench Press
 └── Dumbbell Fly

Back
 ├── Lat Pulldown
 ├── Barbell Row
 └── Seated Cable Row
```

Filtering/search functionality can remain part of the existing exercise catalogue.

---

## 15. Asset Update Process

Asset updates should not be a manual Flutter task.

Create an ingestion command/process:

```text
vital.zip
    ↓
extract
    ↓
validate
    ↓
normalize
    ↓
generate manifest
    ↓
upload MP4s
    ↓
update database
    ↓
publish
```

When a larger Vital library is purchased, the same process should be reusable.

---

## 16. Database

Suggested exercise table:

```text
exercises
--------------------------------
id
name
body_part
equipment
target
difficulty
category
description
instructions
provider
provider_exercise_id
video_url
thumbnail_url
is_active
created_at
updated_at
```

Example:

```text
id:
bench_press_barbell

provider:
vital

provider_exercise_id:
<Vital ID>

video_url:
https://cdn.yourapp.com/...

is_active:
true
```

---

## 17. Admin / Content Controls

The backend should support basic controls even if there is no admin UI initially.

It should be possible to:

- Activate/deactivate an exercise
- Change exercise name
- Change metadata
- Replace animation URL
- Replace thumbnail
- Add custom animation
- Mark an exercise as deprecated

This prevents the frontend from being tightly coupled to the vendor dataset.

---

## 18. Analytics

Add basic animation telemetry:

```text
exercise_animation_loaded
exercise_animation_failed
exercise_animation_played
```

Useful properties:

```json
{
  "exerciseId": "bench_press_barbell",
  "provider": "vital",
  "loadTimeMs": 842,
  "cached": false
}
```

Do not track continuous playback events every few seconds.

---

## 19. Testing

### Unit tests

Test:

- Vital → internal model conversion
- Missing animation
- Missing metadata
- Invalid URLs
- Duplicate IDs
- Provider mapping

### Widget tests

Test:

- Loading state
- Successful video
- Error state
- Retry
- Missing thumbnail
- Autoplay configuration

### Device testing

Test:

- iOS
- Android
- Wi-Fi
- Mobile data
- Slow network
- Offline
- Cached video
- Large exercise lists

---

## 20. Out of Scope

Explicitly keep these out of this implementation:

```text
❌ Exercise detail screen
❌ Workout screen
❌ Workout tracking
❌ Sets/reps
❌ Exercise logging
❌ Workout programs
❌ Progress tracking
❌ Exercise recommendations
❌ Exercise substitutions
❌ AI workout generation
❌ Personalization
```

The deliverable is simply:

> A reusable exercise-animation infrastructure that allows any existing Flutter exercise UI to display the corresponding Vital animation.

---

## 21. Final Implementation Flow

```text
             VITAL ZIP
                 │
                 ▼
       ┌───────────────────┐
       │ Dataset Ingestion  │
       └─────────┬─────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
    Metadata             MP4
        │                 │
        ▼                 ▼
    Database            CDN
        │                 │
        └────────┬────────┘
                 ▼
             Backend API
                 │
                 ▼
            Flutter App
                 │
                 ▼
       ExerciseAnimationWidget
                 │
        ┌────────┴────────┐
        ▼                 ▼
     Thumbnail          MP4
                          │
                       Cache
```

---

## Core Engineering Deliverable

The agent should ultimately be able to implement:

```dart
ExerciseAnimationWidget(
  exercise: exercise,
)
```

The widget should handle:

**thumbnail → loading → CDN video → autoplay → looping → caching → error handling**

without the calling screen needing to know anything about Vital.

---

## Recommended Implementation

Use:

**Vital Free Pack → Cloudflare R2/CDN → Backend exercise manifest → Flutter → video player**

rather than:

**Vital ZIP → Flutter assets**

This keeps the Flutter application lightweight, allows media to be updated independently of app releases, and provides a clean path to upgrading from the free pack to a larger Vital dataset later.
