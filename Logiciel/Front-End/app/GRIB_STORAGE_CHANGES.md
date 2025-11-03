# Changements pour la gestion des fichiers GRIB et Cartes "hors application"

## Résumé des modifications

### 1. **Nouvelles fonctions dans `lib/common/kornog_data_directory.dart`**
   - `getGribDataDirectory()` : retourne `~/.local/share/kornog/KornogData/grib`
   - `getMapDataDirectory()` : retourne `~/.local/share/kornog/KornogData/maps`
   - Les deux suivent le même pattern que `getKornogDataDirectory()`
   - Compatibles avec tous les OS (Android, iOS, Linux, Windows, macOS)

### 2. **Modifications dans `lib/data/datasources/gribs/grib_download_controller.dart`**
   - Importe `getGribDataDirectory` de `kornog_data_directory.dart`
   - Ligne 113 : `final out = outDirOverride ?? await getGribDataDirectory();`
   - Les fichiers téléchargés vont maintenant dans le bon répertoire utilisateur

### 3. **Modifications dans `lib/data/datasources/gribs/grib_file_loader.dart`**
   - Importe `getGribDataDirectory` de `kornog_data_directory.dart`
   - La fonction `findGribFiles()` maintenant :
     - Appelle `await getGribDataDirectory()` pour obtenir le chemin
     - Cherche les fichiers dans ce répertoire au lieu du chemin relatif
     - Entoure le tout dans un try-catch robuste
     - Affiche des logs détaillés pour le débogage

### 4. **Modifications dans `lib/data/datasources/maps/providers/map_providers.dart`**
   - Utilise `getMapDataDirectory()` au lieu de `getKornogDataDirectory()`
   - Ligne 17 : `final dir = await getMapDataDirectory();`
   - Les cartes sont maintenant stockées dans un sous-dossier dédié

### 5. **Nouveau fichier `lib/data/datasources/gribs/grib_providers.dart`**
   - Provider Riverpod `gribStorageDirectoryProvider`
   - Suit le même pattern que `mapStorageDirectoryProvider`

## Structure finale

```
~/.local/share/kornog/KornogData/
├── grib/                    ← Fichiers GRIB (météo, courants, etc.)
│   └── GFS_0p25/
│       ├── 20251103T12/
│       │   ├── gfs.t12z.pgrb2.0p25.f003
│       │   ├── gfs.t12z.pgrb2.0p25.f006
│       │   └── ... (autres fichiers)
│       └── 20251025T12/
│
└── maps/                    ← Cartes marines téléchargées
    └── map_1761499342184_43.526_6.990/
```

## Avantages

1. **Séparation claire** : GRIB et cartes dans des dossiers distincts
2. **Logique unifiée** : Les deux utilisent le même système de répertoires
3. **"Hors application"** : Les fichiers ne sont pas supprimés lors d'un nettoyage
4. **Multi-plateforme** : Utilise les API corrects pour chaque système
5. **Retrocompatibilité** : Les anciens fichiers peuvent être migrés facilement
6. **Débogage** : Logs détaillés pour tracer les problèmes

## Migration des fichiers existants

Les fichiers GRIB ont été copiés :

```bash
# GRIB
cp -r lib/data/datasources/gribs/repositories/GFS_0p25 ~/.local/share/kornog/KornogData/grib/

# Cartes (migration automatique lors du premier lancement)
```

## Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `lib/common/kornog_data_directory.dart` | ✅ Ajout `getGribDataDirectory()` et `getMapDataDirectory()` |
| `lib/data/datasources/gribs/grib_download_controller.dart` | ✅ Utilise `getGribDataDirectory()` |
| `lib/data/datasources/gribs/grib_file_loader.dart` | ✅ Utilise `getGribDataDirectory()` |
| `lib/data/datasources/maps/providers/map_providers.dart` | ✅ Utilise `getMapDataDirectory()` |
| `lib/data/datasources/gribs/grib_providers.dart` | ✅ Nouveau provider |

## Test

1. Lancez l'app : `flutter run -d linux`
2. Allez à "Gérer les fichiers gribs"
3. Sélectionnez une variable (ex: wind10m)
4. Les fichiers devraient être trouvés (plus de message "Aucun fichier GRIB trouvé")
5. Les logs montreront :
   ```
   [GRIB_LOADER] Cherchant les fichiers GRIB dans: /home/fefe/.local/share/kornog/KornogData/grib
   [GRIB_LOADER] Répertoire trouvé, listing...
   [GRIB_LOADER] Trouvé XX fichiers GRIB
   ```

## Note pour les futurs téléchargements

- **GRIBs** : Vont automatiquement dans `~/.local/share/kornog/KornogData/grib/`
- **Cartes** : Vont automatiquement dans `~/.local/share/kornog/KornogData/maps/`
