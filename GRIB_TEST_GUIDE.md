# Guide de test - Visualisation des GRIBs

## 🧪 Test rapide

### Prérequis
- L'app Kornog est compilée et peut se lancer
- Au moins un chart avec des bouées est défini
- Vous avez accès au panneau "Couches météo" (☁️ icône)

### Étapes de test

#### 1. **Vérifier que les fichiers GRIB existent**

```bash
ls -la lib/data/datasources/gribs/repositories/GFS_0p25/20251025T12/
```

Vous devriez voir des fichiers comme:
- `gfs.t12z.pgrb2.0p25.f000`
- `gfs.t12z.pgrb2.0p25.f003`
- etc.

Si rien n'existe, téléchargez d'abord des données:
1. Ouvrez le panneau "Couches météo"
2. Sélectionnez `GFS 0.25°`
3. Sélectionnez `wind10m`
4. Cliquez "Télécharger la sélection"

#### 2. **Afficher les GRIBs sur la carte**

1. Allez sur la page **Charts**
2. Assurez-vous qu'une carte est visible (tuiles OSM)
3. Ouvrez le panneau **"Couches météo"** (☁️ icône)
4. Vérifiez que le switch **"Afficher les GRIBs"** est **ON** (bleu)
5. Cliquez sur une **variable** comme `wind10m`

**Résultat attendu:**
- 🎨 Un heatmap coloré (bleu→rouge) apparaît sur la carte
- 📍 Le heatmap couvre la zone géographique du cours
- 💬 Un toast "GRIB wind10m chargé" s'affiche

#### 3. **Contrôler l'opacité**

Dans le panneau "Couches météo":
1. Localisez le **slider d'opacité** (TODO: à ajouter)
2. Déplacez-le pour voir l'effet sur le heatmap
3. Valeur proche de 0 = transparent, proche de 1 = opaque

#### 4. **Changer de variable**

1. Cliquez sur une autre variable (ex: `mslp`)
2. Le heatmap se met à jour
3. Les couleurs peuvent changer selon les valeurs

#### 5. **Masquer les GRIBs**

1. Utilisez le switch "Afficher les GRIBs" pour OFF (gris)
2. Le heatmap disparaît
3. Réactivez pour le voir réapparaître

---

## 🔍 Débogage

### Les GRIBs ne s'affichent pas?

**Vérification 1: Fichiers présents?**
```bash
find lib/data/datasources/gribs/ -name "*.f0*" | head -5
```

**Vérification 2: Switch activé?**
- Allez dans "Couches météo"
- Vérifiez que "Afficher les GRIBs" = ON

**Vérification 3: Logs de console**
Regardez la console pour les messages `[GRIB]`:
```
[GRIB] Erreur lors du chargement: ...
GRIB wind10m chargé
```

**Vérification 4: Carte visible?**
- Les GRIBs ne s'affichent que si une carte (tuiles OSM) est visible
- Vérifiez que le bouton "Cartes Marines" est activé

### Les données semblent bizarres?

**C'est normal !** Les données affichées sont actuellement une **sinusoïde de test**.

Le vrai parsing GRIB n'est pas implémenté. Les données affichées sont générées par:
```dart
// grib_file_loader.dart - ligne ~45
final value = math.sin(...) * math.cos(...);
values[iy * nx + ix] = (value * 10 + 15).toDouble(); // Vent: 5..25 m/s
```

Pour avoir de vraies données:
1. Installez `eccodes` ou `cfgrib`
2. Intégrez le parsing dans `grib_file_loader.loadGridFromGribFile()`

### La carte scintille?

C'est normal lors du chargement. Si le scintillement persiste:
1. Assurez-vous que `IgnorePointer` enveloppe la couche GRIB
2. Vérifiez que `shouldRepaint()` n'est pas appelé trop souvent

---

## 📊 Tests détaillés

### Test 1: Rendering correct

```dart
// Dans course_canvas.dart
// Vérifier que le Stack contient:
Stack(
  children: [
    // 1. Tuiles de carte
    if (displayMaps && activeMap != null) FutureBuilder(...),
    
    // 2. GRIB layer ← NOUVEAU
    if (gribGrid != null) IgnorePointer(...),
    
    // 3. Course painter
    RepaintBoundary(...),
  ],
)
```

### Test 2: Projection correcte

Les coordonnées doivent être transformées:
```
lon/lat (grille GRIB)
    ↓
Geographic (GRIB → système géo)
    ↓
Local (système géo → Mercator local en mètres)
    ↓
Screen (local → pixels écran via ViewTransform)
```

Pour vérifier:
1. Vous devriez voir le heatmap aligné avec la carte OSM
2. Les couleurs devraient couvrir la zone définie à la création

### Test 3: Opacité

Vérifiez que l'opacité est bien appliquée:
```dart
// Dans GribGridPainter
Opacity(
  opacity: gribOpacity, // 0..1
  child: CustomPaint(...),
)
```

### Test 4: Sélection variable

À chaque clic sur une variable:
1. ✅ onSelected est appelé
2. ✅ findGribFiles() cherche les fichiers
3. ✅ loadGridFromGribFile() charge les données
4. ✅ Providers sont mis à jour
5. ✅ CourseCanvas se redessine avec la nouvelle grille

---

## 📋 Checklist de validation

- [ ] Les fichiers GRIB existent sur disque
- [ ] Le panneau "Couches météo" est accessible
- [ ] Le switch "Afficher les GRIBs" fonctionne
- [ ] Cliquer sur une variable affiche un heatmap
- [ ] Le heatmap est aligné avec la carte
- [ ] L'opacité peut être contrôlée (TODO)
- [ ] Changer de variable change le heatmap
- [ ] Pas d'erreurs dans la console

---

## 🚀 Si tout fonctionne

Bravo! Les GRIBs s'affichent correctement. 

**Prochaines améliorations:**
1. ✅ Parsing GRIB réel (eccodes/cfgrib)
2. ✅ Support des vecteurs (vent U/V)
3. ✅ Slider temps (f000/f003/f006/...)
4. ✅ Sélecteur palette couleurs
5. ✅ Intégration courants (RTOFS)

---

**Besoin d'aide?** Regardez `GRIB_USAGE_GUIDE.md`
