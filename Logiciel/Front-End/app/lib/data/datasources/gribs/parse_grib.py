#!/usr/bin/env python3
"""
Script Python pour parser les fichiers GRIB en utilisant eccodes
Utilisé par GribConverter.dart pour extraire U/V et variables scalaires

Usage:
    python3 parse_grib.py <grib_file> <component> [<field_name>]
    
Exemples:
    python3 parse_grib.py data.grib U          # Extraire UGRD (vent est)
    python3 parse_grib.py data.grib V          # Extraire VGRD (vent nord)
    python3 parse_grib.py data.grib TEMP "TMP" # Extraire température
    python3 parse_grib.py data.grib PRESSURE "PRMSL" # Extraire pression
    
Sortie: CSV format
    record,id,grid,sub_grid,lat,lon,value
    0,0,0,0,-90.0,-180.0,12.5
    ...

Dépendances:
    pip install eccodes cfgrib xarray numpy
"""

import sys
import os

def parse_grib_eccodes(grib_file, component=None, field_name=None):
    """Parse GRIB using eccodes library"""
    try:
        import eccodes
        import numpy as np
    except ImportError:
        print("ERROR: eccodes not installed. Run: pip install eccodes cfgrib xarray numpy", file=sys.stderr)
        return False
    
    if not os.path.exists(grib_file):
        print(f"ERROR: File not found: {grib_file}", file=sys.stderr)
        return False
    
    try:
        with open(grib_file, 'rb') as f:
            msg_id = None
            record_count = 0
            msg_count = 0
            
            # Parcourir tous les messages GRIB
            while True:
                # Utiliser CODES_PRODUCT_GRIB au lieu de CODES_GIF_GRIB2 (compatibilité)
                msg_id = eccodes.codes_grib_new_from_file(f, eccodes.CODES_PRODUCT_GRIB)
                if msg_id is None:
                    break
                
                msg_count += 1
                
                # Chercher le bon message (U, V, ou autre variable)
                if component and component.upper() == 'U':
                    short_name = eccodes.codes_get_string(msg_id, 'shortName')
                    if short_name not in ['u', 'u10m', 'ugrd']:
                        eccodes.codes_release(msg_id)
                        continue
                elif component and component.upper() == 'V':
                    short_name = eccodes.codes_get_string(msg_id, 'shortName')
                    if short_name not in ['v', 'v10m', 'vgrd']:
                        eccodes.codes_release(msg_id)
                        continue
                elif field_name:
                    short_name = eccodes.codes_get_string(msg_id, 'shortName')
                    # Chercher par shortName (ex: 't', 'prmsl')
                    if field_name.lower() not in short_name.lower():
                        eccodes.codes_release(msg_id)
                        continue
                
                # Extraire les données
                try:
                    lats, lons = eccodes.codes_grib_get_data(msg_id, 'latitudes,longitudes')
                    values = eccodes.codes_grib_get_array(msg_id, 'values')
                    
                    if values is None:
                        eccodes.codes_release(msg_id)
                        continue
                    
                    # Convertir en numpy array
                    values = np.array(values, dtype=np.float32)
                    
                    # Parcourir les points
                    grid_size = len(values)
                    for i in range(grid_size):
                        lat = lats[i] if hasattr(lats, '__len__') else lats
                        lon = lons[i] if hasattr(lons, '__len__') else lons
                        val = float(values[i]) if not np.isnan(values[i]) else float('nan')
                        
                        # Output CSV: record,id,grid,sub_grid,lat,lon,value
                        print(f"{record_count},{msg_count},0,0,{lat},{lon},{val}")
                        record_count += 1
                
                except Exception as e:
                    print(f"WARNING: Error extracting data from message {msg_count}: {e}", file=sys.stderr)
                
                eccodes.codes_release(msg_id)
        
        if record_count == 0:
            print(f"ERROR: No data found for component {component}", file=sys.stderr)
            return False
        
        return True
        
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return False


def parse_grib_cfgrib(grib_file, component=None, field_name=None):
    """Parse GRIB using cfgrib (alternative method)"""
    try:
        import xarray as xr
        import numpy as np
    except ImportError:
        print("ERROR: xarray not installed. Run: pip install cfgrib xarray", file=sys.stderr)
        return False
    
    if not os.path.exists(grib_file):
        print(f"ERROR: File not found: {grib_file}", file=sys.stderr)
        return False
    
    try:
        # Lire le fichier GRIB
        ds = xr.open_dataset(grib_file, engine='cfgrib')
        
        # Chercher la variable (u, v, t, prmsl, etc.)
        var_name = None
        if component and component.upper() == 'U':
            var_name = [v for v in ds.data_vars if v.startswith('u')][0] if any(v.startswith('u') for v in ds.data_vars) else None
        elif component and component.upper() == 'V':
            var_name = [v for v in ds.data_vars if v.startswith('v')][0] if any(v.startswith('v') for v in ds.data_vars) else None
        elif field_name:
            var_name = [v for v in ds.data_vars if field_name.lower() in v.lower()][0] if any(field_name.lower() in v.lower() for v in ds.data_vars) else None
        
        if not var_name:
            var_name = list(ds.data_vars)[0]  # Fallback
        
        data = ds[var_name].values
        lats = ds.latitude.values
        lons = ds.longitude.values
        
        # Parcourir et output CSV
        record_count = 0
        for i, lat_row in enumerate(lats):
            for j, lon_row in enumerate(lons):
                try:
                    lat = float(lat_row)
                    lon = float(lon_row)
                    val = float(data[i, j]) if not np.isnan(data[i, j]) else float('nan')
                    
                    print(f"{record_count},1,0,0,{lat},{lon},{val}")
                    record_count += 1
                except:
                    pass
        
        return record_count > 0
        
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return False


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 parse_grib.py <grib_file> <component> [<field_name>]", file=sys.stderr)
        print("  component: U, V, or variable name (e.g., TEMP, PRESSURE)", file=sys.stderr)
        sys.exit(1)
    
    grib_file = sys.argv[1]
    component = sys.argv[2]
    field_name = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Essayer eccodes d'abord, puis cfgrib
    success = parse_grib_eccodes(grib_file, component, field_name)
    if not success:
        print("INFO: Trying cfgrib method...", file=sys.stderr)
        success = parse_grib_cfgrib(grib_file, component, field_name)
    
    sys.exit(0 if success else 1)
