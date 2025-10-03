# 📊 Guide d'Utilisation - Analyse Historique du Vent

## ✨ **Nouvelles Fonctionnalités Ajoutées**

### 🎯 **Graphiques d'Historique du Vent**
- **TWD** (True Wind Direction) - Direction absolue du vent (0-360°)
- **TWA** (True Wind Angle) - Angle au vent (-180 à +180°)  
- **TWS** (True Wind Speed) - Vitesse du vent en nœuds

### 📈 **Visualisation en Temps Réel**
- Collecte automatique des données toutes les secondes
- Affichage graphique avec `fl_chart`
- Historique jusqu'à 300 points (5 minutes)
- Mise à jour automatique de l'interface

---

## 🚀 **Comment Utiliser**

### 1️⃣ **Accéder à l'Analyse**
1. Ouvrez l'application Kornog
2. Naviguez vers l'onglet **"Analysis"**
3. Le graphique du vent s'affiche automatiquement

### 2️⃣ **Contrôler l'Affichage**
1. **Ouvrir les filtres** : Utilisez le menu latéral (hamburger) ☰
2. **Activer/Désactiver** les courbes :
   - ✅ **TWD** (Direction du vent) - Courbe bleue
   - ✅ **TWS** (Vitesse du vent) - Courbe verte  
   - ✅ **TWA** (Angle au vent) - Courbe rouge
3. **Effacer l'historique** : Bouton refresh ↻ sur le graphique

### 3️⃣ **Interpréter les Données**

#### **Courbes Affichées**
- **Ligne Bleue (TWD)** : Direction absolue du vent
  - 0° = Nord, 90° = Est, 180° = Sud, 270° = Ouest
  - Votre configuration actuelle oscille autour de 320° (Nord-Ouest)

- **Ligne Rouge (TWA)** : Angle relatif au bateau
  - Positif = vent vient de tribord (côté droit)
  - Négatif = vent vient de bâbord (côté gauche)
  - Dans vos logs : ~121-130° (vent arrière tribord)

- **Ligne Verte (TWS×10)** : Vitesse du vent (mise à l'échelle ×10)
  - Valeur réelle = valeur affichée ÷ 10
  - Exemple : 140 sur le graphique = 14 nœuds réels

#### **Résumé en Temps Réel**
En bas du graphique, vous voyez :
- **TWD** : Dernière direction mesurée
- **TWA** : Dernier angle mesuré  
- **TWS** : Dernière vitesse mesurée
- **X pts** : Nombre de points collectés

---

## 🔧 **Architecture Technique**

### **Services Créés**
- `WindHistoryService` : Collecte et stockage des données
- `WindHistoryChart` : Widget d'affichage graphique
- Providers Riverpod pour l'état réactif

### **Fichiers Ajoutés**
```
lib/features/analysis/
├── domain/services/
│   └── wind_history_service.dart     # Collecte des données
└── presentation/widgets/
    └── wind_history_chart.dart       # Graphique fl_chart
```

### **Filtres Étendus**
- Ajout de **TWD** dans `AnalysisFilters`
- Interface mise à jour dans le drawer de filtres
- Support des nouvelles métriques

---

## 🎯 **Utilisation Pratique**

### **Analyse Tactique**
1. **Bascules du vent** : Observez les variations de TWD
   - Tendance vers la gauche (backing) : Favorable au bord bâbord
   - Tendance vers la droite (veering) : Favorable au bord tribord

2. **Stabilité du vent** : Analysez les oscillations de TWS
   - Courbe stable : Conditions prévisibles
   - Courbe chaotique : Conditions difficiles

3. **Angles optimaux** : Surveillez TWA pour l'efficacité
   - Près du vent : TWA ~35-45°
   - Travers : TWA ~90°  
   - Portant : TWA ~150-180°

### **Configuration Test**
Votre vent actuel (**mode backing_left**) :
- **Direction de base** : 320° (Nord-Ouest)
- **Bascule** : -3°/min vers la gauche
- **Vitesse** : 14 nœuds
- **Variations** : ±2.5° de bruit

---

## 🛠️ **Personnalisation Avancée**

### **Modifier la Collecte**
Dans `WindHistoryService` :
- `maxPoints` : Nombre max de points (défaut: 300)
- `maxAgeMinutes` : Durée de conservation (défaut: 10 min)
- `updateIntervalMs` : Fréquence de mise à jour (défaut: 1s)

### **Changer l'Affichage**
Dans `WindHistoryChart` :
- Couleurs des courbes
- Échelles des axes
- Style des légendes
- Format des timestamps

---

## 📱 **Interface Utilisateur**

### **Contrôles Disponibles**
- **Refresh** ↻ : Effacer l'historique
- **Légende** : TWD (bleu), TWA (rouge), TWS (vert)
- **Résumé** : Dernières valeurs + nombre de points
- **Filtres** ☰ : Activer/désactiver les courbes

### **États d'Affichage**
- **Loading** : "Collecte des données en cours..."
- **Empty** : "En attente de données..."  
- **Error** : Message d'erreur spécifique
- **Data** : Graphique avec courbes actives

---

## 🎓 **Prochaines Étapes**

### **Extensions Possibles**
1. **Export des données** en CSV
2. **Zoom et pan** sur le graphique
3. **Alertes** sur les changements de vent
4. **Comparaison** entre sessions
5. **Analyse statistique** (moyennes, tendances)

### **Intégration**
- Les données sont déjà disponibles pour d'autres analyses
- Compatible avec le système de routing existant
- Prêt pour l'export vers des outils externes

---

**Votre analyse de vent est maintenant opérationnelle ! 🚀**  
*Les données s'accumulent automatiquement pendant que vous naviguez.*