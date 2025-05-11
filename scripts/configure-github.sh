#!/usr/bin/env bash
set -euo pipefail

# 1. Prompt for user info
read -p "Full Name: " FULL_NAME
export GIT_USERNAME="$FULL_NAME"
read -p "Email: " EMAIL
export GIT_EMAIL="$EMAIL"
read -sp "Passphrase (leave empty for no passphrase): " PASSPHRASE
echo

# 2. Create a GPG batch file
BATCH_FILE=$(mktemp)
cat > "$BATCH_FILE" <<EOF
%echo Generating a GPG key
Key-Type: EDDSA
Key-Curve: ed25519
Key-Length: 4096
Key-Usage: sign
Name-Real: $FULL_NAME
Name-Email: $EMAIL 
Expire-Date: 0
EOF

# Only include Passphrase line if provided
if [[ -n "$PASSPHRASE" ]]; then
  cat >> "$BATCH_FILE" <<EOF
Passphrase: $PASSPHRASE
EOF
fi

cat >> "$BATCH_FILE" <<EOF
%commit
%echo Key generation complete
EOF

# 3. Generate the key
gpg --batch --generate-key "$BATCH_FILE"
rm -f "$BATCH_FILE"

# 4. Extract the newly generated key’s fingerprint
KEY_FPR=$(gpg --list-secret-keys --with-colons "$EMAIL" \
           | awk -F: '/^sec/ {print $5; exit}')

if [[ -z "$KEY_FPR" ]]; then
  echo "ERROR: Could not find GPG key fingerprint for $EMAIL" >&2
  exit 1
fi

export GIT_SIGNING_KEY="$KEY_FPR"
echo "Generated GPG key with fingerprint: $GIT_SIGNING_KEY"

# 5. Authenticate to GitHub (interactive)
echo "Now logging in to GitHub via GH CLI..."
gh auth login -s write:gpg_key || {
  echo "GitHub login failed. Make sure gh CLI is installed and configured." >&2
  exit 1
}

# 6. Export and upload the public key
echo "Exporting public key and uploading to GitHub..."
gpg --armor --export "$GIT_SIGNING_KEY" | gh gpg-key add -t $(hostname) -

# 7. Create a git configuration file with signing rsettings
cat > ~/.gitsigning << EOF
[user]
    name="$FULL_NAME"
    email="$EMAIL"
    signingkey="$KEY_FPR"

[commit]
    gpgsign=true

[tag]
    gpgsign=true
EOF
