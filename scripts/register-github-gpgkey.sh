#!/usr/bin/env bash
set -euo pipefail

shopt -s extglob

declare GIT_EMAIL FULL_NAME

while (( $# > 0 )) ; do
  case $1 in
    -e|--email) GIT_EMAIL=( "${2?Missing argument for -e|--email}" ) ; shift ;;
    -n|--name) FULL_NAME=( "${2?Missing argument for -n|--name}" ) ; shift ;;
    --) shift; break ;;
    -*) printf >&2 'Unknown option %s\n' "$1" ; exit 1 ;;
    *) break ;;
  esac
  shift
done


# Prompt for user info
if [ -z "${GIT_EMAIL+x}" ]; then
    read -p "Github Email: " EMAIL
    export GIT_EMAIL="$EMAIL"
fi

# Check for existing GPG key for the email, and generate if it does not exist
KEY_FPR=$(gpg --list-secret-keys --with-colons "$GIT_EMAIL" 2>/dev/null \
           | awk -F: '/^sec/ {print $5; exit}') || true

if [[ -z "$KEY_FPR" ]]; then
    if [ -z "${FULL_NAME+x}" ]; then
        read -p "Full Name: " FULL_NAME
        echo
    fi

    # Get a passphrase for the new Key-Type
    read -sp "Passphrase (leave empty for no passphrase): " PASSPHRASE
    echo

    # 2.1 Create a GPG batch file
    BATCH_FILE=$(mktemp)
    cat > "$BATCH_FILE" <<EOF
    %echo Generating a GPG key
    Key-Type: EDDSA
    Key-Curve: ed25519
    Key-Length: 4096
    Key-Usage: sign
    Name-Real: $FULL_NAME
    Name-Email: $GIT_EMAIL 
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

    # Generate the key
    gpg --batch --generate-key "$BATCH_FILE"
    rm -f "$BATCH_FILE"

    # Extract the newly generated key’s fingerprint
    KEY_FPR=$(gpg --list-secret-keys --with-colons "$GIT_EMAIL" \
               | awk -F: '/^sec/ {print $5; exit}')

    if [[ -z "$KEY_FPR" ]]; then
      echo "ERROR: Could not find GPG key fingerprint for $GIT_EMAIL" >&2
      exit 1
    fi
fi


export GIT_SIGNING_KEY="$KEY_FPR"
echo "Generated GPG key with fingerprint: $GIT_SIGNING_KEY"

# Authenticate to GitHub (interactive)

if ! gh auth status | grep -q "Active account: true"; then
    echo "Now logging in to GitHub via GH CLI..."
    gh auth login --scopes read:gpg_key,write:gpg_key || {
      echo "GitHub login failed. Make sure gh CLI is installed and configured." >&2
      exit 1
    }
fi


# Check gh for existing key
is_key_registered=$(gh gpg-key list | awk -v val="$GIT_SIGNING_KEY" '$2==val')
if [ -z "$is_key_registered" ]; then
    # 4. Export and upload the public key
    echo "Exporting public key and uploading to GitHub..."
    # gpg --armor --export "$GIT_SIGNING_KEY" | gh gpg-key add -t $(hostname) -
else
    echo "Key $GIT_SIGNING_KEY already registered to account"
fi
