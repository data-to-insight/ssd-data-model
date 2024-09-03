#!/bin/bash

# Declare an associative array to map organizations to system types
declare -A org_system_map

# Populate the array with org:systemtype pairs
org_system_map=(
    ["org1"]="systemc"
    ["org2"]="systemc"
    ["org3"]="mosaic"
    ["org4"]="mosaic"
)

# Iterate over each organization and system type
for org in "${!org_system_map[@]}"; do
  system=${org_system_map[$org]}

  # Create a branch for each organization and system type if it doesn't already exist
  branch_name="${system}-${org}-branch"
  
  if ! git rev-parse --verify $branch_name > /dev/null 2>&1; then
    git checkout -b $branch_name
    mkdir -p $system/$org/
    git add $system/$org/
    git commit -m "Initial setup for $system-$org"
    git push origin $branch_name
  fi
done

# Return to the main branch
git checkout main
