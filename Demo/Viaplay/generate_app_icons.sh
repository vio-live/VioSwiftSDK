#!/bin/bash

# Script para generar todos los iconos de aplicación desde una imagen fuente de 1024x1024
# Uso: ./generate_app_icons.sh <imagen_fuente.png>
# La imagen fuente debe ser de al menos 1024x1024 píxeles

if [ $# -eq 0 ]; then
    echo "❌ Error: Debes proporcionar una imagen fuente"
    echo "Uso: ./generate_app_icons.sh <imagen_fuente.png>"
    exit 1
fi

SOURCE_IMAGE="$1"
ICONSET_DIR="Viaplay/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: No se encontró la imagen: $SOURCE_IMAGE"
    exit 1
fi

if ! command -v sips &> /dev/null; then
    echo "❌ Error: 'sips' no está disponible (debería estar incluido en macOS)"
    exit 1
fi

echo "📱 Generando iconos de aplicación para Viaplay..."
echo "   Imagen fuente: $SOURCE_IMAGE"
echo "   Directorio destino: $ICONSET_DIR"
echo ""

mkdir -p "$ICONSET_DIR"

generate_icon() {
    local size=$1
    local filename=$2
    echo "   Generando $filename ($size x $size)..."
    sips -z $size $size "$SOURCE_IMAGE" --out "$ICONSET_DIR/$filename" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ $filename creado"
    else
        echo "   ❌ Error al crear $filename"
    fi
}

echo "📱 Generando iconos para iPhone..."
generate_icon 40 "AppIcon-20x20@2x.png"
generate_icon 60 "AppIcon-20x20@3x.png"
generate_icon 58 "AppIcon-29x29@2x.png"
generate_icon 87 "AppIcon-29x29@3x.png"
generate_icon 80 "AppIcon-40x40@2x.png"
generate_icon 120 "AppIcon-40x40@3x.png"
generate_icon 120 "AppIcon-60x60@2x.png"
generate_icon 180 "AppIcon-60x60@3x.png"

echo ""
echo "📱 Generando iconos para iPad..."
generate_icon 20 "AppIcon-20x20@1x.png"
generate_icon 29 "AppIcon-29x29@1x.png"
generate_icon 40 "AppIcon-40x40@1x.png"
generate_icon 76 "AppIcon-76x76@1x.png"
generate_icon 152 "AppIcon-76x76@2x.png"
generate_icon 167 "AppIcon-83.5x83.5@2x.png"

echo ""
echo "📱 Generando icono para App Store..."
generate_icon 1024 "AppIcon-1024x1024.png"

echo ""
echo "✅ ¡Todos los iconos generados exitosamente!"
echo ""
echo "📋 Iconos generados:"
ls -lh "$ICONSET_DIR"/*.png 2>/dev/null | awk '{print "   - " $9 " (" $5 ")"}'
echo ""
echo "🎨 Siguiente paso:"
echo "   1. Abre Xcode y selecciona el proyecto Viaplay"
echo "   2. Ve a 'Viaplay' target → General"
echo "   3. Verifica que los iconos aparezcan en App Icons"
echo ""
echo "⚠️  IMPORTANTE para TestFlight:"
echo "   - El icono debe ser PNG sin transparencia"
echo "   - iOS aplicará las esquinas redondeadas automáticamente"
echo "   - Todos los tamaños requeridos están incluidos"

