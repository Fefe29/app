# 🎯 ACCÈS RAPIDE à la Fenêtre d'Analyse Avancée

## Option 1️⃣ : Ajouter un FAB (Bouton flottant) dans l'App Shell

```dart
// Dans lib/app/app_shell.dart, ajouter au Stack après le body:

FloatingActionButton(
  onPressed: () {
    context.go('/analysis/advanced');
  },
  tooltip: '🎯 Analyse Avancée',
  backgroundColor: Colors.blue,
  child: const Icon(Icons.analytics),
),
```

## Option 2️⃣ : Depuis n'importe quel widget
```dart
import 'package:go_router/go_router.dart';

// N'importe où dans ton code:
context.go('/analysis/advanced');
```

## Option 3️⃣ : Via Riverpod (dans un Consumer)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dans un ConsumerWidget:
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        ref.read(goRouterProvider).go('/analysis/advanced');
      },
      child: const Text('Ouvrir Analyse'),
    );
  }
}
```

## Option 4️⃣ : Menu contextuel dans la navigation

Ajouter un MenuItem dans `AnalysisPage`:
```dart
// Dans lib/features/analysis/presentation/pages/analysis_page.dart:

PopupMenuButton<String>(
  itemBuilder: (context) => [
    PopupMenuItem(
      value: 'advanced',
      child: Row(
        children: [
          Icon(Icons.analytics, size: 20),
          SizedBox(width: 8),
          Text('Analyse Avancée'),
        ],
      ),
    ),
  ],
  onSelected: (value) {
    if (value == 'advanced') {
      context.go('/analysis/advanced');
    }
  },
),
```

---

## 🚀 Le plus simple : Copier-coller le bouton

Dans `_HomeShellState` du HomeShell, ajouter ce FAB :

```dart
@override
Widget build(BuildContext context) {
  final idx = _indexFromLocation(widget.location);

  return Scaffold(
    // ... existing code ...
    
    floatingActionButton: FloatingActionButton(
      onPressed: () => context.go('/analysis/advanced'),
      backgroundColor: Colors.blue.shade600,
      child: const Icon(Icons.analytics_outlined, size: 28),
    ),
    
    // ...
  );
}
```

Cela ajoute un bouton bleu "Analyse" en bas-droit de l'écran, accessible partout!

---

## 🧭 Navigation en cascade

**Page Analysis** (existante) → Menu → **Analyse Avancée** (nouveau!)

```
Menu utillisateur
├─ Enregistrer (basic)       → /telemetry-recording
├─ Analyse                   → /analysis
│  └─ Analyse Avancée (NEW!) → /analysis/advanced
└─ Paramètres                → /settings
```

Voilà! Tu peux maintenant naviguer facilement vers la fenêtre.
