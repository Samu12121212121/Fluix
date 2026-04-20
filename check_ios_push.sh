#!/bin/bash
# Script de verificación de configuración Push Notifications para iOS
# Ejecutar desde: ./check_ios_push.sh

echo "🍎 Verificando configuración Push Notifications iOS..."
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

# 1. Verificar Runner.entitlements
echo "📄 Verificando Runner.entitlements..."
if grep -q "aps-environment" ios/Runner/Runner.entitlements; then
    env=$(grep -A1 "aps-environment" ios/Runner/Runner.entitlements | grep "string" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ "$env" = "development" ]; then
        echo -e "${GREEN}✅ aps-environment: development${NC}"
    else
        echo -e "${RED}❌ aps-environment debe ser 'development'${NC}"
        ((errors++))
    fi
else
    echo -e "${RED}❌ Falta aps-environment en Runner.entitlements${NC}"
    ((errors++))
fi
echo ""

# 2. Verificar RunnerRelease.entitlements
echo "📄 Verificando RunnerRelease.entitlements..."
if grep -q "aps-environment" ios/Runner/RunnerRelease.entitlements; then
    env=$(grep -A1 "aps-environment" ios/Runner/RunnerRelease.entitlements | grep "string" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ "$env" = "production" ]; then
        echo -e "${GREEN}✅ aps-environment: production${NC}"
    else
        echo -e "${RED}❌ aps-environment debe ser 'production' en Release${NC}"
        ((errors++))
    fi
else
    echo -e "${RED}❌ Falta aps-environment en RunnerRelease.entitlements${NC}"
    ((errors++))
fi
echo ""

# 3. Verificar Info.plist UIBackgroundModes
echo "📄 Verificando Info.plist..."
if grep -q "remote-notification" ios/Runner/Info.plist; then
    echo -e "${GREEN}✅ UIBackgroundModes contiene 'remote-notification'${NC}"
else
    echo -e "${RED}❌ Falta 'remote-notification' en UIBackgroundModes${NC}"
    ((errors++))
fi
echo ""

# 4. Verificar GoogleService-Info.plist
echo "📄 Verificando GoogleService-Info.plist..."
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ GoogleService-Info.plist existe${NC}"

    # Verificar GCM_SENDER_ID
    if grep -q "GCM_SENDER_ID" ios/Runner/GoogleService-Info.plist; then
        sender_id=$(grep -A1 "GCM_SENDER_ID" ios/Runner/GoogleService-Info.plist | grep "string" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        echo -e "${GREEN}   GCM_SENDER_ID: $sender_id${NC}"
    fi

    # Verificar GOOGLE_APP_ID
    if grep -q "GOOGLE_APP_ID" ios/Runner/GoogleService-Info.plist; then
        app_id=$(grep -A1 "GOOGLE_APP_ID" ios/Runner/GoogleService-Info.plist | grep "string" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        echo -e "${GREEN}   GOOGLE_APP_ID: $app_id${NC}"
    fi
else
    echo -e "${RED}❌ GoogleService-Info.plist NO encontrado${NC}"
    ((errors++))
fi
echo ""

# 5. Verificar que no estamos usando simulador
echo "⚠️  RECORDATORIO:"
echo -e "${YELLOW}   Las notificaciones push NO funcionan en simulador iOS${NC}"
echo -e "${YELLOW}   Debes probar en un iPhone/iPad físico${NC}"
echo ""

# 6. Instrucciones para Xcode
echo "🔧 PASOS MANUALES EN XCODE:"
echo "   1. Abre: ios/Runner.xcworkspace"
echo "   2. Selecciona target 'Runner'"
echo "   3. Pestaña 'Signing & Capabilities'"
echo "   4. Verifica que 'Push Notifications' está añadido"
echo "   5. Verifica que 'Background Modes' tiene 'Remote notifications'"
echo ""

# 7. Instrucciones Firebase
echo "🔥 CONFIGURACIÓN EN FIREBASE:"
echo "   1. Ve a: console.firebase.google.com"
echo "   2. Project Settings → Cloud Messaging"
echo "   3. Apple app configuration"
echo "   4. Sube APNs Authentication Key (.p8)"
echo ""

# Resumen
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✅ Verificación completada: Configuración correcta${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "   1. Configura APNs en Firebase Console"
    echo "   2. Abre el proyecto en Xcode y añade capability 'Push Notifications'"
    echo "   3. Ejecuta en dispositivo físico iOS"
    echo "   4. Verifica logs: '📱 Token FCM: ...'"
else
    echo -e "${RED}❌ Se encontraron $errors errores${NC}"
    echo ""
    echo "Lee el archivo CONFIGURACION_IOS_PUSH.md para más detalles"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

