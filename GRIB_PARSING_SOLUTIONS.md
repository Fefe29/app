# 🔧 Solution pour Parser les GRIB Réels

## 🎯 Problème
- ✅ Les fichiers GRIB sont téléchargés correctement (NOMADS/GFS)
- ❌ Dart/Flutter ne peut pas parser nativement les GRIB2
- ❌ `eccodes` est une dépendance C lourde, très complexe sur Flutter

## 🚀 Solutions Possibles (du plus facile au plus complexe)

### ✨ Option 1: **grib_dump (RECOMMANDÉ - Facile)**
Utiliser l'outil système `wgrib2` pour extraire les données en texte/JSON

**Avantages:**
- ✅ Aucune dépendance Dart/Flutter
- ✅ Facile à configurer
- ✅ Rapide

**Étapes:**
```bash
# 1. Installer wgrib2
sudo apt-get install wgrib2

# 2. Extraire les données du GRIB
wgrib2 gfs.t12z.pgrb2.0p25.f012 -csv out.csv

# 3. Charger le CSV en Dart
```

### ✨ Option 2: **Python Script Local**
Créer un service Python qui parse GRIB et retourne JSON

**Avantages:**
- ✅ Full control
- ✅ Peut faire du preprocessing

**Setup:**
```python
# grib_parser.py
import grib2io  # ou cfgrib
import json

def parse_grib(filepath):
    data = grib2io.open(filepath)
    return json.dumps({
        'u': data.variables['u10'][...],
        'v': data.variables['v10'][...],
        'lat': data.variables['latitude'][...],
        'lon': data.variables['longitude'][...],
    })
```

### ✨ Option 3: **grib_dart Package**
Utiliser un package Dart qui wraps eccodes

**Avantages:**
- ✅ Solution "Flutter-native"

**Inconvénients:**
- ❌ Très lourd, peut être instable

```yaml
dependencies:
  grib2_dart: ^0.1.0  # Si ça existe...
```

### ✨ Option 4: **Convertir en NetCDF d'abord**
Convertir GRIB → NetCDF (plus facile à parser)

```bash
wgrib2 gfs.t12z.pgrb2.0p25.f012 -netcdf out.nc
```

## 🏆 MON RECOMMANDATION

**Utiliser `wgrib2` + CSV** (Option 1):

### Étape 1: Installation
```bash
# Linux
sudo apt-get install wgrib2

# macOS
brew install wgrib2

# Windows: télécharger depuis https://www.ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/
```

### Étape 2: Créer un Helper Dart
```dart
// lib/data/datasources/gribs/grib_converter.dart
import 'dart:io';
import 'dart:convert';

class GribConverter {
  /// Convertir un fichier GRIB en CSV avec wgrib2
  /// Retourne: List<(lon, lat, u, v)>
  static Future<List<(double, double, double, double)>> extractWindVectors(
    File gribFile,
  ) async {
    // Appeler wgrib2
    final result = await Process.run(
      'wgrib2',
      [gribFile.path, '-csv', '-'],
    );

    if (result.exitCode != 0) {
      throw Exception('wgrib2 failed: ${result.stderr}');
    }

    // Parser le CSV
    final lines = (result.stdout as String).split('\n');
    final vectors = <(double, double, double, double)>[];

    for (final line in lines) {
      if (line.isEmpty) continue;
      try {
        final parts = line.split(',');
        // CSV format: record,id,grid,sub_grid,lat,lon,value
        vectors.add((
          double.parse(parts[5]), // lon
          double.parse(parts[4]), // lat
          0.0, // placeholder u
          double.parse(parts[6]), // placeholder v (value)
        ));
      } catch (e) {
        // Skip malformed lines
      }
    }

    return vectors;
  }
}
```

### Étape 3: Utiliser dans grib_file_loader.dart
```dart
// Remplacer la génération de test
final vectors = await GribConverter.extractWindVectors(gribFile);
// ... créer ScalarGrid à partir des données réelles
```

## 🛠️ Alternative: Utiliser cfgrib (Python)

Si vous préférez une solution plus robuste:

```bash
# Installer cfgrib (Python package)
pip install cfgrib

# Créer un service wrapper
python3 -c "
import cfgrib
import json
import sys

grib = cfgrib.open_datasets(sys.argv[1])[0]
print(json.dumps({
    'u10': grib['u10'].values.tolist(),
    'v10': grib['v10'].values.tolist(),
    'lat': grib['latitude'].values.tolist(),
    'lon': grib['longitude'].values.tolist(),
}))
" gfs_file.grib2
```

## 📋 Checklist pour Intégration

- [ ] Installer `wgrib2` sur le système
- [ ] Créer `GribConverter` qui appelle `wgrib2`
- [ ] Modifier `GribFileLoader.loadGridFromGribFile()` pour utiliser le converter
- [ ] Tester avec un vrai fichier GRIB
- [ ] Vérifier que les données s'affichent correctement

## 🚫 Pourquoi pas eccodes natif ?

- 🔴 eccodes est écrit en C/Fortran
- 🔴 Très difficile à compiler pour Flutter (Android/iOS)
- 🔴 Nécessite des platform channels complexes
- 🔴 Pas de package Dart mature et stable

**Conclusion: L'approche système (`wgrib2`) est PLUS simple et PLUS stable que d'essayer d'utiliser eccodes directement en Dart.**

---

Voulez-vous que j'implémente la solution `wgrib2` + CSV ?
