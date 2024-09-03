#!/bin/bash
# chmod +x systemc/refresh_all_downstream_extracts.sh
# This bash file to be run from the downstream repo!

# Script pulls from master ssd-data-model/ repo
# ssd-data-model/deployment_extracts/systemc/live/
# ssd-data-model/deployment_extracts/mosaic/live/
# ssd-data-model/deployment_extracts/eclipse/live/
# ssd-data-model/deployment_extracts/caredirector/live/
# ssd-data-model/deployment_extracts/azeus/live/

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

# Add systemc, mosaic, eclipse, caredirector, and azeus paths to sparse-checkout
echo "deployment_extracts/systemc/live/" > .git/info/sparse-checkout
echo "deployment_extracts/mosaic/live/" >> .git/info/sparse-checkout
echo "deployment_extracts/eclipse/live/" >> .git/info/sparse-checkout
echo "deployment_extracts/caredirector/live/" >> .git/info/sparse-checkout
echo "deployment_extracts/azeus/live/" >> .git/info/sparse-checkout

# Checkout the necessary directories
if ! git checkout ssd-data-model/main -- deployment_extracts/systemc/live/ deployment_extracts/mosaic/live/ deployment_extracts/eclipse/live/ deployment_extracts/caredirector/live/ deployment_extracts/azeus/live/; then
  echo "Error: Failed to checkout the folders. Invalid reference or permissions issue."
  exit 1
fi

# Create the directories in the downstream repository
mkdir -p systemc/
mkdir -p mosaic/
mkdir -p eclipse/
mkdir -p caredirector/
mkdir -p azeus/

# Move the contents to the appropriate directories
mv deployment_extracts/systemc/live/* systemc/
mv deployment_extracts/mosaic/live/* mosaic/
mv deployment_extracts/eclipse/live/* eclipse/
mv deployment_extracts/caredirector/live/* caredirector/
mv deployment_extracts/azeus/live/* azeus/

# Remove the empty directory structures after the move
rm -rf deployment_extracts/

# Ensure all paths are added by modifying sparse-checkout or using the --sparse option
git add --sparse .

# Stage, commit, and push the changes to the downstream repository
git commit -m "Add live SQL files from systemc, mosaic, eclipse, caredirector, and azeus from ssd-data-model repository"
git push origin main
