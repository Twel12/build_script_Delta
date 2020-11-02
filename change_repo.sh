#!/bin/bash

set -e

## handle command line arguments
read -p "Do you want to clean .repo? (y/N) " choice

# Initialize local repository
function clean_repo() {
    rm -rf .repo/manifests && echo ".repo/manifests/ --- deleted"
    rm -rf .repo/manifests.git && echo ".repo/manifests.git --- deleted"
    rm -rf .repo/repo && echo ".repo/repo/ --- deleted"
    rm -rf .repo/manifest.xml && echo ".repo/manifest.xml --- deleted"
    rm -rf .repo/project.list && echo ".repo/project.list --- deleted"
    rm -rf .repo/.repo_fetchtimes.json && echo ".repo/.repo_fetchtimes.json --- deleted"
    echo -e "\033[01;33m\n Clean Successed !!! \033[0m"
    echo -e "\033[01;32m\n Now you can sync new repo ... \033[0m"
}

if [[ $choice == *"y"* ]]; then
    clean_repo
fi
