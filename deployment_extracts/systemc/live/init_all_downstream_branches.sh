#!/bin/bash
# chmod +x ./systemc/init_all_downstream_branches.sh

# LAs to system types
declare -A la_system_map

# Populate with LA:systemtype pairs
la_system_map=(
    ["la1"]="systemc"
    ["la2"]="systemc"
    ["la3"]="mosaic"
    ["la4"]="mosaic"
)

# Iterate over each la and system type
for la in "${!la_system_map[@]}"; do
  system=${la_system_map[$la]}

  # Create branch for each la and system type if doesn't already exist
  branch_name="${system}-${la}-branch"
  
  if ! git rev-parse --verify $branch_name > /dev/null 2>&1; then
    git checkout -b $branch_name
    mkdir -p $system/$la/
    git add $system/$la/
    git commit -m "Initial setup for $system-$la"
    git push origin $branch_name
  fi
done

# Return to the main branch
git checkout main
