# Guide Rapide - Visualiser les GRIBs Correctement

## 🎯 Ce qui devrait se passer maintenant

1. ✅ **Plus de lag/scintillement** quand tu ouvres le panneau "Couches météo"
2. ✅ **Le GRIB s'affiche uniquement sur Europe Ouest** (pas partout en vert)
3. ✅ **Les couleurs sont alignées avec la carte** (pas décalées)

---

## 📋 Comment tester

### Étape 1: Lancer l'app
```bash
cd Logiciel/Front-End/app
flutter run
```

### Étape 2: Aller sur Charts
- Clique sur l'onglet **Charts**
- Assure-toi d'avoir au moins une bouée définie

### Étape 3: Afficher les GRIBs
1. **Clique sur l'icône ☁️ (Couches météo)** dans la barre d'outils
2. L'écran **ne doit pas scintiller** (sinon = problème)
3. **Clique sur `wind10m`** ou une autre variable
4. 🎨 **Un heatmap bleu→rouge doit apparaître** sur la région Bretagne/Manche

### Étape 4: Vérifie l'alignement
- Zoome/dézoom sur la carte (boutons +/-)
- Le GRIB doit rester aligné avec la carte OSM
- Si c'est décalé = problème de projection

---

## 🐛 Dépannage

### Problème: Je vois toujours du vert partout
**Cause**: La grille couvre le monde entier (ancien code)

**Fix**: Supprime le cache Flutter
```bash
flutter clean
flutter pub get
flutter run
```

### Problème: Ça scintille toujours beaucoup
**Cause**: Le RepaintBoundary n'a pas fonctionné ou il y a un autre problème

**Vérification**:
1. Ouvre `course_canvas.dart` ligne ~280
2. Assure-toi que `RepaintBoundary` enveloppe bien le GRIB
3. Regarde la console pour les erreurs

### Problème: Le GRIB est bien petit/décalé
**Cause**: Problème de projection (lon/lat → Mercator → écran)

**Vérification**:
1. Zoome beaucoup sur la région Bretagne (-10 à 0°, 45-50°)
2. Le GRIB doit remplir environ 1/4 de l'écran
3. Si c'est minuscule = projection incorrecte

---

## 🔧 Ajustements possibles

### Agrandir/réduire le GRIB affiché

Si tu veux une zone différente, modifie `grib_file_loader.dart` ligne ~45:

```dart
// Zone actuelle: Bretagne/Manche
final lon0 = -12.0;   // ← Change ici pour décaler à l'ouest/est
final lat0 = 41.0;    // ← Change ici pour décaler au sud/nord
final nx = 68;        // ← Plus grand = zone plus grande
final ny = 44;        // ← Plus grand = zone plus grande
```

### Exemples de zones
```dart
// Atlantique Nord complet
lon0 = -20.0; lat0 = 30.0; nx = 120; ny = 100;

// Méditerranée
lon0 = -6.0; lat0 = 30.0; nx = 80; ny = 60;

// Nord Europe (UK, Scandinavie)
lon0 = -5.0; lat0 = 48.0; nx = 100; ny = 80;
```

### Modifier l'opacité du GRIB
**Dans le code** (car pas encore d'UI):
```dart
// course_canvas.dart
ref.read(gribOpacityProvider.notifier).setOpacity(0.3); // 0 = transparent, 1 = opaque
```

---

## 📊 Résumé des fixes

| Problème | Cause | Fix |
|----------|-------|-----|
| Lag/scintillement | Pas d'isolation de rendu | `RepaintBoundary` |
| Vert partout | Grille mondiale | Grille Europe seulement |
| Décalage visuel | Validation manquante | Vérifications `isNaN` |

---

## ✅ Checklist finale

- [ ] App compile sans erreurs (`flutter run` réussit)
- [ ] Pas de scintillement en ouvrant "Couches météo"
- [ ] GRIB apparaît uniquement sur Bretagne/Manche
- [ ] GRIB aligné avec carte OSM (zoome pour vérifier)
- [ ] Sélectionner différentes variables fonctionne
- [ ] Zoom/pan n'affecte pas le GRIB négativement

---

## 🚀 Prochaines améliorations

1. **Slider opacité** dans le panneau
2. **Vrai parsing GRIB** (remplacer sinusoïde)
3. **Sélecteur région** (zone déroulante)
4. **Sélecteur temps** (f000/f003/f006...)
5. **Support vecteurs** (flèches vent au lieu de heatmap)

---

**Besoin d'aide?** Consulte `GRIB_FIX_v2.md` pour plus de détails
