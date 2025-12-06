#!/bin/bash

SOURCE="FrictionlessMonitor/FrictionlessMonitor/Resources/FrictionlessIcon.jpg"
DEST="FrictionlessMonitor/FrictionlessMonitor/Assets.xcassets/AppIcon.appiconset"

# Ensure source exists
if [ ! -f "$SOURCE" ]; then
    echo "Source image not found at $SOURCE"
    exit 1
fi

# Sizes required: 16, 32, 128, 256, 512
# Scales: 1x, 2x

# Function to resize
generate_icon() {
    SIZE=$1
    SCALE=$2
    FILENAME="icon_${SIZE}x${SIZE}@${SCALE}x.png"
    
    if [ "$SCALE" == "2" ]; then
        TARGET_SIZE=$((SIZE * 2))
    else
        TARGET_SIZE=$SIZE
    fi
    
    sips -z $TARGET_SIZE $TARGET_SIZE "$SOURCE" --out "$DEST/$FILENAME" > /dev/null
    echo "Created $FILENAME"
}

generate_icon 16 1
generate_icon 16 2
generate_icon 32 1
generate_icon 32 2
generate_icon 128 1
generate_icon 128 2
generate_icon 256 1
generate_icon 256 2
generate_icon 512 1
generate_icon 512 2

echo "Icon generation complete."
