#!/bin/bash
# chmod +x test.sh

# Branch name and directory for this LA
name="east-sussex"

# Base directory where the repository is located
repo_dir="/workspaces/ssd-data-model"
worktree_base_dir="/workspaces/ssd-data-model/la_deployment"

# Change to the repository directory
cd $repo_dir

# Ensure we are on the main branch and in a clean state
git checkout main
git reset --hard HEAD  # Clean up any local changes

echo "Processing $name..."

# Check if the worktree directory already exists and remove the worktree if needed
if [ -d "$worktree_base_dir/$name" ]; then
  echo "Removing worktree at '$worktree_base_dir/$name'..."
  git worktree remove $worktree_base_dir/$name --force
  rm -rf $worktree_base_dir/$name  # Ensure the directory is completely removed
fi

# Check if the branch already exists and delete if needed
if git show-ref --verify --quiet refs/heads/$name-branch; then
  echo "Branch '$name-branch' already exists, deleting it..."
  git branch -D $name-branch
fi

# Create a new branch for the LA
git branch $name-branch

# Create a worktree for the new branch in a separate directory
git worktree add $worktree_base_dir/$name $name-branch

# Move the necessary files directly to the root of the LA directory
cp -r $repo_dir/cms_ssd_extract_sql/systemc/live/* $worktree_base_dir/$name/
cp $repo_dir/CONTRIBUTORS.md $worktree_base_dir/$name/
cp $repo_dir/CHANGELOG.md $worktree_base_dir/$name/

# Clean up any leftover directories in the worktree
rm -rf $worktree_base_dir/$name/cms_ssd_extract_sql

# Change to the LA worktree directory and commit the changes
cd $worktree_base_dir/$name
git add .
git commit -m "Set up $name with bespoke files"

# Push the branch to the remote repository
git push origin $name-branch

# Return to the main repository directory
cd $repo_dir

echo "Worktree and branch for $name processed."
