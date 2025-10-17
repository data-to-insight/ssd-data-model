#!/bin/bash

# LAs to system types
declare -A la_system_map

# Populate with LA:systemtype pairs
la_system_map=(
    ["la1"]="systemc"
    ["la2"]="systemc"
    ["la3"]="mosaic"
    ["la4"]="mosaic"
)

# Path to upstream repo
upstream_repo="https://github.com/data-to-insight/ssd-data-model.git"

# Fetch latest changes from the upstream repo
git fetch ssd-data-model

# Iterate over each la and system type
for la in "${!la_system_map[@]}"; do
  system=${la_system_map[$la]}
  
  # Checkout branch for each la
  git checkout ${system}-${la}-branch

  # Enable sparse checkout and pull the specific folder from upstream repo
  git config core.sparseCheckout true
  echo "deployment_extracts/${system}/live/" > .git/info/sparse-checkout

  if ! git checkout ssd-data-model/main -- deployment_extracts/${system}/live/; then
    echo "Error: Failed to checkout the ${system} folder for ${la}. Invalid reference or permissions issue."
    exit 1
  fi

  # Merge upstream changes into branch, handle conflicts manually
  git merge --no-commit --no-ff ssd-data-model/main

  # Manually resolve any conflicts !!

  # Commit merge changes
  git commit -m "Merge upstream changes into ${system}-${la}"
  git push origin ${system}-${la}-branch
done

# Return to main branch
git checkout main
