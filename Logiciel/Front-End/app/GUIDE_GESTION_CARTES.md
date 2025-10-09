# Guide de Test - Bouton de Gestion des Cartes

## Fonctionnalités Implémentées ✅

### 1. Bouton Cartes dans le Bandeau Horizontal
- **Localisation** : Bandeau horizontal des boutons, à côté du bouton "Importer"
- **Icône** : 🗺️ (icône de carte)
- **Comportement** : Clic ouvre un menu déroulant avec les options

### 2. Options du Menu Cartes

#### A. Téléchargement de Cartes OpenSeaMap
- **Option** : "Télécharger une carte" (icône verte)
- **Fonctionnalité** : Ouvre le dialog de téléchargement de cartes nautiques OpenSeaMap
- **Pré-remplissage** : Utilise automatiquement la zone du parcours si disponible

#### B. Affichage des Cartes
- **Option** : Case à cocher "Afficher les cartes"
- **Fonctionnalité** : Active/désactive l'affichage des tuiles de cartes sur le canvas
- **État par défaut** : Activé

#### C. Sélection de Carte Active
- **Interface** : Liste des cartes téléchargées avec cases cochables
- **Informations affichées** : 
  - Nom de la carte
  - Taille du fichier
  - Niveau de zoom
- **Sélection unique** : Une seule carte peut être active à la fois

#### D. Gestion Avancée des Cartes
- **Option** : "Gérer les cartes" (icône orange)
- **Fonctionnalités** :
  - Voir les informations détaillées de chaque carte
  - Supprimer des cartes avec confirmation
  - Voir les zones géographiques couvertes

### 3. Intégration avec le Système de Rendu

#### A. Providers Riverpod
- `selectedMapProvider` : Gère la carte actuellement sélectionnée
- `mapDisplayProvider` : Contrôle l'affichage des cartes (on/off)
- `activeMapProvider` : Combine les deux pour déterminer quelle carte afficher

#### B. Rendu Conditionnel
- Les tuiles ne sont chargées que si :
  1. L'affichage des cartes est activé
  2. Une carte est sélectionnée
  3. La carte sélectionnée est complètement téléchargée

## Comment Tester

### Test 1 : Accès au Menu
1. Lancer l'application
2. Aller sur l'onglet "Charts"
3. Vérifier la présence de l'icône de carte dans le bandeau horizontal
4. Cliquer sur l'icône → Le menu doit s'ouvrir

### Test 2 : Téléchargement de Carte
1. Dans le menu cartes, cliquer sur "Télécharger une carte"
2. Vérifier que le dialog s'ouvre avec les champs pré-remplis si un parcours existe
3. Tester le téléchargement d'une petite zone

### Test 3 : Affichage/Masquage
1. Dans le menu cartes, utiliser la case "Afficher les cartes"
2. Vérifier que le canvas se met à jour en conséquence

### Test 4 : Sélection de Carte
1. Télécharger plusieurs cartes
2. Dans le menu, sélectionner différentes cartes
3. Vérifier que le canvas utilise la carte sélectionnée

### Test 5 : Gestion des Cartes
1. Cliquer sur "Gérer les cartes"
2. Tester l'affichage des informations
3. Tester la suppression d'une carte

## Architecture Technique

### Fichiers Modifiés/Créés
1. **`map_toolbar_button.dart`** : Nouveau widget pour le bouton et menu
2. **`chart_page.dart`** : Ajout du bouton dans le bandeau horizontal
3. **`map_providers.dart`** : Nouveaux providers pour gestion d'état
4. **`course_canvas.dart`** : Modification pour utiliser la carte sélectionnée

### Structure du Code
```
MapToolbarButton (StatefulWidget)
├── PopupMenuButton avec icône carte
├── Menu Items :
│   ├── Télécharger (→ MapDownloadDialog)
│   ├── Affichage ON/OFF (Switch)
│   ├── Liste cartes (CheckedPopupMenuItem)
│   └── Gérer (→ _MapManagementDialog)
└── _MapManagementDialog
    ├── Liste des cartes avec actions
    ├── Informations détaillées
    └── Suppression avec confirmation
```

### Providers Riverpod
```
selectedMapProvider (String?) ← Carte sélectionnée par ID
mapDisplayProvider (bool) ← Affichage activé/désactivé
activeMapProvider (MapTileSet?) ← Carte à utiliser pour le rendu
```

## Notes Techniques

### Gestion d'État Robuste
- Auto-sélection de la première carte si la sélection actuelle est invalide
- Réinitialisation de la sélection lors de suppression d'une carte
- Synchronisation entre providers pour éviter les incohérences

### Intégration UI/UX
- Menu contextuel moderne avec séparateurs visuels
- Icônes colorées pour différentier les actions
- Cases à cocher pour la sélection de cartes
- Messages informatifs si aucune carte disponible

### Performance
- Chargement des tuiles uniquement pour la carte active
- Pas de re-rendu inutile grâce aux providers Riverpod
- Gestion mémoire optimisée (une seule carte chargée à la fois)

## Statut : ✅ IMPLÉMENTÉ ET TESTÉ - OpenSeaMap
- Toutes les fonctionnalités demandées sont opérationnelles
- Utilise maintenant OpenSeaMap pour les cartes nautiques spécialisées
- L'application compile et fonctionne sans erreur
- L'interface est intuitive et accessible
- Le code est bien structuré et maintenable

## Changement vers OpenSeaMap
- **Serveur de tuiles** : `https://tiles.openseamap.org/seamark`
- **Avantages** : Cartes spécialisées pour la navigation maritime avec sondes, bouées, chenaux, etc.
- **Compatibilité** : Même système de coordonnées et niveaux de zoom qu'OpenStreetMap