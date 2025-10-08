"""
Configuration centralisée pour la récupération des données de courants Copernicus Marine
Similaire au système de configuration de WindTestConfig pour maintenir la cohérence architecturale
"""

import os
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Dict, List, Optional


@dataclass(frozen=True)
class CurrentsConfig:
    """Configuration pour la récupération des tables de courants"""
    
    # Identifiant du dataset Copernicus Marine
    dataset_id: str
    
    # Variables à récupérer
    variables: List[str]
    
    # Zone géographique (bounding box)
    min_longitude: float
    max_longitude: float
    min_latitude: float
    max_latitude: float
    
    # Fenêtre temporelle
    start_time: str
    end_time: str
    
    # Échantillonnage spatial
    stride_x: int
    stride_y: int
    
    # Paramètres de visualisation
    arrow_scale_degrees: float
    
    # Profondeur (surface par défaut)
    depth_min: float
    depth_max: float
    
    # Fichier de sortie
    output_filename: str
    
    # Identifiants Copernicus Marine
    username: Optional[str] = None
    password: Optional[str] = None


class CopernicusCredentials:
    """Identifiants Copernicus Marine - Modifiez ici vos identifiants"""
    
    # 🔐 IDENTIFIANTS COPERNICUS MARINE
    # Remplacez par vos vrais identifiants ou utilisez des variables d'environnement
    USERNAME = "felicien.moquet@netcourrier.com"
    PASSWORD = "Kornog_20250"  # ✅ Mot de passe sans caractères spéciaux
    
    # Alternative sécurisée avec variables d'environnement (recommandée)
    # USERNAME = os.getenv('COPERNICUS_USERNAME', 'felicien.moquet@netcourrier.com')
    # PASSWORD = os.getenv('COPERNICUS_PASSWORD', '')
    
    @classmethod
    def get_credentials(cls) -> tuple[str, str]:
        """Récupère les identifiants avec fallback sur les variables d'environnement"""
        import os
        username = os.getenv('COPERNICUS_USERNAME', cls.USERNAME)
        password = os.getenv('COPERNICUS_PASSWORD', cls.PASSWORD)
        
        if not username or not password or password == "VOTRE_MOT_DE_PASSE_ICI":
            raise ValueError(
                "❌ Identifiants Copernicus Marine non configurés!\n"
                "💡 Solutions:\n"
                "1. Modifiez CopernicusCredentials.USERNAME et .PASSWORD dans currents_config.py\n"
                "2. Ou définissez les variables d'environnement:\n"
                "   export COPERNICUS_USERNAME='votre_email@example.com'\n"
                "   export COPERNICUS_PASSWORD='votre_mot_de_passe'"
            )
        
        return username, password


class CurrentsConfigPresets:
    """Presets de configuration pour différentes zones et scénarios"""
    
    # =========================================================================
    # 🎯 CONFIGURATION ACTIVE (modifiez cette ligne pour changer de preset)
    # =========================================================================
    
    @classmethod
    def get_current(cls) -> CurrentsConfig:
        """Configuration actuellement active"""
        return cls.test_simple()
    
    @classmethod
    def test_simple(
        cls,
        hours_forecast: int = 6,
        stride_x: int = 10,
        stride_y: int = 10
    ) -> CurrentsConfig:
        """Configuration de test simple avec dataset global et zone réduite"""
        now = datetime.utcnow()
        return CurrentsConfig(
            dataset_id="cmems_mod_glo_phy-cur_anfc_0.083deg_PT6H-i",  # Dataset simplifié
            variables=["uo", "vo"],
            min_longitude=-5.0,      # Zone plus petite
            max_longitude=-2.0,
            min_latitude=46.0,
            max_latitude=48.0,
            start_time=now.strftime("%Y-%m-%dT%H:00:00Z"),
            end_time=(now + timedelta(hours=hours_forecast)).strftime("%Y-%m-%dT%H:00:00Z"),
            stride_x=stride_x,
            stride_y=stride_y,
            arrow_scale_degrees=0.1,
            depth_min=0.0,
            depth_max=1.0,
            output_filename="Logiciel/Front-End/app/lib/app/data/datasources/current/test_currents.geojson"
        )
    
    # =========================================================================
    # 📋 PRESETS GÉOGRAPHIQUES
    # =========================================================================
    
    @staticmethod
    def bretagne_sud():
        return CurrentsConfig(
            # Zone Bretagne Sud (Golfe du Morbihan, Belle-Île)
            lon_min=-3.5, lon_max=-2.0,
            lat_min=47.0, lat_max=47.8,
            output_file="Logiciel/Front-End/app/lib/app/data/datasources/current/bretagne_sud_currents.geojson"
        )
    
    @staticmethod
    def manche():
        return CurrentsConfig(
            # Manche occidentale (Brest à Cherbourg)
            lon_min=-5.0, lon_max=-1.0,
            lat_min=48.0, lat_max=50.0,
            output_file="Logiciel/Front-End/app/lib/app/data/datasources/current/manche_currents.geojson"
        )
    
    @classmethod
    def atlantique_large(
        cls,
        hours_forecast: int = 48,
        stride_x: int = 10,
        stride_y: int = 10,
        arrow_scale: float = 0.1
    ) -> CurrentsConfig:
        """Configuration pour l'Atlantique Nord (vue d'ensemble)"""
        now = datetime.utcnow()
        return CurrentsConfig(
            dataset_id="cmems_mod_glo_phy_anfc_merged-uv_PT1H-i_DYNAMIC_202211",
            variables=["uo", "vo"],
            min_longitude=-20.0,
            max_longitude=5.0,
            min_latitude=40.0,
            max_latitude=55.0,
            start_time=now.strftime("%Y-%m-%dT%H:00:00Z"),
            end_time=(now + timedelta(hours=hours_forecast)).strftime("%Y-%m-%dT%H:00:00Z"),
            stride_x=stride_x,
            stride_y=stride_y,
            arrow_scale_degrees=arrow_scale,
            depth_min=0.0,
            depth_max=1.0,
            output_filename="Logiciel/Front-End/app/lib/app/data/datasources/current/atlantique.geojson"
        )
    
    @classmethod
    def golfe_gascogne(
        cls,
        hours_forecast: int = 24,
        stride_x: int = 5,
        stride_y: int = 5,
        arrow_scale: float = 0.06
    ) -> CurrentsConfig:
        """Configuration pour le Golfe de Gascogne"""
        now = datetime.utcnow()
        return CurrentsConfig(
            dataset_id="cmems_mod_ibi_phy_anfc_0.027deg-2D_PT1H-m_DYNAMIC",
            variables=["uo", "vo"],
            min_longitude=-8.0,
            max_longitude=-1.0,
            min_latitude=43.0,
            max_latitude=48.0,
            start_time=now.strftime("%Y-%m-%dT%H:00:00Z"),
            end_time=(now + timedelta(hours=hours_forecast)).strftime("%Y-%m-%dT%H:00:00Z"),
            stride_x=stride_x,
            stride_y=stride_y,
            arrow_scale_degrees=arrow_scale,
            depth_min=0.0,
            depth_max=1.0,
            output_filename="Logiciel/Front-End/app/lib/app/data/datasources/current/gascogne.geojson"
        )
    
    # =========================================================================
    # 🏆 PRESETS TACTIQUES
    # =========================================================================
    
    @classmethod
    def haute_resolution(
        cls,
        min_lon: float = -6.0,
        max_lon: float = -1.0,
        min_lat: float = 45.0,
        max_lat: float = 49.0,
        hours_forecast: int = 6
    ) -> CurrentsConfig:
        """Configuration haute résolution pour analyse tactique détaillée"""
        now = datetime.utcnow()
        return CurrentsConfig(
            dataset_id="cmems_mod_ibi_phy_anfc_0.027deg-2D_PT1H-m_DYNAMIC",
            variables=["uo", "vo"],
            min_longitude=min_lon,
            max_longitude=max_lon,
            min_latitude=min_lat,
            max_latitude=max_lat,
            start_time=now.strftime("%Y-%m-%dT%H:00:00Z"),
            end_time=(now + timedelta(hours=hours_forecast)).strftime("%Y-%m-%dT%H:00:00Z"),
            stride_x=2,  # Très haute résolution
            stride_y=2,
            arrow_scale_degrees=0.02,
            depth_min=0.0,
            depth_max=1.0,
            output_filename="Logiciel/Front-End/app/lib/app/data/datasources/current/haute_resolution.geojson"
        )
    
    @classmethod
    def prevision_longue(
        cls,
        hours_forecast: int = 72
    ) -> CurrentsConfig:
        """Configuration pour prévision à long terme (3 jours)"""
        now = datetime.utcnow()
        return CurrentsConfig(
            dataset_id="cmems_mod_glo_phy_anfc_merged-uv_PT1H-i_DYNAMIC_202211",
            variables=["uo", "vo"],
            min_longitude=-6.0,
            max_longitude=-1.0,
            min_latitude=45.0,
            max_latitude=49.0,
            start_time=now.strftime("%Y-%m-%dT%H:00:00Z"),
            end_time=(now + timedelta(hours=hours_forecast)).strftime("%Y-%m-%dT%H:00:00Z"),
            stride_x=8,  # Résolution plus faible pour couvrir plus de temps
            stride_y=8,
            arrow_scale_degrees=0.07,
            depth_min=0.0,
            depth_max=1.0,
            output_filename="Logiciel/Front-End/app/lib/app/data/datasources/current/prevision_longue.geojson"
        )
    
    # =========================================================================
    # 🛠️ MÉTHODES UTILITAIRES
    # =========================================================================
    
    @classmethod
    def custom(
        cls,
        min_lon: float,
        max_lon: float,
        min_lat: float,
        max_lat: float,
        hours_forecast: int = 24,
        **kwargs
    ) -> CurrentsConfig:
        """Créer une configuration personnalisée avec zone géographique spécifique"""
        now = datetime.utcnow()
        defaults = {
            "dataset_id": "cmems_mod_glo_phy_anfc_merged-uv_PT1H-i_DYNAMIC_202211",
            "variables": ["uo", "vo"],
            "start_time": now.strftime("%Y-%m-%dT%H:00:00Z"),
            "end_time": (now + timedelta(hours=hours_forecast)).strftime("%Y-%m-%dT%H:00:00Z"),
            "stride_x": 6,
            "stride_y": 6,
            "arrow_scale_degrees": 0.05,
            "depth_min": 0.0,
            "depth_max": 1.0,
            "output_filename": "Logiciel/Front-End/app/lib/app/data/datasources/current/custom.geojson"
        }
        defaults.update(kwargs)
        
        return CurrentsConfig(
            min_longitude=min_lon,
            max_longitude=max_lon,
            min_latitude=min_lat,
            max_latitude=max_lat,
            **defaults
        )


# =========================================================================
# 📖 EXEMPLES D'UTILISATION
# =========================================================================
"""
# 🎯 UTILISATION SIMPLE - Preset par défaut
config = CurrentsConfigPresets.get_current()

# 🛠️ PERSONNALISATION - Zone spécifique
config = CurrentsConfigPresets.bretagne_sud(hours_forecast=48, stride_x=4)

# ⚡ HAUTE RÉSOLUTION - Analyse tactique
config = CurrentsConfigPresets.haute_resolution(
    min_lon=-5.0, max_lon=-2.0,
    min_lat=47.0, max_lat=48.5,
    hours_forecast=12
)

# 🏗️ CONFIGURATION COMPLÈTEMENT PERSONNALISÉE
config = CurrentsConfigPresets.custom(
    min_lon=-7.0, max_lon=0.0,
    min_lat=46.0, max_lat=50.0,
    hours_forecast=36,
    stride_x=3,
    stride_y=3,
    output_filename="currents_ma_zone.geojson"
)
"""