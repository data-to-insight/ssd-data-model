#!/bin/bash
# chmod +x pull_updates.sh

cd /workspaces/ssd-data-model/
git add .
git commit -m "clear changes"
git push origin main


# Define the list of names
names=("east-sussex" "knowsley" "bradford")

# Base directory for the clones
base_dir="/workspaces/ssd-data-model/cms_ssd_clone_la_deployment"

# Iterate over each name in the list
for name in "${names[@]}"; do
  echo "Updating $name..."

  # Navigate to the clone directory
  cd $base_dir/$name

  # Print current status
  echo "Current status of $name:"
  git status

  # Add and commit any local changes
  if [[ -n $(git status -s) ]]; then
    git add .
    git commit -m "Auto-commit before pulling updates from main"
  fi

 # Reset local changes to ensure clean pull
  git reset --hard

  # Pull changes from the main repository
  echo "Pulling changes from main for $name..."
  git pull origin main

  # Reinitialize Sparse Checkout
  echo "Reinitializing sparse checkout for $name..."
  git sparse-checkout init --cone
  echo 'cms_ssd_extract_sql/systemc/live/' > .git/info/sparse-checkout
  echo 'CONTRIBUTORS.md' >> .git/info/sparse-checkout
  echo 'CHANGELOG.md' >> .git/info/sparse-checkout
  git sparse-checkout reapply

  # Print new status
  echo "New status of $name:"
  git status
  echo "Contents of sparse-checkout file:"
  cat .git/info/sparse-checkout
  echo "Listing contents of cms_ssd_extract_sql/systemc/live/"
  ls cms_ssd_extract_sql/systemc/live/

  # Return to the base directory before next iteration
  cd $base_dir
done

echo "All clones have been updated."
