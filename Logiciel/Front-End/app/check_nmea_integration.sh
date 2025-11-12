#!/bin/bash

# Script de vérification - Intégration NMEA 0183
# Usage: bash check_nmea_integration.sh

echo "🔍 Vérification de l'intégration NMEA 0183..."
echo ""

ERRORS=0
WARNINGS=0
SUCCESS=0

APP_DIR="/home/fefe/Informatique/Projets/Kornog/app/Logiciel/Front-End/app"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$APP_DIR/$file" ]; then
        echo -e "${GREEN}✅${NC} $description"
        echo "   → $file"
        ((SUCCESS++))
    else
        echo -e "${RED}❌${NC} $description MANQUANT"
        echo "   → $file"
        ((ERRORS++))
    fi
}

check_dir() {
    local dir="$1"
    local description="$2"
    
    if [ -d "$APP_DIR/$dir" ]; then
        echo -e "${GREEN}✅${NC} $description"
        echo "   → $dir"
        ((SUCCESS++))
    else
        echo -e "${YELLOW}⚠️${NC} Répertoire non créé: $description"
        echo "   → $dir"
        ((WARNINGS++))
    fi
}

check_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if [ -f "$APP_DIR/$file" ]; then
        if grep -q "$pattern" "$APP_DIR/$file"; then
            echo -e "${GREEN}✅${NC} $description"
            ((SUCCESS++))
        else
            echo -e "${RED}❌${NC} $description - pattern NOT FOUND"
            ((ERRORS++))
        fi
    fi
}

# ============================================
echo -e "${BLUE}📦 VÉRIFICATION DES FICHIERS${NC}"
echo "============================================"
echo ""

echo "1️⃣  Fichiers Parser & Bus"
check_file "lib/common/services/nmea_parser.dart" "Parser NMEA 0183"
check_file "lib/data/datasources/telemetry/network_telemetry_bus.dart" "Network Telemetry Bus"
echo ""

echo "2️⃣  Configuration"
check_file "lib/config/telemetry_config.dart" "Configuration Télémétrie"
check_file "lib/common/providers/telemetry_providers.dart" "Providers Télémétrie"
echo ""

echo "3️⃣  Interface Utilisateur"
check_file "lib/features/settings/presentation/screens/network_config_screen.dart" "Écran Configuration Réseau"
check_file "lib/features/settings/presentation/widgets/nmea_status_widget.dart" "Widget Statut NMEA"
echo ""

echo "4️⃣  Exemples & Tests"
check_file "lib/features/telemetry/examples/nmea_examples.dart" "Exemples d'Usage"
check_file "test/nmea_parser_test.dart" "Tests Unitaires"
echo ""

echo "5️⃣  Documentation"
check_file "NMEA_QUICK_START.md" "Guide Rapide"
check_file "NMEA_INTEGRATION_GUIDE.md" "Guide Complet"
check_file "NMEA_ARCHITECTURE.md" "Architecture & Diagrammes"
check_file "IMPLEMENTATION_CHECKLIST.md" "Checklist Installation"
echo ""

# ============================================
echo -e "${BLUE}🔧 VÉRIFICATION DE LA CONFIGURATION${NC}"
echo "============================================"
echo ""

echo "Vérification pubspec.yaml..."
check_content "pubspec.yaml" "udp:" "Dépendance UDP"
check_content "pubspec.yaml" "network_info_plus:" "Dépendance Network Info Plus"
echo ""

echo "Vérification app_providers.dart..."
check_content "lib/common/providers/app_providers.dart" "telemetrySourceModeProvider" "Provider Mode Source"
check_content "lib/common/providers/app_providers.dart" "NetworkTelemetryBus" "Import NetworkTelemetryBus"
echo ""

# ============================================
echo -e "${BLUE}📁 VÉRIFICATION DES RÉPERTOIRES${NC}"
echo "============================================"
echo ""

check_dir "lib/common/services" "Services Directory"
check_dir "lib/data/datasources/telemetry" "Telemetry Datasources"
check_dir "lib/config" "Config Directory"
check_dir "lib/common/providers" "Providers Directory"
check_dir "lib/features/settings/presentation/screens" "Settings Screens"
check_dir "lib/features/settings/presentation/widgets" "Settings Widgets"
check_dir "lib/features/telemetry/examples" "Telemetry Examples"
check_dir "test" "Test Directory"
echo ""

# ============================================
echo -e "${BLUE}🧪 VÉRIFICATIONS COMPLÉMENTAIRES${NC}"
echo "============================================"
echo ""

echo "1. Vérification des imports NMEA..."
if grep -q "import 'package:kornog/common/services/nmea_parser.dart'" "$APP_DIR/lib/data/datasources/telemetry/network_telemetry_bus.dart" 2>/dev/null; then
    echo -e "${GREEN}✅${NC} NetworkTelemetryBus importe NmeaParser"
    ((SUCCESS++))
else
    echo -e "${YELLOW}⚠️${NC} Vérifier import NmeaParser dans NetworkTelemetryBus"
    ((WARNINGS++))
fi
echo ""

echo "2. Vérification TelemetryBus interface..."
if grep -q "abstract class TelemetryBus" "$APP_DIR/lib/data/datasources/telemetry/telemetry_bus.dart" 2>/dev/null; then
    echo -e "${GREEN}✅${NC} Interface TelemetryBus existe"
    ((SUCCESS++))
else
    echo -e "${RED}❌${NC} Interface TelemetryBus non trouvée"
    ((ERRORS++))
fi
echo ""

echo "3. Vérification implémentation NetworkTelemetryBus..."
if grep -q "class NetworkTelemetryBus implements TelemetryBus" "$APP_DIR/lib/data/datasources/telemetry/network_telemetry_bus.dart" 2>/dev/null; then
    echo -e "${GREEN}✅${NC} NetworkTelemetryBus implémente TelemetryBus"
    ((SUCCESS++))
else
    echo -e "${YELLOW}⚠️${NC} Vérifier implémentation NetworkTelemetryBus"
    ((WARNINGS++))
fi
echo ""

# ============================================
echo -e "${BLUE}📊 RÉSUMÉ${NC}"
echo "============================================"
echo ""
echo -e "${GREEN}✅ Fichiers OK:${NC} $SUCCESS"
echo -e "${YELLOW}⚠️  Avertissements:${NC} $WARNINGS"
echo -e "${RED}❌ Erreurs:${NC} $ERRORS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}🎉 TOUT EST PRÊT!${NC}"
    echo ""
    echo "Prochaines étapes:"
    echo "1. flutter pub get"
    echo "2. flutter run"
    echo "3. Aller à: Menu → Paramètres → Connexion Télémétrie"
    echo "4. Configurer IP/port du Miniplexe"
    echo "5. Tester la connexion (badge vert ✅)"
    echo ""
else
    echo -e "${RED}⚠️  ERREURS DÉTECTÉES${NC}"
    echo ""
    echo "Vérifiez:"
    echo "- Les fichiers listés existent et sont au bon endroit"
    echo "- Les imports sont corrects"
    echo "- pubspec.yaml est à jour"
    echo ""
fi

# Afficher le chemin APP
echo -e "${BLUE}Répertoire APP:${NC} $APP_DIR"
echo ""
