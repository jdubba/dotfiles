#!/usr/bin/env bash
set -euo pipefail

# NOTE: Only run inside a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Not in a Git repository."
    exit
fi

# 1. Prompt for user info
read -p "Full Name: " FULL_NAME
export GIT_USERNAME="$FULL_NAME"
read -p "Email: " EMAIL
export GIT_EMAIL="$EMAIL"

# 2. Check for existing GPG key for the email, and generate if it does not exist
KEY_FPR=$(gpg --list-secret-keys --with-colons "$EMAIL" \
           | awk -F: '/^sec/ {print $5; exit}')

if [[ -z "$KEY_FPR" ]]; then
    echo "No GPG signing key found for the given email.  Run register-github-gpgkey to generate a key."
    exit
fi


export GIT_SIGNING_KEY="$KEY_FPR"

# 7. Create a git configuration file with signing rsettings
git config --local user.name "$GIT_USERNAME"
git config --local user.email "$GIT_EMAIL"
git config --local user.signingkey "$KEY_FPR"
git config --local commit.gpgsign "true"
git config --local tag.gpgsign "true"
