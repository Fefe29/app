# 🎯 GUIDE RAPIDE - Système de Télémétrie (V3.1)

## 🎯 INTERFACE UNIQUE - DRAWER INTÉGRÉ

### 📈 **Onglet Analyse** (Principale)
- **Drawer (Menu latéral ☰)** : Toutes les fonctionnalités intégrées
  - ✅ **Sélection des données** : TWD, TWA, TWS, Vitesse bateau, Polaires
  - ✅ **Enregistrement** : Démarrer/Arrêter/Pause
  - ✅ **Gestion des sessions** : Export/Supprimer

- **Graphiques dynamiques** : Affichés selon sélection du drawer
- **Diagramme polaire** avec sélecteur de force de vent
- **Stats clés** de la dernière session

## 🚀 Utiliser l'interface

### 1️⃣ Ouvrir le menu principal
- Cliquez sur l'**icône ☰** (burger menu) en haut à gauche
- Le **Drawer** s'affiche avec toutes les options

### 2️⃣ Sélectionner les données à afficher
1. Dans le Drawer, cochez les métriques désirées (TWD, TWA, TWS, etc.)
2. Les graphiques s'affichent **automatiquement** sur la page
3. Cliquez **"Appliquer"** ou fermez le drawer

### 3️⃣ Enregistrer une session
1. Ouvrez le Drawer (☰)
2. Cliquez le bouton **⏱️ Enregistrement**
3. Fenêtre de dialogue : Cliquez **"Démarrer"**
4. Le système enregistre automatiquement
5. Cliquez **"Arrêter"** quand terminé
6. Fermez la fenêtre

### 4️⃣ Gérer les sessions
1. Ouvrez le Drawer (☰)
2. Cliquez le bouton **📂 Gérer les Sessions**
3. Fenêtre de dialogue : Liste des sessions
4. Options : Export / Supprimer
5. Fermez la fenêtre

## 🚀 Démarrer un enregistrement

1. Ouvrir l'app KORNOG
2. Naviguer vers **Analyse** → Onglet **"⏱️ Enregistrement"**
3. Cliquer bouton **"Démarrer"** (rouge)
4. Un message confirm : _"✅ Enregistrement démarré: session_1731532800000"_
5. L'enregistrement est actif ! 🔴

## 📊 Voir les données en temps réel

1. Pendant l'enregistrement, aller à l'onglet **"🎯 Données"**
2. Vous voyez :
   - **Statistiques** : Vitesse moyenne/max, vent moyen, # points
   - **Tableau** : Temps, SOG, HDG, TWS, TWD en continu
3. Scroll horizontal pour voir plus de colonnes

## ⏹️ Arrêter l'enregistrement

1. Onglet **"⏱️ Enregistrement"**
2. Cliquer **"Arrêter"** (orange)
3. Message confirm : _"✅ Enregistrement arrêté: 540 points"_
4. Fichier automatiquement compressé et sauvegardé

## 📂 Gérer les fichiers enregistrés

1. Onglet **"📂 Gestion"**
2. Vous voyez liste de toutes les sessions :
   ```
   session_1731532800000    540 points • 12.5 KB    [⋮]
   session_1731532500000    320 points • 7.8 KB     [⋮]
   ```
3. Cliquer les 3 points `[⋮]` pour menu :
   - **Exporter CSV** → Fichier format tabulaire (Excel compatible)
   - **Exporter JSON** → Fichier format brut (Python compatible)
   - **Supprimer** → Suppression définitive

## 📈 Analyser les graphiques

1. Onglet **"📈 Vent"**
2. Vous voyez :
   - Graphiques TWD, TWA, TWS
   - Diagramme polaire
   - Courbe vitesse du bateau
3. Menu `[☰]` en haut-gauche pour filtres (checkboxes)

## 💾 Où sont stockées les données ?

```
~/.kornog/telemetry/sessions/*.gz      ← Fichiers compressés
~/.kornog/telemetry/metadata/*.json    ← Infos sessions
```

## ⚙️ Contrôles spéciaux

| État | Bouton | Effet |
|------|--------|-------|
| **⏹️ Inactif** | Démarrer | Lance enregistrement |
| **🔴 Enregistrement** | Pause | Met en pause |
| **🔴 Enregistrement** | Arrêter | Finalise session |
| **⏸️ En pause** | Reprendre | Continue enregistrement |

## ✅ Checklist démarrage

- [ ] App KORNOG ouverte
- [ ] Données du bateau reçues (TelemetryBus actif)
- [ ] Onglet "⏱️ Enregistrement" visible
- [ ] État affiché comme "⏹️ Inactif"
- [ ] Bouton "Démarrer" clickable (rouge)

## 🐛 Dépannage

### Q: "Aucune session" dans Gestion
- A: Vous n'avez pas encore lancé d'enregistrement
- **Solution**: Démarrer un nouvel enregistrement (onglet 3)

### Q: État reste "Inactif"
- A: Le bouton Démarrer n'a pas été cliqué correctement
- **Solution**: Vérifier que TelemetryBus est actif dans le tableau de bord

### Q: Export ne fonctionne pas
- A: Vérifier les permissions de fichier
- **Solution**: Fichiers exportés dans `/tmp`, vérifier permissions

### Q: Session disparue après suppression
- A: Normal - la suppression est définitive
- **Solution**: Exporter avant suppression pour archiver

## 📖 Workflow complet (exemple)

```
09:00 → Lancer app KORNOG
09:05 → Naviguer Analyse → Enregistrement
09:05 → [Démarrer] → session_1699176300000
09:06 → Onglet Données → Voir stats en temps réel
09:30 → [Arrêter] → Session finalisée (1245 points)
09:31 → Onglet Gestion → [⋮] → Exporter CSV
09:32 → Ouvrir fichier session_1699176300000.csv dans Excel
09:33 → Analyser données : vitesse, vent, heading
10:00 → Nouveau enregistrement...
```

## 🎓 Tips avancés

### Débriefing complet
1. Après enregistrement, exporter session en CSV
2. Ouvrir dans Excel → Créer graphiques comparatifs
3. Ou en Python → Analyse statistique avancée

### Comparaison multi-sessions
1. Enregistrer plusieurs sessions (même parcours, conditions différentes)
2. Exporter chaque session en CSV
3. Python (Pandas) → Croiser données, comparer performances

### Archivage
1. Exporter en JSON (complet)
2. Stocker localement ou cloud
3. Supprimer de l'app une fois archivé

---

**Version**: 2.0  
**Date**: 14 novembre 2025  
**Support**: Vérifier documentation complète dans `TELEMETRY_ANALYSIS_INTEGRATION.md`
