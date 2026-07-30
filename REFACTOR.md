# iReader Web — Refactor Roadmap

Minimal, incremental improvements without rewriting the whole app.

## Done

- [x] Fix RC edit screens writing to wrong Firestore collections
- [x] Add `lib/core/firestore_collections.dart` for shared collection names
- [x] Add `lib/services/auth_service.dart` (Google sign-in + role resolution)
- [x] Wire `AuthGate` / `RoleGate` for session persistence on refresh
- [x] Apply `AppTheme` in `main.dart`

## Next (recommended order)

### Phase 1 — Shared data access (low risk)
1. Add `lib/services/student_service.dart` — CRUD used by admin/RC/teacher student screens
2. Add `lib/services/assessment_service.dart`
3. Add `lib/services/practice_set_service.dart`
4. Replace inline `FirebaseFirestore.instance` calls in one feature at a time (start with students)

### Phase 2 — Dedupe UI (medium effort)
1. Merge the three `student_profile.dart` files into one screen with a `UserRole` parameter
2. Merge `manage_student.dart` copies the same way
3. Merge practice-set screens (`manage_wr_ps`, `add_sentences`, etc.)
4. Extract shared widgets: data tables, confirm dialogs, export button

### Phase 3 — Navigation & shell (medium effort)
1. Add a shared `AppShell` sidebar filtered by role
2. Replace scattered `Navigator.pushReplacement` with named routes or `go_router`
3. Remove cross-role imports (RC should not import admin screens)

### Phase 4 — Platform & quality
1. Wrap `dart:html` usage behind a web download helper with `kIsWeb` guards
2. Add Firestore security rules (server-side authorization)
3. Add widget tests for auth flow and one CRUD flow
4. Resolve README merge conflict and document setup/deploy steps

## Target structure

```
lib/
  core/
    firestore_collections.dart
  auth/
    login.dart
    rolegate.dart
  services/
    auth_service.dart
    student_service.dart      ← next
    assessment_service.dart   ← next
  model/
  widgets/                    ← shared UI components
  features/
    students/
    assessments/
    practice_sets/
  theme.dart
  main.dart
```

## Rule of thumb

When touching a screen for a bug fix or feature, move its Firestore calls into the matching service file instead of adding more logic to the widget.
