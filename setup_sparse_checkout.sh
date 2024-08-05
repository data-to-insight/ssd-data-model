#!/bin/bash
# chmod +x setup_sparse_checkout.sh

# Clean up any existing deployment directory
rm -rf /workspaces/ssd-data-model/cms_ssd_clone_la_deployment

# Create necessary directories
cd /workspaces/ssd-data-model
mkdir -p cms_ssd_clone_la_deployment/east-sussex
cd cms_ssd_clone_la_deployment/east-sussex

# Clone the repo into the current directory
git clone --filter=blob:none --no-checkout https://github.com/data-to-insight/ssd-data-model.git .

# Clean out any existing sparse settings
rm -f .git/info/sparse-checkout

# Unset cone mode globally and locally
git config --global --unset core.sparseCheckoutCone
git config --global --unset core.sparseCheckout
git config --unset core.sparseCheckoutCone
git config --unset core.sparseCheckout

# Initialize Sparse Checkout Without Cone Mode
git sparse-checkout init


# Configure Sparse Checkout with explicit patterns
echo '/cms_ssd_extract_sql/systemc/live/' > .git/info/sparse-checkout

# Reapply Sparse Checkout
git sparse-checkout reapply

# Set permissions (in case needed)
chmod -R 755 .

# Checkout the main branch
git checkout main


# Configure Sparse Checkout with explicit patterns
# echo '/cms_ssd_extract_sql/systemc/live' > .git/info/sparse-checkout
# echo '!/rebaseline_repo.sh' >> .git/info/sparse-checkout
# echo '!/setup.sh' >> .git/info/sparse-checkout
# echo '!/requirements.txt' >> .git/info/sparse-checkout
# echo '!/pyproject.toml' >> .git/info/sparse-checkout
# echo '!/poetry.lock' >> .git/info/sparse-checkout
