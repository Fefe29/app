# Test de l'Interface d'Analyse des Tendances du Vent

## Objectif
Tester les nouvelles fonctionnalités de configuration des paramètres d'analyse des tendances du vent.

## Fonctionnalités à Tester

### 1. Configuration de la Période d'Analyse ⏱️

**Fonctionnement :**
- Boutons rapides : 5min, 10min, 20min, 30min
- Slider pour ajustement fin (1-60 minutes)
- Période par défaut : 20 minutes

**Tests :**
- [ ] Cliquer sur "5min" → période passe à 5 minutes
- [ ] Cliquer sur "10min" → période passe à 10 minutes  
- [ ] Cliquer sur "20min" → période passe à 20 minutes (défaut)
- [ ] Cliquer sur "30min" → période passe à 30 minutes
- [ ] Utiliser le slider → ajustement précis de 1 à 60 minutes
- [ ] Vérifier l'affichage "Calcul de tendance sur Xmin"

### 2. Configuration de la Sensibilité 🎯

**Fonctionnement :**
- Slider 0.0 à 1.0 (10 divisions)
- Labels : "Faible" → "Forte"
- Affecte la détection des bascules de vent

**Tests :**
- [ ] Déplacer le slider vers "Faible" → sensibilité diminue
- [ ] Déplacer le slider vers "Forte" → sensibilité augmente
- [ ] Vérifier l'impact sur la détection des tendances

### 3. Affichage des Tendances en Temps Réel 📊

**Fonctionnement :**
- Analyse en continu des données TWD/TWA
- Affichage de la tendance actuelle avec couleur
- Informations sur la régression linéaire

**États possibles :**
- 🔴 **Bascule Droite (Veering)** : Vent tourne à droite
- 🔵 **Bascule Gauche (Backing)** : Vent tourne à gauche  
- 🟢 **Vent Stable** : Pas de tendance marquée
- 🟠 **Vent Irrégulier** : Données insuffisantes ou chaotiques

**Tests :**
- [ ] Vérifier l'icône et couleur selon la tendance
- [ ] Contrôler l'affichage de la pente (°/min)
- [ ] Vérifier le nombre de points d'analyse
- [ ] Contrôler le badge "Fiable" / "Peu de données"

### 4. Navigation et Interface 🧭

**Navigation :**
1. Aller à l'onglet "Analyse" 
2. Activer TWD ou TWA dans le menu latéral
3. Le widget de configuration apparaît automatiquement

**Tests :**
- [ ] Widget visible seulement si TWD ou TWA actifs
- [ ] Interface responsive et intuitive
- [ ] Mise à jour en temps réel des paramètres
- [ ] Persistance des réglages entre sessions

## Scénarios de Test

### Scénario 1: Configuration Basique
1. Activer TWD dans l'analyse
2. Modifier la période à 10 minutes
3. Vérifier que l'analyse se base sur les 10 dernières minutes
4. Observer les changements de tendance

### Scénario 2: Sensibilité Fine
1. Régler la sensibilité au minimum
2. Observer les tendances détectées
3. Augmenter progressivement la sensibilité
4. Noter les différences de détection

### Scénario 3: Modes Préconfigurés
1. Utiliser un mode comme `backing_left`
2. Observer les tendances détectées
3. Ajuster les paramètres d'analyse
4. Vérifier la cohérence des résultats

## Résultats Attendus

### ✅ Comportements Corrects
- Configuration intuitive et réactive
- Analyse en temps réel des tendances
- Affichage clair des résultats
- Impact visible des paramètres

### ❌ Problèmes Potentiels
- Latence dans la mise à jour
- Incohérence entre paramètres et résultats
- Interface non responsive
- Erreurs de calcul

## Notes de Performance
- La période d'analyse impacte la réactivité
- Plus de données = analyse plus fiable
- Sensibilité élevée = plus de variations détectées
- Paramètres optimal dépendent des conditions

---
**Date de test :** [À remplir]  
**Version :** 1.0.0  
**Testeur :** [Nom]  
**Résultat global :** [✅ Validé / ❌ À corriger / ⚠️ Avec réserves]