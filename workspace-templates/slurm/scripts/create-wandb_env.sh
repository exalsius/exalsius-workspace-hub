#!/bin/bash

set -euo pipefail


CSV_FILE="coldstart2025_wandb_keys.csv"
BASE_HOME="/home"

tail -n +2 "$CSV_FILE" | while IFS=',' read -r raw_user key; do

    user="${raw_user##*-}"

    user_home="$BASE_HOME/$user"
    bashrc="$user_home/.bashrc"

    if [[ -d "$user_home" ]]; then
        # bashrc und profile werden per default nicht angelegt. Daher aus Vorlage kopieren
        cp /etc/skel/.bashrc "$user_home"
        chown "$user":"$user" "$user_home/.bashrc"
        cp /etc/skel/.profile "$user_home"
        chown "$user":"$user" "$user_home/.profile"

        echo "export WANDB_API_KEY=\"$key\"" >> "$bashrc"

        echo "Set WANDB_API_KEY for $user → $key"
    else
        echo "Home directory for $user not found ($user_home)"
    fi
done