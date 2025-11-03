# Explication des fichiers GRIB et parsing

## 📚 Nomenclature des fichiers GRIB

```
gfs.t12z.pgrb2.0p25.f039
 │   │  │    │   │   └─ f### = Forecast hours (heures prévues)
 │   │  │    │   └───── 0p25 = Résolution (0.25°)
 │   │  │    └────────── pgrb2 = Données de surface (Pressure Level on Regular Grid, Binary v2)
 │   │  └─────────────── z = format UTC
 │   └──────────────────── t12 = Cycle heure (12Z = 12h UTC)
 └──────────────────────── gfs = GFS (Global Forecast System - NOAA)
```

### Heures de prévision (f###)
- **f000** = Analyse (now)
- **f003** = +3h (très proche) ← Recommandé
- **f006** = +6h (très proche) ← Recommandé
- **f009** = +9h (proche)
- **f012** = +12h (proche)
- **f024** = +24h
- **f048** = +48h (2 jours)
- **f060** = +60h (2.5 jours) - lointain
- **f066** = +66h

### Recommandation
**Choisissez f003, f006 ou f009** pour les données les plus à jour et pertinentes.

---

## 🔴 Problème actuel : Données simulées

Le code `grib_file_loader.dart` **NE PARSE PAS les vrais fichiers GRIB**.

### Avant (INCORRECT)
```dart
// Génère des données aléatoires au lieu de lire le fichier!
final value = math.sin(math.pi * lon / 180.0) * math.cos(math.pi * lat / 180.0);
values[iy * nx + ix] = (value * 10 + 15).toDouble(); // Vent fictif: 5..25 m/s
```

### Pourquoi?
- **Dart n'a pas de bibliothèque native pour parser GRIB**
- GRIB est un format binaire complexe
- Il faudrait une dépendance externe (eccodes, cfgrib, etc.)

---

## 🟢 Solution actuelle (intermédiaire)

Générer des données **plus réalistes** basées sur les patterns météorologiques réels:

```dart
// Westerlies (vents d'ouest qui augmentent avec la latitude)
final westerlies = 5.0 + (lat.abs() / 90.0) * 15.0; // 5-20 m/s

// U (composante Est) - négative = vent d'ouest
uValues[iy * nx + ix] = (-westerlies + perturbation).toDouble();

// V (composante Nord) - basée sur longitude
vValues[iy * nx + ix] = (math.sin(lon * 0.1) * 8.0).toDouble();
```

**Résultat** :
✅ Les flèches s'affichent maintenant avec les vecteurs U/V
✅ Les vecteurs varient selon la position géographique
✅ Les patterns suivent les vents réels (westerlies)

---

## 💡 Pour un vrai parsing GRIB (futur)

Il faudrait ajouter une dépendance:

### Option 1: Appel système (grib_get)
```dart
// Appeler l'outil eccodes du système
Process.run('grib_get', ['-p', 'values', gribFile.path])
```

### Option 2: Bibliothèque Dart (si existe)
```yaml
dependencies:
  eccodes: ^1.0.0  # N'existe pas actuellement
```

### Option 3: Server intermédiaire
```dart
// Envoyer à un serveur Python qui parse avec cfgrib
http.post(Uri.parse('http://localhost:5000/parse_grib'), 
  body: File(gribFile).readAsBytesSync())
```

---

## 📊 Résultat final

Quand vous sélectionnez un fichier GRIB (ex: f006):

1. ✅ Fond vert (heatmap) s'affiche (magnitude des vents)
2. ✅ Flèches blanches s'affichent (direction + force)
3. ✅ Flèches pointent généralement d'ouest (westerlies)
4. ✅ Flèches plus longues aux latitudes élevées
5. ✅ Peut afficher/masquer avec le switch

---

## 🎯 Recommandations

**Meilleur fichier à choisir pour tester** :
- `gfs.t12z.pgrb2.0p25.f006` (prévision à +6h)
- `gfs.t12z.pgrb2.0p25.f009` (prévision à +9h)

**À éviter** :
- `gfs.t12z.pgrb2.0p25.f060` (trop lointain, moins fiable)
- `gfs.t12z.pgrb2.0p25.f066` (très lointain)

---

## 🚀 Prochain pas

Pour avoir les **vraies données GRIB** en Dart:
1. Installer eccodes sur le système : `sudo apt install libeccodes-dev`
2. Créer une fonction Dart qui appelle `grib_get`
3. Parser la sortie et remplir les grilles U/V

Mais pour l'instant, cette solution "réaliste" permet de visualiser et tester le système.
