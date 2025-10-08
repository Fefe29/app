#!/bin/bash

# Script d'installation des dépendances Python pour Kornog
# Usage: ./install_python_deps.sh

set -e  # Arrêt en cas d'erreur

echo "🚀 Installation des dépendances Python pour Kornog"
echo "================================================="

# Vérification que Python est installé
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 n'est pas installé. Veuillez l'installer d'abord."
    exit 1
fi

echo "✅ Python 3 détecté: $(python3 --version)"

# Vérification que pip est installé
if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
    echo "❌ pip n'est pas installé. Installation en cours..."
    sudo apt-get update && sudo apt-get install -y python3-pip
fi

echo "✅ pip détecté: $(python3 -m pip --version)"

# Création d'un environnement virtuel (recommandé)
if [ ! -d "venv_kornog" ]; then
    echo "📦 Création de l'environnement virtuel..."
    python3 -m venv venv_kornog
fi

echo "🔧 Activation de l'environnement virtuel..."
source venv_kornog/bin/activate

# Mise à jour de pip
echo "⬆️  Mise à jour de pip..."
python -m pip install --upgrade pip

# Installation des dépendances
echo "📦 Installation des dépendances depuis requirements.txt..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    echo "✅ Toutes les dépendances ont été installées!"
else
    echo "❌ Fichier requirements.txt introuvable dans le répertoire courant"
    echo "📍 Assurez-vous d'être dans le répertoire racine de Kornog"
    exit 1
fi

echo ""
echo "🎉 Installation terminée!"
echo ""
echo "📋 Pour utiliser l'environnement:"
echo "   source venv_kornog/bin/activate"
echo ""
echo "🧪 Pour tester l'installation:"
echo "   python -c 'import xarray, copernicusmarine; print(\"✅ Imports OK\")'"
echo ""
echo "🚀 Pour exécuter le script de courants:"
echo "   cd Logiciel/Front-End/app/lib/data/datasources/current/"
echo "   python fetch_currents_to_geojson.py"