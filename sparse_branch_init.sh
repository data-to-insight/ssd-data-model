#!/bin/bash
# chmod +x sparse_branch.sh
# This not yet set up to iterate over LAs

cd ..

# # Rem
# rm -rf ssd-deployment

# Clone
git clone https://github.com/data-to-insight/ssd-deployment.git

cd ssd-deployment

# create la deployment folders
mkdir -p bradford/cms_ssd_extract_sql/systemc/live/

# cp extracts over
cp -r ../cms_ssd_extract_sql/systemc/live/* bradford/cms_ssd_extract_sql/systemc/live/

# cp key markdown files 
cp ../CHANGELOG.md ../CONTRIBUTORS.md ../README.md bradford/

# to git staging 
git add bradford/cms_ssd_extract_sql/systemc/live/
git add bradford/CHANGELOG.md bradford/CONTRIBUTORS.md bradford/README.md

git commit -m "Manual import of files from ssd-data-model-init test"

git push origin main
