#!/usr/bin/env python3
"""
Script alternatif utilisant xarray avec accès direct zarr (sans authentification)
Contourne les problèmes d'authentification de l'API subset
"""

import json
import math
import sys
import os
from datetime import datetime
from pathlib import Path

# Ajouter le répertoire de configuration au PYTHONPATH
config_dir = Path(__file__).parent.parent.parent.parent / "config"
sys.path.insert(0, str(config_dir))

try:
    import numpy as np
    import xarray as xr
    from currents_config import CurrentsConfigPresets
except ImportError as e:
    print(f"❌ Erreur d'importation: {e}")
    print("📦 Installez les dépendances avec: pip install xarray numpy")
    sys.exit(1)

# Configuration
config = CurrentsConfigPresets.get_current()

print("🌊 Récupération des courants via accès direct zarr")
print(f"📍 Zone: {config.min_longitude}°W à {config.max_longitude}°W, {config.min_latitude}°N à {config.max_latitude}°N")
print(f"⏰ Période: {config.start_time} à {config.end_time}")

# URL zarr directe (pas d'authentification requise pour l'accès lecture)
zarr_url = "https://s3.waw3-1.cloudferro.com/mdl-arco-time-009/arco/GLOBAL_ANALYSISFORECAST_PHY_001_024/cmems_mod_glo_phy-cur_anfc_0.083deg_PT6H-i_202406/timeChunked.zarr"

print(f"🔗 Accès direct zarr: {zarr_url}")

try:
    # Ouverture du dataset zarr
    print("📂 Ouverture du dataset...")
    ds = xr.open_zarr(zarr_url, chunks={})
    
    print("✅ Dataset ouvert!")
    print(f"📊 Variables disponibles: {list(ds.data_vars)}")
    print(f"📏 Dimensions: {dict(ds.dims)}")
    
    # Sélection de la zone géographique et temporelle
    print("🎯 Sélection de la zone et période...")
    
    # Sélection spatiale (on prend les derniers temps disponibles)
    ds_subset = ds.sel(
        longitude=slice(config.min_longitude, config.max_longitude),
        latitude=slice(config.min_latitude, config.max_latitude)
    ).sel(
        elevation=0.49402499198913574,  # Surface 
        method='nearest'
    ).isel(
        time=slice(-6, None)  # Les 6 derniers pas de temps disponibles
    )
    
    # Sous-échantillonnage
    ds_subset = ds_subset.isel(
        longitude=slice(0, None, config.stride_x),
        latitude=slice(0, None, config.stride_y)
    )
    
    print(f"📊 Dimensions après sélection: {dict(ds_subset.dims)}")
    
    # Chargement des données
    print("💾 Chargement des données...")
    u = ds_subset["uo"].load()
    v = ds_subset["vo"].load()
    
    print(f"✅ Données chargées: {u.shape}")
    
    def angle_deg(u_val, v_val):
        """Calcule l'angle de direction du courant"""
        rad = np.arctan2(u_val, v_val)
        deg = (np.degrees(rad) + 360.0) % 360.0
        return deg
    
    # Génération des features GeoJSON
    features = []
    lon_vals = ds_subset.longitude.values
    lat_vals = ds_subset.latitude.values  
    time_vals = ds_subset.time.values
    
    print(f"🔄 Génération des features pour {len(time_vals)} pas de temps...")
    
    for ti, time_val in enumerate(time_vals):
        u_t = u.isel(time=ti).values
        v_t = v.isel(time=ti).values
        
        if np.all(np.isnan(u_t)) or np.all(np.isnan(v_t)):
            continue
            
        speed = np.sqrt(u_t**2 + v_t**2)
        direction = angle_deg(u_t, v_t)
        
        for j, lat in enumerate(lat_vals):
            for i, lon in enumerate(lon_vals):
                ui = float(u_t[j, i]) if not np.isnan(u_t[j, i]) else None
                vi = float(v_t[j, i]) if not np.isnan(v_t[j, i]) else None
                
                if ui is None or vi is None:
                    continue
                    
                spd = float(speed[j, i])
                dir_deg = float(direction[j, i])
                
                # Point avec données
                features.append({
                    "type": "Feature",
                    "geometry": {"type": "Point", "coordinates": [float(lon), float(lat)]},
                    "properties": {
                        "time": str(time_val),
                        "u": ui, "v": vi,
                        "speed_ms": spd,
                        "speed_kn": spd * 1.94384,
                        "dir_deg": dir_deg
                    }
                })
                
                # Flèche directionnelle
                theta = math.radians(dir_deg)
                dx = config.arrow_scale_degrees * math.sin(theta)
                dy = config.arrow_scale_degrees * math.cos(theta)
                
                features.append({
                    "type": "Feature",
                    "geometry": {"type": "LineString", "coordinates": [[float(lon), float(lat)], [float(lon + dx), float(lat + dy)]]},
                    "properties": {
                        "time": str(time_val),
                        "u": ui, "v": vi,
                        "speed_ms": spd,
                        "speed_kn": spd * 1.94384,
                        "dir_deg": dir_deg,
                        "is_arrow": True
                    }
                })
    
    # Sauvegarde du GeoJSON
    fc = {"type": "FeatureCollection", "features": features}
    
    print(f"💾 Écriture du fichier GeoJSON...")
    
    # Créer le répertoire s'il n'existe pas
    output_dir = os.path.dirname(config.output_filename)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)
        print(f"📁 Répertoire créé: {output_dir}")
    
    # Si le fichier spécifique n'existe pas, créer aussi un fichier avec horodatage
    filename_base = os.path.splitext(config.output_filename)[0]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    timestamped_filename = f"{filename_base}_{timestamp}.geojson"
    
    try:
        with open(config.output_filename, "w", encoding="utf-8") as f:
            json.dump(fc, f, indent=2)
        
        # Créer aussi une copie avec horodatage
        with open(timestamped_filename, "w", encoding="utf-8") as f:
            json.dump(fc, f, indent=2)
            
    except FileNotFoundError as e:
        print(f"❌ Erreur: {e}")
        print(f"🔍 Type: {type(e).__name__} si tu ne l'as pas tu le créer avec date et heure de demande de téléchargement pour nom")
        # En cas d'erreur, créer uniquement le fichier avec horodatage
        with open(timestamped_filename, "w", encoding="utf-8") as f:
            json.dump(fc, f, indent=2)
        config.output_filename = timestamped_filename
    
    print(f"✅ Fichier créé: {config.output_filename}")
    print(f"📊 Nombre de features: {len(features)}")
    
    if features:
        points = [f for f in features if f['geometry']['type'] == 'Point']
        if points:
            speeds = [f['properties']['speed_kn'] for f in points]
            print(f"🌊 Vitesse des courants:")
            print(f"   Min: {min(speeds):.2f} kn")
            print(f"   Max: {max(speeds):.2f} kn") 
            print(f"   Moyenne: {sum(speeds)/len(speeds):.2f} kn")
            print(f"⏰ Pas de temps: {len(time_vals)}")
            print(f"📍 Points par pas de temps: {len(points) // len(time_vals)}")

except Exception as e:
    print(f"❌ Erreur: {e}")
    print(f"🔍 Type: {type(e).__name__}")
    sys.exit(1)

print("🎉 Récupération terminée avec succès!")