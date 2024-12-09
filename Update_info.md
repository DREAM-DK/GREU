Periodically, admin should pull updates from the original repository into your fork by using following git bash commands:

git fetch upstream  
git checkout main               # Switch to your main branch (or default branch)  
git merge upstream/main         # Merge changes from the original repository  


If you want these updates in your private branches:  

git checkout private-branch  
git merge main                  # Merge the latest updates into the private branch  
git push origin private-branch  
