
#Backup the Current Repository
git clone --mirror https://github.com/data-to-insight/ssd-data-model https://github.com/data-to-insight/ssd-data-model-backup.git



#Clone the Repository Locally
git clone https://github.com/data-to-insight/ssd-data-model
cd ssd-data-model


#Create a Temporary Branch Pointing to the Current HEAD
git checkout --orphan temp_branch

#Add and Commit All Current Files as the new "initial commit" 
git add -A
git commit -am "v1.0 SSD Live"


#delete old history, branches, and tags
git branch -D main  # or master or  default branch name
git tag | xargs git tag -d  # Delete all tags


##renames temp_branch to main (or master or whatever default branch is).
git branch -m main  # or master or  default branch name


# overwrite the remote repository with  new history-free version.
git push -f origin main

#Push the new tags (if any)
git push --tags
