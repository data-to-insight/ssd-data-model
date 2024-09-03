#!/bin/bash

# Declare an associative array
declare -A org_system_map

# Populate the array with org:systemtype pairs
org_system_map=(
    ["org1"]="systemc"
    ["org2"]="systemc"
    ["org3"]="mosaic"
    ["org4"]="mosaic"
)

# Path to the upstream repo
upstream_repo="https://github.com/data-to-insight/ssd-data-model.git"

# Fetch the latest changes from the upstream repository
git fetch ssd-data-model

# Iterate over each organization and system type
for org in "${!org_system_map[@]}"; do
  system=${org_system_map[$org]}
  
  # Checkout the branch for each organization
  git checkout ${system}-${org}-branch

  # Enable sparse checkout and pull the specific folder from the upstream repository
  git config core.sparseCheckout true
  echo "deployment_extracts/${system}/live/" > .git/info/sparse-checkout

  if ! git checkout ssd-data-model/main -- deployment_extracts/${system}/live/; then
    echo "Error: Failed to checkout the ${system} folder for ${org}. Invalid reference or permissions issue."
    exit 1
  fi

  # Merge upstream changes into the branch, handling conflicts manually
  git merge --no-commit --no-ff ssd-data-model/main

  # Manually resolve any conflicts here if necessary

  # Commit the merge changes
  git commit -m "Merge upstream changes into ${system}-${org}"
  git push origin ${system}-${org}-branch
done

# Return to the main branch
git checkout main
