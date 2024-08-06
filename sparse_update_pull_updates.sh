#!/bin/bash
# chmod +x pull_updates.sh

# LAs to update clone (check init file for any changes/ensure consistent list ontents)
names=("east-sussex" "knowsley" "bradford")

# Base dir for clones
base_dir="/workspaces/ssd-data-model/cms_ssd_clone_la_deployment"

# Iterate/process clone each LA in list
for name in "${names[@]}"; do
  echo "Updating $name..."

  # jump to clone dir
  cd $base_dir/$name

  # Stash any local changes (just in case)
  git stash

  # Pull changes from the main repository
  git pull origin main

  # Reapply stashed changes (put them back)
  git stash pop

  # Return to base dir ready for next iter
  cd $base_dir
done

echo "All clones updated."
