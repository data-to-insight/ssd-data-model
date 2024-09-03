#!/bin/bash
# chmod +x test.sh

# This bash file to be run from the downstream repo!

# Paths in the upstream repo:
# /workspaces/ssd-data-model/deployment_extracts/systemc/live/
# /workspaces/ssd-data-model/deployment_extracts/mosaic/live/
# /workspaces/ssd-data-model/deployment_extracts/eclipse/live/
# /workspaces/ssd-data-model/deployment_extracts/caredirector/live/
# /workspaces/ssd-data-model/deployment_extracts/azeus/live/

# Check if already in the ssd-deployment directory
if [ ! -d ".git" ]; then
  echo "Error: Not a git repository. Make sure you are in the 'ssd-deployment' directory."
  exit 1
fi

# Ensure the remote for ssd-data-model exists
if ! git remote get-url ssd-data-model > /dev/null 2>&1; then
  git remote add ssd-data-model https://github.com/data-to-insight/ssd-data-model.git
fi

# Fetch the latest changes from the source repository (check for errors)
if ! git fetch ssd-data-model; then
  echo "Error: Failed to fetch from ssd-data-model. Check your permissions."
  exit 1
fi

# Enable sparse checkout and pull the specific folders from the source repository
git config core.sparseCheckout true

# Add paths to sparse-checkout
echo "deployment_extracts/systemc/live/" > .git/info/sparse-checkout
echo "deployment_extracts/mosaic/live/" >> .git/info/sparse-checkout
echo "deployment_extracts/eclipse/live/" >> .git/info/sparse-checkout
echo "deployment_extracts/caredirector/live/" >> .git/info/sparse-checkout
echo "deployment_extracts/azeus/live/" >> .git/info/sparse-checkout

# Checkout the systemc directory
if ! git checkout ssd-data-model/main -- deployment_extracts/systemc/live/; then
  echo "Error: Failed to checkout the systemc folder. Invalid reference or permissions issue."
  exit 1
fi

# Checkout the mosaic directory
if ! git checkout ssd-data-model/main -- deployment_extracts/mosaic/live/; then
  echo "Error: Failed to checkout the mosaic folder. Invalid reference or permissions issue."
  exit 1
fi

# Checkout the eclipse directory
if ! git checkout ssd-data-model/main -- deployment_extracts/eclipse/live/; then
  echo "Error: Failed to checkout the eclipse folder. Invalid reference or permissions issue."
  exit 1
fi

# Checkout the caredirector directory
if ! git checkout ssd-data-model/main -- deployment_extracts/caredirector/live/; then
  echo "Error: Failed to checkout the caredirector folder. Invalid reference or permissions issue."
  exit 1
fi

# Checkout the azeus directory
if ! git checkout ssd-data-model/main -- deployment_extracts/azeus/live/; then
  echo "Error: Failed to checkout the azeus folder. Invalid reference or permissions issue."
  exit 1
fi

# Create the directories in the downstream repository
mkdir -p systemc/
mkdir -p mosaic/
mkdir -p eclipse/
mkdir -p caredirector/
mkdir -p azeus/

# Move the systemc folder's contents to the systemc directory
mv deployment_extracts/systemc/live/* systemc/

# Move the mosaic folder's contents to the mosaic directory
mv deployment_extracts/mosaic/live/* mosaic/

# Move the eclipse folder's contents to the eclipse directory
mv deployment_extracts/eclipse/live/* eclipse/

# Move the caredirector folder's contents to the caredirector directory
mv deployment_extracts/caredirector/live/* caredirector/

# Move the azeus folder's contents to the azeus directory
mv deployment_extracts/azeus/live/* azeus/

# Remove the empty directory structures after the move
rm -rf deployment_extracts/

# Stage, commit, and push the changes to the downstream repository
git add .
git commit -m "Add live SQL files from multiple folders in the ssd-data-model repository"
git push origin main
