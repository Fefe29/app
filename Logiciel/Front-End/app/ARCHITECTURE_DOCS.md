# Architecture & Documentation des Modules du Front-End Kornog

Ce document centralise la documentation détaillée de chaque fichier Dart sous `lib/`.
Chaque fichier source contient désormais un petit en-tête de commentaire pointant vers ce document. Ce fichier fournit :

- Objectif / Responsabilité
- Classes / providers / widgets principaux
- Dépendances amont (ce qu'il importe conceptuellement)
- Consommateurs aval (qui en dépend) si pertinent
- Points d'extension / comment modifier en sécurité
- Notes / pièges à éviter

---
## Table des matières

### Noyau & Shell de l'application
- [lib/main.dart](#libmaindart)
- [lib/app/app.dart](#libappappdart)
- [lib/app/app_shell.dart](#libappapp_shelldart)
- [lib/app/router.dart](#libapprouterdart)
- [lib/core/widgets/app_scaffold.dart](#libcorewidgetsapp_scaffolddart)

### Thème
- [lib/theme/app_theme.dart](#libthemeapp_themedart)

### Fournisseurs & Modèles Globaux
- [lib/common/providers/app_providers.dart](#libcommonprovidersapp_providersdart)
- [lib/providers.dart](#libprovidersdart)
- [lib/common/models/feature_bindings.dart](#libcommonmodelsfeature_bindingsdart)

### Couche de Données Télémétriques
- [lib/data/datasources/telemetry/telemetry_bus.dart](#libdatadatasourcestelemetrytelemetry_busdart)
- [lib/data/datasources/telemetry/fake_telemetry_bus.dart](#libdatadatasourcestelemetryfake_telemetry_busdart)

### Entités Métier
- [lib/domain/entities/telemetry.dart](#libdomainentitiestelemetrydart)

### Fonctionnalités : Cartes (Domaine + Providers + UI)
- [lib/features/charts/domain/models/boat.dart](#libfeatureschartsdomainmodelsboatdart)
- [lib/features/charts/domain/models/course.dart](#libfeatureschartsdomainmodelscoursedart)
- [lib/features/charts/domain/models/polar_table.dart](#libfeatureschartsdomainmodelspolar_tabledart)
- [lib/features/charts/domain/services/polar_parser.dart](#libfeatureschartsdomainservicespolar_parserdart)
- [lib/features/charts/domain/services/polaire_port.dart](#libfeatureschartsdomainservicespolaire_portdart)
- [lib/features/charts/domain/services/vmc_calculator.dart](#libfeatureschartsdomainservicesvmc_calculatordart)
- [lib/features/charts/domain/services/routing_calculator.dart](#libfeatureschartsdomainservicesrouting_calculatordart)
- [lib/features/charts/domain/services/ado_refus_strategy.dart](#libfeatureschartsdomainservicesado_refus_strategydart)
- [lib/features/charts/domain/services/wind_trend_analyzer.dart](#libfeatureschartsdomainserviceswind_trend_analyzerdart)
- [lib/features/charts/providers/course_providers.dart](#libfeatureschartsproviderscourse_providersdart)
- [lib/features/charts/providers/polar_providers.dart](#libfeatureschartsproviderspolar_providersdart)
- [lib/features/charts/providers/route_plan_provider.dart](#libfeatureschartsprovidersroute_plan_providerdart)
- [lib/features/charts/providers/tactics_providers.dart](#libfeatureschartsproviderstactics_providersdart)
- [lib/features/charts/providers/wind_trend_provider.dart](#libfeatureschartsproviderswind_trend_providerdart)
- [lib/features/charts/presentation/pages/chart_page.dart](#libfeatureschartspresentationpageschart_pagedart)
- [lib/features/charts/presentation/widgets/course_canvas.dart](#libfeatureschartspresentationwidgetscourse_canvasdart)
- [lib/features/charts/presentation/widgets/course_menu.dart](#libfeatureschartspresentationwidgetscourse_menudart)

### Fonctionnalités : Tableau de bord
- [lib/features/dashboard/providers/selected_metrics.dart](#libfeaturesdashboardprovidersselected_metricsdart)
- [lib/features/dashboard/presentation/pages/dashboard_page.dart](#libfeaturesdashboardpresentationpagesdashboard_pagedart)
- [lib/features/dashboard/presentation/widgets/metric_tile.dart](#libfeaturesdashboardpresentationwidgetsmetric_tiledart)
- [lib/features/dashboard/presentation/widgets/metrics_selector_sheet.dart](#libfeaturesdashboardpresentationwidgetsmetrics_selector_sheetdart)

### Fonctionnalités : Analyse
- [lib/features/analysis/providers/analysis_filters.dart](#libfeaturesanalysisprovidersanalysis_filtersdart)
- [lib/features/analysis/presentation/pages/analysis_page.dart](#libfeaturesanalysispresentationpagesanalysis_pagedart)
- [lib/features/analysis/presentation/widgets/analysis_filter_drawer.dart](#libfeaturesanalysispresentationwidgetsanalysis_filter_drawerdart)

### Fonctionnalités : Alarmes
- [lib/features/alarms/providers/regatta_timer_provider.dart](#libfeaturesalarmsprovidersregatta_timer_providerdart)
- [lib/features/alarms/providers/anchor_alarm_provider.dart](#libfeaturesalarmsprovidersanchor_alarm_providerdart)
- [lib/features/alarms/providers/sleep_timer_provider.dart](#libfeaturesalarmsproviderssleep_timer_providerdart)
- [lib/features/alarms/presentation/pages/alarms_page.dart](#libfeaturesalarmspresentationpagesalarms_pagedart)

### Fonctionnalités : Paramètres
- [lib/features/settings/presentation/pages/settings_page.dart](#libfeaturessettingspresentationpagessettings_pagedart)

---

## Conventions
- Tous les providers suivent la convention Riverpod (Notifier/Provider/StreamProvider) : `<chose>Provider`.
- Clés de métriques : `nav.*`, `wind.*`, `env.*` proviennent exclusivement de `FakeTelemetryBus` pour l'instant.
- Vent réel : `wind.twd`, `wind.tws` ; Dérivés : `wind.twa`, `wind.awa`, `wind.aws`.
- `WindSample` (dans `app_providers.dart`) est l'instantané de vent de référence pour les consommateurs.

---

## Documentation des fichiers

### lib/main.dart
**Objectif** : Point d'entrée de l'application, initialise le ProviderScope et le widget App principal.

**Fonction détaillée** : Ce fichier contient la fonction `main()` qui lance l'application Flutter. Il encapsule l'application dans un `ProviderScope` de Riverpod pour permettre la gestion d'état réactive à travers toute l'application. C'est ici que l'on configure les paramètres globaux de l'application comme la gestion des erreurs, les configurations d'environnement (développement/production), et l'initialisation des services externes.

**Clé** : Appel de `runApp()`.

**Extensions possibles** : 
- Ajouter la configuration d'environnement (développement/production)
- Implémenter la gestion d'erreur globale (`FlutterError.onError`)
- Configurer les services de crash reporting
- Initialiser les plugins natifs (GPS, Bluetooth)

### lib/app/app.dart
**Objectif** : Construit le widget racine `MaterialApp` avec le thème et le routage.

**Fonction détaillée** : Ce fichier définit le widget principal de l'application qui configure le thème Material Design, les routes de navigation, la localisation, et les paramètres généraux de l'interface utilisateur. Il sert de pont entre l'initialisation (`main.dart`) et la structure de l'application (`app_shell.dart`). C'est ici que l'on définit les couleurs globales, les polices, et les comportements de navigation.

**Dépend de** : `app_theme.dart`, `router.dart`.

**Extensions possibles** : 
- Ajouter la localisation/internationalisation (i18n)
- Implémenter des overlays globaux (notifications, modales)
- Configurer les boundaries d'erreur
- Ajouter le support du mode sombre/clair

### lib/app/app_shell.dart
**Objectif** : Structure d'enveloppe de l'application (shell) avec navigation (barre du bas ou rail latéral).

**Fonction détaillée** : Le shell est la structure permanente de l'application qui entoure le contenu des pages. Il gère la barre de navigation inférieure ou le rail de navigation latéral, permettant de naviguer entre les différentes fonctionnalités (Tableau de bord, Cartes, Analyse, Alarmes, Paramètres). Ce composant reste visible en permanence et maintient l'état de navigation. Il adapte automatiquement son interface selon la taille d'écran (mobile vs tablette).

**Clés** : Navigation tabs, responsive layout.

**Extensions possibles** : 
- Ajouter de nouveaux onglets de navigation
- Implémenter des drawers globaux
- Ajouter des badges de notification sur les onglets
- Personnaliser l'animation entre les pages

### lib/app/router.dart
**Objectif** : Définitions centrales des routes (configuration GoRouter/Navigator).

**Fonction détaillée** : Ce fichier centralise toute la logique de routage de l'application. Il définit les chemins d'accès vers chaque page, gère les paramètres d'URL, les redirections, et les guards de sécurité. Utilise probablement GoRouter pour une navigation déclarative avec support des liens profonds. Il maintient aussi l'état de navigation et peut gérer les transitions personnalisées entre les pages.

**Extensions possibles** : 
- Ajouter des liens profonds (deep links)
- Implémenter la logique de garde (authentication guards)
- Configurer des redirections conditionnelles
- Ajouter des transitions d'animation personnalisées

### lib/core/widgets/app_scaffold.dart
**Objectif** : Wrapper de scaffold partagé (padding cohérent, arrière-plans, UI système).

**Fonction détaillée** : Ce widget fournit une structure de base réutilisable pour toutes les pages de l'application. Il standardise les marges, les couleurs d'arrière-plan, la gestion de la barre d'état, et les éléments d'interface commune. Permet d'assurer une cohérence visuelle à travers toute l'application et facilite les modifications globales de mise en page.

**Extensions possibles** : 
- Ajouter des éléments d'interface communs (header, footer)
- Implémenter la gestion des états de chargement
- Configurer les SafeAreas pour différents devices
- Ajouter le support des gestes système

### lib/theme/app_theme.dart
**Objectif** : Factory de ThemeData, schéma de couleurs, typographie.

**Fonction détaillée** : Ce fichier définit l'identité visuelle complète de l'application Kornog. Il configure les couleurs primaires et secondaires (probablement inspirées des couleurs nautiques), les tailles et styles de police, les formes des composants (boutons, cartes), et les animations. Peut inclure des thèmes spécifiques pour le contexte nautique (couleurs jour/nuit pour la navigation).

**Extensions possibles** : 
- Ajouter des thèmes de composants personnalisés (ButtonTheme, InputDecorationTheme)
- Implémenter un thème spécial "navigation de nuit"
- Configurer des couleurs pour différents types d'alertes
- Ajouter des animations thématiques

### lib/common/providers/app_providers.dart
**Objectif** : Bus de télémétrie global et providers dérivés.

**Fonction détaillée** : Ce fichier est le cœur de la gestion des données télémétriques de l'application. Il expose le `telemetryBusProvider` qui fournit un flux de données télémétriques en temps réel à travers l'application. Il dérive également des providers pour des métriques spécifiques comme `windSampleProvider` pour simplifier l'accès aux données de vent. Utilise actuellement `FakeTelemetryBus` comme source de données simulées.

**Symboles clés** : `telemetryBusProvider`, `windSampleProvider`, `twaSimModeProvider` (Notifier), `WindSample`.

**Dépend de** : `fake_telemetry_bus.dart`.

**Extensions possibles** : 
- Remplacer `FakeTelemetryBus` par une implémentation réelle du bus NMEA
- Ajouter un mécanisme de mise en cache pour les données télémétriques
- Implémenter des providers dérivés pour des calculs de performance (VMG, VMC)
- Ajouter des tests unitaires pour la logique de dérivation

### lib/providers.dart
**Objectif** : (Alias / consolidation héritée) re-export ou câblage de provider transitoire.

**Fonction détaillée** : Ce fichier agit comme un point de consolidation pour réexporter les providers utilisés à travers l'application. Il permet de simplifier les imports dans d'autres parties de l'application en fournissant des chemins d'accès uniques pour chaque provider. Peut également être utilisé pour des ajustements temporaires lors de la migration vers de nouveaux providers ou de nouvelles structures.

**Note** : Envisager de fusionner complètement dans `app_providers.dart`.

### lib/common/models/feature_bindings.dart
**Objectif** : Structuration de l'activation / enregistrement des fonctionnalités.

**Fonction détaillée** : Ce fichier définit les structures de données utilisées pour activer ou désactiver certaines fonctionnalités au sein de l'application. Il peut s'agir de simples booléens ou de structures plus complexes permettant de configurer des fonctionnalités expérimentales, des tests A/B, ou des options de personnalisation avancées.

**Extensions possibles** : 
- Ajouter des flags de fonctionnalités pour des tests A/B
- Implémenter une logique de chargement dynamique des fonctionnalités
- Ajouter des métadonnées pour la documentation des fonctionnalités
- Intégrer avec un service de configuration à distance

### lib/data/datasources/telemetry/telemetry_bus.dart
**Objectif** : Interface abstraite pour le streaming d'événements télémétriques.

**Fonction détaillée** : Ce fichier définit l'interface `TelemetryBus` qui doit être implémentée par toute source de données télémétriques. Elle inclut des méthodes pour émettre des événements télémétriques, s'abonner à des flux d'événements, et gérer le cycle de vie des connexions. Sert de contrat entre la couche de données et les providers Riverpod.

**Clé** : `TelemetryBus`.

**Extensions possibles** : 
- Implémenter un bus NMEA réel
- Ajouter un bus basé sur WebSocket pour les données en temps réel
- Implémenter un bus de replay pour rejouer des scénarios de test
- Ajouter des tests d'intégration pour les implémentations de bus

### lib/data/datasources/telemetry/fake_telemetry_bus.dart
**Objectif** : Télémétrie simulée déterministe pour le développement et les tests.

**Fonction détaillée** : Ce fichier fournit une implémentation simulée de `TelemetryBus` pour les tests et le développement. Elle émet des données télémétriques simulées à intervalles réguliers, permettant de tester le comportement de l'application sans dépendre de sources de données réelles. Supporte plusieurs modes de vent pour simuler différentes conditions de navigation.

**Clé** : `FakeTelemetryBus`, `TwaSimMode`.

**Extensions possibles** : 
- Ajouter une simulation de dérive
- Intégrer un modèle de vagues aléatoires
- Ajouter des seeds aléatoires pour des scénarios de test variés
- Ajouter des tests de performance pour l'émission de télémétrie

### lib/domain/entities/telemetry.dart
**Objectif** : Modèle de domaine pour les données télémétriques.

**Fonction détaillée** : Ce fichier définit les entités de domaine utilisées pour représenter les données télémétriques au sein de l'application. Cela inclut des modèles pour les instantanés de télémétrie, les mesures individuelles, et les unités de mesure. Ces modèles sont utilisés par les providers pour dériver des métriques spécifiques et par l'UI pour afficher les données télémétriques.

**Extensions possibles** : 
- Ajouter des validateurs pour les données entrantes
- Implémenter des wrappers typés pour différents groupes de mesures
- Ajouter des méthodes utilitaires pour la conversion d'unités
- Ajouter des tests unitaires pour les calculateurs de métriques

### lib/features/charts/domain/models/boat.dart
**Objectif** : Modèle des propriétés statiques et dynamiques du bateau.

**Fonction détaillée** : Ce fichier définit un modèle pour représenter les caractéristiques du bateau, tant statiques (taille, poids, type de coque) que dynamiques (vitesse, direction). Ces informations sont utilisées par les calculateurs de performance pour estimer la vitesse du bateau en fonction des conditions de vent et d'angle.

**Extensions possibles** : 
- Ajouter des propriétés pour les configurations de voiles
- Intégrer des capteurs réels pour les données dynamiques
- Ajouter des méthodes pour estimer les performances sur différentes allures
- Ajouter des tests d'intégration pour les scénarios de navigation

### lib/features/charts/domain/models/course.dart
**Objectif** : Modélisation des parcours, waypoints et bords.

**Fonction détaillée** : Ce fichier définit les modèles utilisés pour représenter un parcours de navigation, y compris les points de passage (waypoints) et les bords. Ces modèles sont utilisés par les calculateurs de routage pour déterminer le meilleur itinéraire vers un objectif donné.

**Extensions possibles** : 
- Ajouter des méthodes pour optimiser les parcours en fonction des courants
- Intégrer des données cartographiques pour la navigation assistée
- Ajouter des tests unitaires pour les calculateurs de routage
- Implémenter un import/export de parcours au format GPX

### lib/features/charts/domain/models/polar_table.dart
**Objectif** : Structure de données pour les polaires de performance.

**Fonction détaillée** : Ce fichier définit la structure de données utilisée pour stocker les polaires de performance du bateau. Les polaires sont des tableaux de référence qui lient la vitesse du bateau à des angles et vitesses de vent spécifiques. Elles sont utilisées par les calculateurs de performance pour estimer la vitesse du bateau en temps réel.

**Clé** : Logique d'interpolation (si présente).

**Extensions possibles** : 
- Ajouter des méthodes d'interpolation pour les valeurs manquantes
- Supporter plusieurs jeux de polaires (par exemple, pour différentes voiles)
- Ajouter des tests unitaires pour les calculateurs de polaires
- Implémenter un import/export de polaires au format CSV

### lib/features/charts/domain/services/polar_parser.dart
**Objectif** : Analyse des formats de définition de polaires externes.

**Fonction détaillée** : Ce fichier fournit des fonctions pour analyser et convertir des fichiers de définition de polaires externes en tables de polaires utilisables par l'application. Cela permet d'importer des polaires depuis des sources externes et de les utiliser pour le calcul de performance.

**Extensions possibles** : 
- Ajouter le support pour plus de formats de fichiers de polaires
- Implémenter des validateurs pour les données de polaires entrantes
- Ajouter des tests d'intégration pour les scénarios d'importation
- Intégrer un éditeur de polaires pour ajuster les valeurs importées

### lib/features/charts/domain/services/polaire_port.dart
**Objectif** : Adaptateur de domaine pour les polaires.

**Fonction détaillée** : Ce fichier agit comme un adaptateur entre les données de polaires brutes et les modèles de domaine utilisés par l'application. Il traduit les données de polaires en objets de domaine et vice versa, permettant une séparation claire entre la couche de données et la logique métier.

**Extensions possibles** : 
- Ajouter des caches pour les polaires fréquemment utilisées
- Implémenter une logique de mise à jour dynamique des polaires
- Ajouter des tests unitaires pour la logique d'adaptation
- Intégrer un service de notification pour les mises à jour de polaires

### lib/features/charts/domain/services/vmc_calculator.dart
**Objectif** : Calculs liés au VMC/VMG.

**Fonction détaillée** : Ce fichier fournit des fonctions pour calculer le VMC (Velocity Made Good to Course) et le VMG (Velocity Made Good) en fonction des données de vent et de cap du bateau. Ces calculs sont essentiels pour optimiser le parcours du bateau en fonction des conditions de vent.

**Extensions possibles** : 
- Ajouter des méthodes pour estimer le temps d'arrivée à un waypoint
- Intégrer des modèles de courant pour affiner les calculs
- Ajouter des tests unitaires pour les calculateurs de VMC/VMG
- Implémenter une logique de prédiction de performance sur plusieurs bords

### lib/features/charts/domain/services/routing_calculator.dart
**Objectif** : Optimisation de parcours, laylines, projections.

**Fonction détaillée** : Ce fichier contient la logique pour calculer et optimiser les parcours de navigation. Cela inclut la détermination des laylines (lignes de limite de virement) et des projections de parcours en fonction des données de vent et des caractéristiques du bateau.

**Extensions possibles** : 
- Ajouter des algorithmes d'optimisation avancés (par exemple, A*)
- Intégrer des données en temps réel sur les courants et les marées
- Ajouter des tests d'intégration pour les scénarios de routage
- Implémenter une visualisation des laylines sur la carte

### lib/features/charts/domain/services/ado_refus_strategy.dart
**Objectif** : Algorithme tactique (éviter le refus / logique de header).

**Fonction détaillée** : Ce fichier définit la logique pour éviter les refus (zones de non-navigation) et optimiser le cap du bateau en fonction des changements de vent. Il utilise des données historiques et en temps réel pour ajuster la stratégie de navigation.

**Extensions possibles** : 
- Ajouter des modèles de prévision de vent à court terme
- Intégrer des capteurs de vent réels pour des ajustements dynamiques
- Ajouter des tests unitaires pour la logique d'évitement de refus
- Implémenter une interface utilisateur pour visualiser les zones de refus

### lib/features/charts/domain/services/wind_trend_analyzer.dart
**Objectif** : Analyse des tendances de changement de vent.

**Fonction détaillée** : Ce fichier analyse les échantillons de vent récents pour détecter des tendances ou des changements significatifs dans la direction ou la vitesse du vent. Cela peut aider à anticiper les changements de conditions de navigation et à ajuster la stratégie en conséquence.

**Extensions possibles** : 
- Ajouter des configurations pour la fenêtre d'averaging, seuils de déviation standard
- Intégrer des alertes pour des changements de vent critiques
- Ajouter des tests unitaires pour les calculateurs de tendances de vent
- Implémenter une visualisation graphique des tendances de vent

### lib/features/charts/providers/course_providers.dart
**Objectif** : Providers Riverpod pour l'état du parcours, la sélection, les superpositions.

**Fonction détaillée** : Ce fichier définit les providers nécessaires pour gérer l'état des parcours de navigation au sein de l'application. Cela inclut la gestion des parcours actifs, des waypoints, et des options de superposition sur les cartes.

**Extensions possibles** : 
- Ajouter des méthodes pour importer/exporter des parcours
- Implémenter une logique de synchronisation des parcours entre appareils
- Ajouter des tests d'intégration pour les scénarios de parcours
- Intégrer un éditeur de parcours pour modifier les waypoints

### lib/features/charts/providers/polar_providers.dart
**Objectif** : Exposer les tables de polaires, vitesses cibles actuelles.

**Fonction détaillée** : Ce fichier définit les providers qui exposent les données de polaires au reste de l'application. Cela inclut les tables de polares pour différents angles et vitesses de vent, ainsi que les vitesses cibles calculées pour le bateau.

**Extensions possibles** : 
- Ajouter des méthodes pour mettre à jour les polaires en temps réel
- Implémenter une logique de sélection de polaire active
- Ajouter des tests unitaires pour les providers de polaires
- Intégrer un service de notification pour les mises à jour de polaires

### lib/features/charts/providers/route_plan_provider.dart
**Objectif** : Fournir le plan de route calculé (bords, ETA) basé sur le vent actuel.

**Fonction détaillée** : Ce fichier définit la logique pour calculer et fournir le plan de route optimal vers un objectif donné, en fonction des données de vent actuelles et des caractéristiques du bateau. Cela inclut la détermination des bords à effectuer, des temps estimés d'arrivée, et des ajustements de cap.

**Extensions possibles** : 
- Ajouter des algorithmes d'optimisation de plan de route
- Intégrer des données en temps réel sur les conditions de mer
- Ajouter des tests d'intégration pour les scénarios de plan de route
- Implémenter une visualisation du plan de route sur la carte

### lib/features/charts/providers/tactics_providers.dart
**Objectif** : Providers d'évaluation tactique (état de lift/header, tack recommandé).

**Fonction détaillée** : Ce fichier définit les providers utilisés pour évaluer les options tactiques en cours de navigation. Cela inclut l'analyse des changements de vent, la détection des lifts et headers, et la recommandation de manœuvres (tacks/gybes).

**Extensions possibles** : 
- Ajouter des modèles de prévision de vent à long terme
- Intégrer des capteurs de vent pour des ajustements tactiques en temps réel
- Ajouter des tests unitaires pour les calculateurs tactiques
- Implémenter une interface utilisateur pour visualiser les recommandations tactiques

### lib/features/charts/providers/wind_trend_provider.dart
**Objectif** : Flux et agrégation des échantillons de vent récents pour la visualisation des tendances.

**Fonction détaillée** : Ce fichier définit la logique pour agréger et fournir des échantillons de vent récents, permettant d'analyser les tendances et les changements dans les conditions de vent. Cela peut être utilisé pour ajuster la stratégie de navigation et anticiper les changements de cap.

**Extensions possibles** : 
- Ajouter des méthodes pour filtrer les échantillons par période
- Implémenter une logique de détection automatique des tendances
- Ajouter des tests d'intégration pour les scénarios d'analyse de tendance
- Intégrer une visualisation graphique des échantillons de vent

### lib/features/charts/presentation/pages/chart_page.dart
**Objectif** : Liaison de l'UI avec les données du parcours, du vent, et des polaires dans un graphique interactif.

**Fonction détaillée** : Cette page UI est responsable de l'affichage des données de navigation sous forme graphique, permettant à l'utilisateur d'interagir avec les données du parcours, de visualiser les polaires, et d'analyser les tendances du vent. Elle utilise des widgets personnalisés pour le rendu des graphiques et des cartes.

**Extensions possibles** : 
- Ajouter des options de personnalisation des graphiques
- Implémenter des outils d'annotation sur les graphiques
- Ajouter des tests d'intégration pour les scénarios d'interaction graphique
- Intégrer des sources de données externes pour des graphiques en temps réel

### lib/features/charts/presentation/widgets/course_canvas.dart
**Objectif** : Logique de peinture personnalisée / canevas pour la visualisation des routes et du vent.

**Fonction détaillée** : Ce widget personnalisé est utilisé pour dessiner les routes de navigation, les zones de vent, et d'autres éléments graphiques sur un canevas. Il utilise les API de dessin de Flutter pour créer des visualisations précises et esthétiques.

**Extensions possibles** : 
- Ajouter des animations pour les changements de données
- Implémenter des options de zoom et de défilement
- Ajouter des tests unitaires pour la logique de dessin
- Intégrer des modèles 3D pour une visualisation avancée

### lib/features/charts/presentation/widgets/course_menu.dart
**Objectif** : Menu contextuel pour manipuler le parcours / mode de simulation.

**Fonction détaillée** : Ce widget fournit un menu contextuel permettant à l'utilisateur de modifier le parcours, d'ajuster les paramètres de simulation, et d'accéder à d'autres fonctionnalités liées à l'analyse des données de navigation.

**Extensions possibles** : 
- Ajouter des options de partage du parcours
- Implémenter des liens vers des ressources d'aide/contextuelles
- Ajouter des tests d'intégration pour les scénarios d'utilisation du menu
- Intégrer des fonctionnalités de feedback utilisateur

### lib/features/dashboard/providers/selected_metrics.dart
**Objectif** : Persister / exposer l'ensemble des métriques affichées dans le tableau de bord.

**Fonction détaillée** : Ce fichier définit la logique pour gérer les métriques sélectionnées par l'utilisateur pour affichage dans le tableau de bord. Cela inclut la persistance des préférences de l'utilisateur et la fourniture des données de métriques sélectionnées.

**Extensions possibles** : 
- Ajouter des options de personnalisation avancées pour les métriques
- Implémenter une logique de synchronisation des préférences entre appareils
- Ajouter des tests d'intégration pour les scénarios de tableau de bord
- Intégrer des widgets de visualisation avancée pour les métriques

### lib/features/dashboard/presentation/pages/dashboard_page.dart
**Objectif** : Mise en page du tableau de bord affichant les tuiles de métriques.

**Fonction détaillée** : Cette page définit la mise en page principale du tableau de bord, organisant les différentes tuiles de métriques, les graphiques, et autres éléments d'interface utilisateur. Elle utilise des widgets de mise en page Flutter pour organiser les éléments de manière réactive et esthétique.

**Extensions possibles** : 
- Ajouter des options de disposition personnalisée pour l'utilisateur
- Implémenter des widgets de résumé pour les performances clés
- Ajouter des tests d'intégration pour les scénarios de tableau de bord
- Intégrer des fonctionnalités de drill-down pour des analyses détaillées

### lib/features/dashboard/presentation/widgets/metric_tile.dart
**Objectif** : Rendu individuel des métriques, formatage, gestion des unités.

**Fonction détaillée** : Ce widget est responsable du rendu d'une métrique individuelle, y compris le formatage de la valeur, l'affichage de l'unité, et l'application des styles appropriés. Il peut également afficher des indicateurs d'alerte ou des seuils de performance.

**Extensions possibles** : 
- Ajouter un codage couleur basé sur des seuils de performance
- Implémenter des animations pour les changements de valeur
- Ajouter des tests unitaires pour le rendu des métriques
- Intégrer des fonctionnalités d'accessibilité (lecteurs d'écran, contrastes)

### lib/features/dashboard/presentation/widgets/metrics_selector_sheet.dart
**Objectif** : Feuille inférieure pour choisir les métriques visibles.

**Fonction détaillée** : Ce widget affiche une feuille modale permettant à l'utilisateur de sélectionner quelles métriques afficher sur le tableau de bord. Elle présente une liste des métriques disponibles avec des options de filtrage et de recherche.

**Extensions possibles** : 
- Ajouter des options de tri et de filtrage avancées
- Implémenter une logique de sélection/désélection en masse
- Ajouter des tests d'intégration pour les scénarios de sélection de métriques
- Intégrer des fonctionnalités de feedback utilisateur

### lib/features/analysis/providers/analysis_filters.dart
**Objectif** : Filtres (plage temporelle, sous-ensembles de métriques) pour l'analyse.

**Fonction détaillée** : Ce fichier définit les filtres utilisés pour affiner les données affichées dans les fonctionnalités d'analyse. Cela inclut des filtres pour la plage de dates, les types de métriques, et d'autres critères de sélection.

**Extensions possibles** : 
- Ajouter des options de filtrage avancées (par exemple, par plage de valeurs)
- Implémenter une logique de sauvegarde des filtres préférés
- Ajouter des tests d'intégration pour les scénarios d'analyse
- Intégrer des visualisations graphiques pour les données filtrées

### lib/features/analysis/presentation/pages/analysis_page.dart
**Objectif** : UI d'analyse historique (graphiques, panneaux statistiques).

**Fonction détaillée** : Cette page définit l'interface utilisateur pour afficher les données d'analyse historique, y compris des graphiques, des tableaux, et d'autres éléments visuels. Elle permet à l'utilisateur d'explorer les données passées et d'en tirer des insights.

**Extensions possibles** : 
- Ajouter des options d'exportation des données d'analyse (CSV, JSON)
- Implémenter des outils de comparaison côte à côte
- Ajouter des tests d'intégration pour les scénarios d'analyse historique
- Intégrer des fonctionnalités de partage de rapports d'analyse

### lib/features/analysis/presentation/widgets/analysis_filter_drawer.dart
**Objectif** : Tiroir pour configurer les filtres de manière interactive.

**Fonction détaillée** : Ce widget affiche un tiroir latéral permettant à l'utilisateur de configurer les filtres d'analyse de manière interactive. Il présente les différentes options de filtrage disponibles et permet une sélection facile.

**Extensions possibles** : 
- Ajouter des options de filtrage par glisser-déposer
- Implémenter des presets de filtres pour des analyses courantes
- Ajouter des tests d'intégration pour les scénarios de filtrage
- Intégrer des fonctionnalités d'aide contextuelle

### lib/features/alarms/providers/regatta_timer_provider.dart
**Objectif** : Logique de démarrage/séquence du minuteur pour le départ de la course.

**Fonction détaillée** : Ce fichier définit la logique pour gérer le minuteur de départ de la course, y compris le compte à rebours, les alertes sonores, et les vibrations. Il s'assure que le navigateur est averti au bon moment pour prendre des mesures (comme lever l'ancre).

**Extensions possibles** : 
- Ajouter des options de personnalisation du minuteur (son, vibration)
- Implémenter une logique de synchronisation avec des signaux externes
- Ajouter des tests unitaires pour la logique du minuteur
- Intégrer des fonctionnalités de retour d'information utilisateur

### lib/features/alarms/providers/anchor_alarm_provider.dart
**Objectif** : État de surveillance de la dérive de l'ancre.

**Fonction détaillée** : Ce fichier définit la logique pour surveiller la position du bateau par rapport à un point d'ancrage et déclencher des alertes en cas de dérive excessive. Il utilise des données GPS et des seuils configurables pour déterminer l'état d'alarme.

**Extensions possibles** : 
- Ajouter des options de personnalisation des alertes de dérive
- Implémenter une logique de calibration automatique
- Ajouter des tests d'intégration pour les scénarios de surveillance d'ancre
- Intégrer des fonctionnalités de notification à distance

### lib/features/alarms/providers/sleep_timer_provider.dart
**Objectif** : Minuteur de sommeil à cycle court pour veille solo.

**Fonction détaillée** : Ce fichier définit la logique pour un minuteur de sommeil qui permet au navigateur de faire des siestes courtes tout en étant averti en cas de besoin (par exemple, changement de vent, dérive).

**Extensions possibles** : 
- Ajouter des options de personnalisation pour la durée et les alertes
- Implémenter une logique de suivi de sommeil
- Ajouter des tests unitaires pour la logique du minuteur de sommeil
- Intégrer des fonctionnalités de relaxation (sons, méditations)

### lib/features/alarms/presentation/pages/alarms_page.dart
**Objectif** : UI de gestion unifiée des alarmes.

**Fonction détaillée** : Cette page fournit une interface utilisateur pour gérer toutes les alarmes de l'application, y compris les alarmes de dérive, les minuteurs de course, et les minuteurs de sommeil. Elle permet d'activer/désactiver les alarmes, de configurer les seuils, et de tester les alertes.

**Extensions possibles** : 
- Ajouter des options de tri et de filtrage des alarmes
- Implémenter une logique de snooze pour les alarmes
- Ajouter des tests d'intégration pour les scénarios de gestion des alarmes
- Intégrer des fonctionnalités de rapport d'historique des alarmes

### lib/features/settings/presentation/pages/settings_page.dart
**Objectif** : Paramètres globaux de l'application (unités, thèmes, sources).

**Fonction détaillée** : Cette page permet à l'utilisateur de configurer les paramètres globaux de l'application, y compris les préférences d'unités (métriques vs impériales), les thèmes (clair vs sombre), et d'autres options de personnalisation.

**Extensions possibles** : 
- Ajouter des options de synchronisation des paramètres entre appareils
- Implémenter une logique de sauvegarde et restauration des paramètres
- Ajouter des tests d'intégration pour les scénarios de paramètres
- Intégrer des fonctionnalités d'aide contextuelle

---
## Extension Guidelines
1. Add new telemetry metric: emit in bus -> document key -> add provider -> add tile.
2. Swap to real data: implement new TelemetryBus, change provider override at root.
3. Add feature: create domain model -> service -> provider -> UI widget.
4. Performance: batch metric emissions or debounce heavy computations.

---
## Future Ideas
- Replay mode (load telemetry log file)
- NMEA 0183 / SignalK integration bus
- Persistent favorites for metrics across devices
- Export analysis snapshots (CSV / JSON)

---
End of document.
\n---\n
## Architecture Flow (Textual Diagram)

Data Flow (Simulation -> State -> Domain Derivation -> UI):

```
FakeTelemetryBus (timer emits TelemetrySnapshot)
		  |
		  v
telemetryBusProvider (Provider<TelemetryBus>)
		  |
		  +--> snapshotStreamProvider (StreamProvider<TelemetrySnapshot>)
		  |         |
		  |         +--> metricProvider(key) (StreamProvider.family<Measurement>)
		  |
		  +--> windSampleProvider (Provider<WindSample>)
									 |
									 +--> polar / routing / tactics providers
													 |
													 +--> chart_page.dart widgets / course_canvas painter

Dashboard metric tiles  <------ metricProvider & windSampleProvider
Analysis feature        <------ snapshotStreamProvider (historic / filtering)
Tactics feature         <------ windSampleProvider + trend analyzer
```

### Layering Principles
- Data Source Layer: `TelemetryBus` implementations (currently only `FakeTelemetryBus`).
- Provider Composition Layer: Pure Riverpod providers (no UI) in `common/providers` + feature providers.
- Domain Logic Layer: Under `features/*/domain/services` and `domain/entities`.
- Presentation Layer: Widgets & Pages rendering provider state.

### Update Strategy
To add a real data feed (e.g., NMEA via UDP/WebSocket):
1. Implement `TelemetryBus`.
2. Override `telemetryBusProvider` at the app root with the real bus.
3. Keep all downstream providers unchanged (stable contract).

---
## Glossary

- TWD (True Wind Direction): Direction the wind is coming FROM (° true).
- TWS (True Wind Speed): Wind speed over ground, unaffected by boat motion (knots).
- TWA (True Wind Angle): Signed angle between boat heading and true wind (-180..+180). Negative = port tack, positive = starboard (or vice versa depending on convention—document choice if inverted later).
- AWS (Apparent Wind Speed): Wind felt onboard = vector sum of TWS and boat velocity.
- AWA (Apparent Wind Angle): Apparent angle relative to bow (-180..180).
- HDG (Heading): Boat's compass heading (° true here; could support magnetic later).
- COG (Course Over Ground): Actual track direction over earth surface.
- SOG (Speed Over Ground): Velocity over ground (knots).
- VMG (Velocity Made Good): Component of speed toward (or away from) a target (often wind angle or waypoint bearing).
- VMC (Velocity Made good to Course): Component of speed toward a navigational waypoint (course bearing).
- Polar (Table): Performance lookup map (TWS x TWA -> target boat speed).
- Layline: Optimal course line to a mark when tacking/gybing minimal times.
- Depth: Water depth below transducer.
- Trend (Wind): Statistical smoothing / detection of persistent shifts (lift/header).

---
## TODO / Technical Debt / Improvement Backlog

Category | Item | Notes / Direction
---------|------|------------------
Data Bus | Real NMEA integration | Add UDP listener -> parse -> emit Measurement
Data Bus | Replay mode | Load recorded snapshots from file with adjustable speed
Wind Model | Advanced apparent wind calc | Use true wind vector + boat velocity
Wind Model | Gust modeling | Introduce short-lived spikes (Poisson + decay)
Providers | Caching layer | Persist last snapshot for cold start
Providers | Error channel | Add error stream & provider for bus failures
Performance | Batch emission | Coalesce multiple metrics in one frame / microtask
Performance | Selective watch optimization | Fine-grain streams per metric already exists—validate overhead
UI | Theme variants | Light/Dark adaptive nautical palette
UI | Metric formatting | Add unit system toggle (knots <-> m/s; °T vs °M)
Routing | Layline projection | Use polar + current TWD to draw laylines
Routing | Isochrone routing | Add time-front based pathfinder
Testing | Unit tests for calculators | Target: vmc_calculator, routing_calculator
Testing | Golden tests for widgets | chart_page key states
DevEx | Lint rules expansion | Enforce doc headers & naming patterns
DevEx | CI pipeline | Flutter analyze + test + format gating
Resilience | Graceful bus dispose | Confirm no stream leaks on hot reload
Extensibility | Plugin system | Factor telemetry enrichment steps (middleware style)

### Open Questions
- Should wind angle sign convention be explicitly configurable? (Port negative vs positive)
- Do we need magnetic variation handling soon? (Store + apply variation) 
- Persistence layer for analysis: local database vs remote sync?

---
## Modification Guidelines (Detailed)

1. Adding a Metric:
	- Emit in `FakeTelemetryBus._tick()` (or future real bus).
	- Add semantic accessor provider only if composite logic needed.
	- Add to dashboard via selection list if user-visible.

2. Refactoring Telemetry Snapshot Frequency:
	- Adjust timer period; ensure consumers handling rate (debounce if needed).

3. Introducing Real-Time Networking:
	- Use isolate or compute for parsing if CPU heavy.
	- Backpressure: queue last N packets; drop older if lagging.

4. Trend Detection Tuning:
	- Expose config provider: averaging window length, standard deviation threshold.

5. Polars Extension:
	- Support multiple polar sets (e.g., sail configurations) -> add keyed repository & activePolarProvider.

---
## Quick Reference Map (Keys)

Group | Key Prefix | Example | Notes
------|------------|---------|------
Navigation | nav.* | nav.hdg | Heading, course, speed
Wind (true/app) | wind.* | wind.twd | All wind metrics unified
Environment | env.* | env.depth | Depth, temp

---
## Release Checklist
- [ ] All new metrics documented here
- [ ] No orphan providers (search: Provider<  without usage)
- [ ] Hot reload stable (no duplicate timers)
- [ ] TelemetryBus swap tested (simulation vs placeholder real)
- [ ] Trend analyzer thresholds tuned

---
End of extended documentation.
