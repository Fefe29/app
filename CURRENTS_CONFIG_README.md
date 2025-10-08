# Configuration des Données de Courants - Kornog

## 📋 Vue d'ensemble

Ce système de configuration centralise la récupération des données de courants marins depuis Copernicus Marine, suivant le pattern architectural de `WindTestConfig` pour maintenir la cohérence avec le reste de l'application Kornog.

## 🚀 Installation Rapide

```bash
# 1. Installer les dépendances Python
cd /home/fefe/home/Kornog
./install_python_deps.sh

# 2. Activer l'environnement virtuel
source venv_kornog/bin/activate

# 3. Tester l'installation
python -c "import xarray, copernicusmarine; print('✅ Imports OK')"
```

## 📁 Structure des Fichiers

```
Kornog/
├── requirements.txt                    # Dépendances Python
├── install_python_deps.sh             # Script d'installation automatique
├── venv_kornog/                       # Environnement virtuel (créé automatiquement)
├── data/                               # Données générées
│   └── datasources/
│       └── current/                    # Fichiers GeoJSON des courants
│           └── test_currents.geojson  # Données de test
└── Logiciel/Front-End/app/lib/
    ├── config/
    │   ├── currents_config.py          # Configuration des courants
    │   └── wind_test_config.dart       # Configuration du vent (existant)
    └── data/datasources/current/
        └── fetch_currents.py           # Script de récupération (zarr)
```

## ⚙️ Configuration

### Presets Disponibles

```python
# Zone principale (Bretagne Sud) - Par défaut
config = CurrentsConfigPresets.bretagne_sud()

# Haute résolution pour analyse tactique
config = CurrentsConfigPresets.haute_resolution()

# Vue d'ensemble Atlantique
config = CurrentsConfigPresets.atlantique_large()

# Manche (dataset IBI haute résolution)
config = CurrentsConfigPresets.manche()

# Golfe de Gascogne
config = CurrentsConfigPresets.golfe_gascogne()

# Prévision long terme (72h)
config = CurrentsConfigPresets.prevision_longue()
```

### Personnalisation

```python
# Modifier un preset existant
config = CurrentsConfigPresets.bretagne_sud(
    hours_forecast=48,      # 48h au lieu de 24h par défaut
    stride_x=4,            # Résolution plus fine
    stride_y=4
)

# Configuration complètement personnalisée
config = CurrentsConfigPresets.custom(
    min_lon=-7.0, max_lon=0.0,
    min_lat=46.0, max_lat=50.0,
    hours_forecast=36,
    stride_x=3,
    output_filename="mes_courants.geojson"
)
```

## 🛠️ Utilisation

### 1. Configuration Active

Modifiez la méthode `get_current()` dans `currents_config.py`:

```python
@classmethod
def get_current(cls) -> CurrentsConfig:
    """Configuration actuellement active"""
    return cls.bretagne_sud()  # ← Changez ici pour un autre preset
```

### 2. Exécution

```bash
cd Logiciel/Front-End/app/lib/data/datasources/current/
python fetch_currents.py
```

### 3. Sortie

Le script génère un fichier GeoJSON contenant:
- **Points**: Données de courant (vitesse, direction) à chaque point de grille
- **LineString**: Segments fléchés pour visualisation directe sur carte

## 📊 Paramètres de Configuration

| Paramètre | Description | Valeurs Typiques |
|-----------|-------------|------------------|
| `dataset_id` | Dataset Copernicus Marine | `cmems_mod_glo_phy_anfc_merged-uv_PT1H-i_DYNAMIC_202211` |
| `variables` | Variables à récupérer | `["uo", "vo"]` (courants est/nord) |
| `min/max_longitude/latitude` | Zone géographique | Bretagne Sud: -6.0/-1.0/45.0/49.0 |
| `hours_forecast` | Durée de prévision | 6-72 heures |
| `stride_x/y` | Sous-échantillonnage spatial | 2-10 (plus petit = plus fin) |
| `arrow_scale_degrees` | Taille des flèches | 0.02-0.1 degrés |

## 🎯 Datasets Disponibles

### Global (Résolution Standard)
- **ID**: `cmems_mod_glo_phy_anfc_merged-uv_PT1H-i_DYNAMIC_202211`
- **Résolution**: ~1/12° (~9km)
- **Couverture**: Mondiale
- **Mise à jour**: Quotidienne

### IBI (Atlantique Nord-Est, Haute Résolution)
- **ID**: `cmems_mod_ibi_phy_anfc_0.027deg-2D_PT1H-m_DYNAMIC`
- **Résolution**: 0.027° (~3km)
- **Couverture**: Atlantique Nord-Est, Manche, Golfe de Gascogne
- **Mise à jour**: Quotidienne

## 📈 Cas d'Usage

### Navigation Côtière (Résolution Fine)
```python
config = CurrentsConfigPresets.haute_resolution(
    min_lon=-5.5, max_lon=-2.5,
    min_lat=47.0, max_lat=48.5,
    hours_forecast=12
)
```

### Planification Long Terme
```python
config = CurrentsConfigPresets.prevision_longue(hours_forecast=72)
```

### Analyse Tactique Temps Réel
```python
config = CurrentsConfigPresets.manche(
    hours_forecast=6,
    stride_x=2, stride_y=2  # Maximum de détail
)
```

## 🔧 Dépannage

### Erreur "ModuleNotFoundError"
```bash
# Vérifier l'environnement virtuel
source venv_kornog/bin/activate
pip list | grep xarray
```

### Erreur d'authentification Copernicus

**Méthode 1 - Configuration dans le code (simple):**
Modifiez le fichier `lib/config/currents_config.py` :
```python
class CopernicusCredentials:
    USERNAME = "felicien.moquet@netcourrier.com"
    PASSWORD = "ScEwKb.3~H^*FbQ"
```

**Méthode 2 - Variables d'environnement (sécurisée):**
```bash
export COPERNICUS_USERNAME='felicien.moquet@netcourrier.com'
export COPERNICUS_PASSWORD='ScEwKb.3~H^*FbQ'
```

**Méthode 3 - Login interactif (si les deux autres échouent):**
```bash
copernicusmarine login
```

### Erreur de mémoire sur zones étendues
- Augmenter `stride_x` et `stride_y`
- Réduire `hours_forecast`
- Réduire la zone géographique

## 🚀 Intégration Future

Ce système de configuration est conçu pour s'intégrer facilement avec:

1. **Providers Riverpod**: Création de `current_providers.dart`
2. **Architecture Flutter**: Intégration dans `features/charts/domain/services/`
3. **Cache Local**: Stockage des données pour utilisation hors-ligne
4. **API Backend**: Exposition des données via endpoint REST

## 📝 Exemple Complet

```python
#!/usr/bin/env python3
from currents_config import CurrentsConfigPresets

# Configuration pour course au large Bretagne-Irlande
config = CurrentsConfigPresets.custom(
    min_lon=-10.0, max_lon=-2.0,
    min_lat=47.0, max_lat=52.0,
    hours_forecast=48,
    stride_x=5, stride_y=5,
    output_filename="course_irlande.geojson"
)

# Le script utilisera automatiquement cette configuration
```