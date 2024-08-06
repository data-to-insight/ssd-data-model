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


### Liquid Logic / SystcmC LA's

rm -rf /workspaces/ssd-data-model/cms_ssd_clone_la_deployment # only once !! - rm entire clone structure



cd /workspaces/ssd-data-model
mkdir -p cms_ssd_clone_la_deployment/east-sussex
cd cms_ssd_clone_la_deployment/east-sussex

git clone --filter=blob:none --no-checkout https://github.com/data-to-insight/ssd-data-model.git .

rm -f .git/info/sparse-checkout

git config --global --unset core.sparseCheckoutCone
git config --global --unset core.sparseCheckout
git config --unset core.sparseCheckoutCone
git config --unset core.sparseCheckout

git sparse-checkout init

echo 'cms_ssd_extract_sql/systemc/live/' > .git/info/sparse-checkout
git sparse-checkout reapply

chmod -R 755 .

git checkout main




cd /workspaces/ssd-data-model
mkdir -p cms_ssd_clone_la_deployment/knowsley
cd cms_ssd_clone_la_deployment/knowsley

git clone --filter=blob:none --no-checkout https://github.com/data-to-insight/ssd-data-model.git .

rm -f .git/info/sparse-checkout 

git config --global --unset core.sparseCheckoutCone
git config --global --unset core.sparseCheckout
git config --unset core.sparseCheckoutCone
git config --unset core.sparseCheckout


git sparse-checkout init


echo 'cms_ssd_extract_sql/systemc/live/' > .git/info/sparse-checkout
git sparse-checkout reapply 

chmod -R 755 . 

git checkout main


### Mosaic LA's

### CareDirector LA's

### Eclipse LA's

### Azeus LA's




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