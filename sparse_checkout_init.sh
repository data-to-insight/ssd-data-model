#!/bin/bash
# chmod +x setup_sparse_checkout.sh

## Set up clones for each LA's CMS/deployment type
## process logic...
# Create necessary dir
# Clone repo into the current dir
# Clean out existing sparse settings
# Unset cone mode global and local
# Init Sparse Checkout Without Cone Mode
# Config Sparse Checkout (relative paths)
# Reapply Sparse Checkout
# Set permissions (in case needed)



rm -rf /workspaces/ssd-data-model/cms_ssd_clone_la_deployment # only once !! - rm entire clone structure

  # Unset cone mode global + local
git config --global --unset core.sparseCheckoutCone
git config --global --unset core.sparseCheckout
git config --unset core.sparseCheckoutCone
git config --unset core.sparseCheckout

### Liquid Logic / SystcmC LA's

# LAs to clone for
names=("east-sussex" "knowsley" "bradford")

# Iterate/process clone each LA in list
for name in "${names[@]}"; do
  echo "Processing $name..."

  # Create needed dirs
  cd /workspaces/ssd-data-model
  mkdir -p cms_ssd_clone_la_deployment/$name
  cd cms_ssd_clone_la_deployment/$name

  # Clone repo into current dir
  git clone --filter=blob:none --no-checkout https://github.com/data-to-insight/ssd-data-model.git .

  # Clean out existing sparse settings
  rm -f .git/info/sparse-checkout

  # Initialise Sparse Checkout Without Cone Mode
  git sparse-checkout init

  # Configure Sparse Checkout [relative paths]
  echo 'cms_ssd_extract_sql/systemc/live/' > .git/info/sparse-checkout
  echo 'CONTRIBUTORS.md' >> .git/info/sparse-checkout
  echo 'CHANGELOG.md' >> .git/info/sparse-checkout
  # echo '!setup.sh' >> .git/info/sparse-checkout
  # echo '!requirements.txt' >> .git/info/sparse-checkout
  # echo '!pyproject.toml' >> .git/info/sparse-checkout
  # echo '!poetry.lock' >> .git/info/sparse-checkout

  # Reapply Sparse Checkout
  git sparse-checkout reapply

  # Set permissions (in case needed)
  chmod -R 755 .

  # Checkout the main branch
  git checkout main

  # Return to base dir / reset
  cd /workspaces/ssd-data-model
done

echo "All clones processed"






### Mosaic LA's
## MOSAIC LAs START

### CareDirector LA's
## CAREDIR LAs START

### Eclipse LA's
## ECLIPSE LAs START

### Azeus LA's
## AZEUS LAs START




# Copy/paste as needed 

# # Pull changes from main repo for : knowsley
# cd /workspaces/ssd-data-model/cms_ssd_clone_la_deployment/knowsley
# git pull origin main

# # Pull changes from main repo for : east-sussex
# cd /workspaces/ssd-data-model/cms_ssd_clone_la_deployment/east-sussex
# git pull origin main


# # check contents of clone folder(s)
# git ls-tree -r main --name-only | grep cms_ssd_extract_sql/systemc/live

# # check current sparse checkout folders
# cat .git/info/sparse-checkout


# # configure Git to disable push access by removing push URL for the remote(s)
# # For knowsley
# cd /workspaces/ssd-data-model/cms_ssd_clone_la_deployment/knowsley
# git remote set-url --delete origin [https://github.com/data-to-insight/ssd-data-model/tree/main/cms_ssd_clone_la_deployment/knowsley]

# # For east-sussex
# cd /workspaces/ssd-data-model/cms_ssd_clone_la_deployment/east-sussex
# git remote set-url --delete origin [https://github.com/data-to-insight/ssd-data-model/tree/main/cms_ssd_clone_la_deployment/east-sussex]