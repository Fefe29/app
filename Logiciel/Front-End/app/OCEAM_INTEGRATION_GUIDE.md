# Intégration OSeaM Streaming - Documentation Complète

## 📋 Vue d'ensemble

Vous pouvez maintenant sélectionner un mode **OSeaM Standard (Streaming)** via le menu des cartes dans la toolbar de chart. Ce mode vous permet d'afficher les cartes marines OSeaM en temps réel via leur API REST, sans nécessité de téléchargement préalable.

**Avantages:**
- Pas de stockage local nécessaire
- Données toujours à jour
- Basculement facile entre cartes téléchargées et OSeaM
- API officielle OSeaM standard

---

## 🔧 Architecture Technique

### 1. **Modèles de données** (`map_tile_set.dart`)

#### Ajouts:
```dart
enum MapSource {
  local,    // Cartes téléchargées localement
  oceam,    // OSeaM standard en streaming
}

enum MapDownloadStatus {
  // ... existants ...
  streaming // Nouveau: flux continu OSeaM
}
```

- **Raison**: Distinguer les sources de cartes (fichiers vs API)

### 2. **Service OSeaM** (`oceam_tile_service.dart` - NOUVEAU)

Service pour récupérer les tuiles OSeaM via HTTP:

```dart
class OSeaMTileService {
  Future<Uint8List?> getTile(int x, int y, int z)
  Future<Map<String, Uint8List?>> getTiles(List<(int,int,int)> coords)
}
```

**Caractéristiques:**
- Cache en mémoire (100 tuiles par défaut)
- Rate limiting automatique (500ms entre requêtes)
- Timeout configurable (10s)
- Gestion gracieuse des erreurs
- Statistiques de requêtes

### 3. **Providers** (`map_providers.dart`)

#### Nouveaux providers:

```dart
// Service OSeaM singleton
final oceamTileServiceProvider = Provider<OSeaMTileService>

// État d'activation OSeaM
final oceamActiveProvider = NotifierProvider<OSeaMActiveNotifier, bool>

// Carte virtuelle OSeaM
final activeMapProvider = Provider<MapTileSet?> 
// (adapté pour retourner une carte virtuelle OSeaM si actif)
```

#### Logique de sélection:
```
SI oceamActive = true
  → Afficher OSeaM (désactiver cartes téléchargées)
SINON SI displayMaps = true
  → Afficher cartes téléchargées
SINON
  → Aucune carte
```

### 4. **Layer OSeaM** (`oceam_tile_layer.dart` - NOUVEAU)

Couche de rendu pour les tuiles OSeaM:

```dart
class OSeaMTilePainter extends CustomPainter {
  // Dessine les tuiles avec projection géographique
}

class OSeaMLayeredTile {
  int x, y, z;
  ui.Image image;
}
```

**Projection:**
- Conversion tuile (x,y,z) → lat/lon (Web Mercator)
- Projection via mercator service (même système que le parcours)
- Dessin avec `canvas.drawImageRect`

### 5. **Menu Toolbar** (`map_toolbar_button.dart`)

#### Nouvel élément dans le menu:

```
┌─ Cartes Marines ─────────────────────┐
│ ☁  OSeaM Standard (Streaming) [🟢 ON]│
│ ─────────────────────────────────────│
│ ⬇ Afficher cartes téléchargées [  ] │
│ ─────────────────────────────────────│
│ Cartes disponibles:                  │
│   ✓ Carte 1 (15 MB)                 │
│   Carte 2 (8 MB)                    │
│ ...                                  │
└─────────────────────────────────────┘
```

**Comportement:**
- Switch pour activer/désactiver OSeaM
- Icône cloud_download_outlined
- Couleur verte quand actif
- Désactive automatiquement les cartes téléchargées quand activé

### 6. **Canvas d'affichage** (`course_canvas.dart`)

#### Intégration dans la pile de dessin:

```dart
Stack(
  children: [
    // 1. Cartes (OSeaM OU téléchargées)
    Consumer(
      builder: (_, ref, __) {
        if (ref.watch(oceamActiveProvider)) {
          return OSeaMTilePainter(...) // OSeaM
        } else if (displayMaps && activeMap != null) {
          return MultiLayerTilePainter(...) // Local
        }
        return SizedBox.shrink();
      },
    ),
    
    // 2. GRIB overlays (vent, etc.)
    // ... existing code ...
    
    // 3. Parcours (buées, lignes, etc.)
    // ... existing code ...
  ],
)
```

#### Méthode helper: `_loadOSeaMTilesForView`

```dart
Future<List<OSeaMLayeredTile>> _loadOSeaMTilesForView(
  WidgetRef ref,
  MercatorCoordinateSystemService mercatorService,
  CourseState course,
  ViewTransform view,
)
```

- Calcule les tuiles visibles basées sur le parcours
- Charge en parallèle (max 4 concurrent)
- Retourne les tuiles décodées en images Flutter

---

## 🎯 Flux d'utilisation

### 1. **Activation OSeaM**

```
Utilisateur clique sur icon "Cartes" 
→ Menu apparaît
→ Utilisateur toggle "OSeaM Standard (Streaming)" 
→ `oceamActiveProvider.notifier.setActive(true)`
→ `mapDisplayProvider.notifier.toggle(false)` (cartes désactivées)
→ Canvas se rafraîchit et affiche OSeaM
```

### 2. **Chargement des tuiles**

```
Course rendue à zoom 15
→ `_loadOSeaMTilesForView()` called
→ Parcours scannée (buées, lignes)
→ Tuiles visibles calculées (avec marge)
→ `oceamService.getTile(x, y, z)` pour chaque tuile
→ Images décodées et cachées
→ Painter dessine sur canvas
```

### 3. **Basculement cartes**

```
Utilisateur toggle "Afficher cartes téléchargées"
→ `mapDisplayProvider.notifier.toggle(true)`
→ `oceamActiveProvider.notifier.setActive(false)` 
→ OSeaM désactivé automatiquement
→ Cartes téléchargées affichées
```

---

## 📊 Structure de fichiers

```
lib/
├── data/datasources/maps/
│   ├── models/
│   │   └── map_tile_set.dart (MODIFIÉ: MapSource, streaming status)
│   ├── services/
│   │   ├── multi_layer_tile_service.dart (existant)
│   │   └── oceam_tile_service.dart ✨ NOUVEAU
│   └── providers/
│       └── map_providers.dart (MODIFIÉ: oceam providers)
│
├── features/charts/
│   └── presentation/widgets/
│       ├── map_toolbar_button.dart (MODIFIÉ: menu OSeaM)
│       └── course_canvas.dart (MODIFIÉ: affichage OSeaM)
│
└── features/mapview/layers/
    └── oceam_tile_layer.dart ✨ NOUVEAU
```

---

## 🔌 API OSeaM

### URL de base
```
https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png
```

### Paramètres
- `z`: niveau de zoom (1-18 typiquement, 15 utilisé ici)
- `x`, `y`: coordonnées slippy tile

### Exemple
```
https://tiles.openseamap.org/seamark/15/16383/10975.png
```

### Rate Limiting
- Respecté: 100ms délai entre requêtes
- User-Agent: `Kornog/1.0 (OSeaM Tile Fetcher)`
- Timeout: 10 secondes par requête

---

## 🚀 Utilisation

### 1. **Sélectionner OSeaM**
1. Cliquez sur l'icône "🗺️" (Gestion des cartes) dans la toolbar
2. Trouvez "OSeaM Standard (Streaming)"
3. Cliquez sur le switch pour l'activer

### 2. **Voir les tuiles se charger**
- Status affichant "Chargement OSeaM..."
- Tuiles s'affichent progressivement
- Zoom: automatiquement à niveau 15

### 3. **Interagir avec la carte**
- **Pan**: glisser-déposer comme les cartes téléchargées
- **Zoom**: molette souris
- **Tuiles**: se chargent automatiquement au besoin

### 4. **Revenir aux cartes téléchargées**
1. Cliquez sur "Afficher cartes téléchargées"
2. Sélectionnez une carte dans la liste
3. OSeaM se désactive automatiquement

---

## ⚙️ Configuration

### OSeaM Service (`oceam_tile_service.dart`)

```dart
OSeaMConfig(
  tileBaseUrl: 'https://tiles.openseamap.org/seamark', // URL de base
  timeout: Duration(seconds: 10),                       // Timeout HTTP
  cacheSize: 100,                                       // Tuiles en cache
)
```

### Zoom OSeaM (`course_canvas.dart`)

```dart
const zoom = 15; // Niveau de détail fixe
```

Peut être ajusté selon les besoins (14-18 recommandé).

---

## 🐛 Dépannage

### "OSeaM: Aucune tuile"
- **Cause**: Aucune buée / parcours vide
- **Solution**: Créez un parcours avec des buées

### "Erreur OSeaM: connexion timeout"
- **Cause**: Serveur OSeaM indisponible ou réseau lent
- **Solution**: Vérifiez la connexion, réessayez

### Tuiles pixelisées
- **Normal**: Niveau de zoom 15 est très détaillé
- **Solution**: Zoom avant (scroll wheel) pour voir le détail

### Pas d'image OSeaM
- **Cause**: Cache plein, ou service non initialisé
- **Solution**: Rechargez l'app

---

## 📈 Performances

| Métrique | Valeur |
|----------|--------|
| Tuiles par vue | 4-12 (selon parcours) |
| Requêtes parallèles | 4 max |
| Délai entre requêtes | 100ms |
| Timeout par requête | 10s |
| Cache mémoire | 100 tuiles |
| Taille / tuile | ~15-30 KB |
| Temps d'affichage | 1-5 secondes (réseau) |

---

## 🔐 Limitations

1. **Pas de persistance**: Les tuiles ne sont pas sauvegardées (cache mémoire uniquement)
2. **Connectivité requise**: Toujours besoin d'une connexion Internet active
3. **Zoom fixe**: Niveau 15 pour tous les parcours
4. **Attribution**: OSeaM doit être crédité (déjà dans leurs tuiles)

---

## 🎓 Concepts clés

### Web Mercator
- Projection cartographique standard pour les tuiles
- Latitude/Longitude ↔ Pixel (via mercatorService)
- Utilisée par OSM, Google Maps, OSeaM, etc.

### Slippy Tile Coordinates
- Format standard: `z/x/y.png`
- `z`: zoom (niveau de détail)
- `x`, `y`: position horizontale/verticale
- Conversion: lat/lon → x/y via formules mathématiques

### Cache Strategy
- En-mémoire: tuiles récemment chargées
- Clé: `z/x/y` (32-64 octets par clé)
- Valeur: image PNG (15-30 KB)

---

## 📚 Prochaines étapes possibles

1. **Persistance sur disque**: Sauvegarder les tuiles OSeaM localement (comme les cartes)
2. **Zoom dynamique**: Adapter le niveau de zoom selon le zoom du canvas
3. **Chiffres de crédit**: Afficher les informations OSeaM à l'écran
4. **Mode offline**: Combiner cartes téléchargées + cache OSeaM
5. **Selection multiple**: Afficher OSeaM + cartes téléchargées simultanément

---

## ✅ Checklist de test

- [ ] Toggle OSeaM active dans le menu
- [ ] Tuiles apparaissent progressivement
- [ ] Pan/zoom fonctionne correctement
- [ ] Basculement vers cartes téléchargées
- [ ] Aucun crash lors du changement
- [ ] Performance acceptable (< 2s pour chargement)
- [ ] Gestion erreurs réseau
- [ ] Cache fonctionne (2e affichage rapide)

---

## 📞 Support

Pour des questions sur l'intégration OSeaM:
- Consultez la documentation officielle: https://www.openseamap.org/
- Vérifiez les conditions d'utilisation de l'API
- Testez avec l'URL de base directement dans le navigateur

---

**Version**: 1.0  
**Date**: Novembre 2025  
**Statut**: ✅ Implémentation complète
