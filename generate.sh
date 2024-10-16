#!/bin/bash

BASE_DIR="base"
OVERLAYS_BASE="overlays" # Adjust if your base path is different
PACKAGE_FOLDER="package"

echo "Building all overlays"
rm -rf "${PACKAGE_FOLDER}"
mkdir -p "${PACKAGE_FOLDER}"

# Check if overlay directory exists with overlays
if [[ -d "$OVERLAYS_BASE" && -n "$(ls -A "$OVERLAYS_BASE")" ]]; then

    # Find all directories within the overlays base
    for overlay_dir in "$OVERLAYS_BASE"/*/; do
        # Extract the directory name without the trailing slash
        overlay_name="${overlay_dir%/}"
        overlay_name="${overlay_name##*/}"

        if [[ -f "$(pwd)/${OVERLAYS_BASE}/${overlay_name}/kustomization.yaml" ]]; then
            echo "Building overlay: $overlay_name" # Optional for progress updates
            kustomize build ${OVERLAYS_BASE}/$overlay_name > ${PACKAGE_FOLDER}/$overlay_name.yaml
        else
            echo "No '${OVERLAYS_BASE}/${overlay_name}/kustomization.yaml' file found in overlay: $overlay_name. Skipping..."
            continue
        fi
    done

else
    ## No overlays, build a global package from base
    kustomize build "$(pwd)/$BASE_DIR" > ${PACKAGE_FOLDER}/global.yaml
fi
