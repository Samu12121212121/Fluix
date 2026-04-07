#!/bin/bash
# Script para ejecutar tests de integración con Firebase Emulators

# 1. Iniciar Emuladores en background
echo "Iniciando Firebase Emulators..."
firebase emulators:start --only firestore,auth,functions,storage &
EMULATOR_PID=$!

# Esperar a que inicien (ajustar tiempo si es necesario)
sleep 10

# 2. Ejecutar Tests
echo "Ejecutando tests de integración..."
flutter test test/integration/

# 3. Cerrar Emuladores
echo "Deteniendo emuladores..."
kill $EMULATOR_PID

