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


#### revisions used on ssd-deployment-test

#!/bin/bash
# chmod +x init_all_downstream_branches.sh

# ## Do we already have entry or ssd-data-model repo??
# git remote -v
# git remote add ssd-data-model https://github.com/data-to-insight/ssd-data-model.git # manual add



# LAs to system types
declare -A la_system_map

# Populate with LA:systemtype pairs
la_system_map=(
    ["la1"]="systemc"
    ["la2"]="systemc"
    ["la3"]="mosaic"
    ["la4"]="mosaic"
)

# Ensure the remote for ssd-data-model exists
if ! git remote get-url ssd-data-model > /dev/null 2>&1; then
  echo "Adding remote for ssd-data-model..."
  git remote add ssd-data-model https://github.com/data-to-insight/ssd-data-model.git
fi

# Uncomment these if you need to change the remote URL or access type
# If use SSH instead of HTTPS:
# git remote set-url ssd-data-model git@github.com:data-to-insight/ssd-data-model.git

# If using a GitHub token for HTTPS access, set it here:
# git remote set-url ssd-data-model https://<your-github-username>@github.com/data-to-insight/ssd-data-model.git


# Fetch the latest changes from the source repository (check for errors)
echo "Fetching latest from upstream (ssd-data-model)..."
if ! git fetch ssd-data-model; then
  echo "Error: Failed to fetch from ssd-data-model. Check your permissions."
  exit 1
fi

# Set up sparse checkout
echo "Configuring sparse checkout..."
git config core.sparseCheckout true

# Add systemc and mosaic paths to sparse-checkout
echo "Adding paths to sparse-checkout..."
echo "deployment_extracts/systemc/live/" > .git/info/sparse-checkout
echo "deployment_extracts/mosaic/live/" >> .git/info/sparse-checkout
# Add other systems here if needed
# echo "deployment_extracts/eclipse/live/" >> .git/info/sparse-checkout

# Reapply sparse checkout
echo "Reapplying sparse checkout..."
git sparse-checkout reapply

# Iterate over each LA and system type
for la in "${!la_system_map[@]}"; do
  system=${la_system_map[$la]}
  branch_name="${system}-${la}-branch"

  # Create and switch to the branch if it doesn't already exist
  echo "Processing $la for $system..."
  if ! git rev-parse --verify $branch_name > /dev/null 2>&1; then
    git checkout -b $branch_name
    mkdir -p $system/$la/

    # Move the appropriate files to the LA's directory
    mv deployment_extracts/$system/live/* $system/$la/

    # Stage and commit the changes
    git add $system/$la/
    git commit -m "Initial setup for $system-$la"
    git push origin $branch_name
  else
    echo "Branch $branch_name already exists. Skipping..."
  fi
done

# Return to the main branch
echo "Switching back to the main branch..."
git checkout main

# Optional: Commit any changes made during this process
echo "Committing the init script changes to the main branch..."
git add .
git commit -m "Ensure all changes are committed, including init script."
git push origin main

echo "All processing complete."
