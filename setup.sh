#!/usr/bin/env bash

set -euo pipefail

# Keep this script usable from any working directory.
CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

backup_path() {
    local path="$1"
    local dir name stem ext candidate index

    dir="$(dirname -- "$path")"
    name="$(basename -- "$path")"

    if [[ "$name" == *.* && "$name" != .* ]]; then
        stem="${name%.*}"
        ext=".${name##*.}"
    else
        stem="$name"
        ext=""
    fi

    candidate="$dir/${stem}_back${ext}"
    index=1
    while [[ -e "$candidate" || -L "$candidate" ]]; do
        candidate="$dir/${stem}_back_${index}${ext}"
        ((index++))
    done

    printf '%s\n' "$candidate"
}

# Each top-level directory maps to a hidden directory in $HOME:
#   ./prime/agent/settings.json -> ~/.prime/agent/settings.json
while IFS= read -r -d '' agent_source; do
    agent_name="$(basename -- "$agent_source")"
    agent_target="$HOME/.${agent_name}"

    if [[ -e "$agent_target" && ! -d "$agent_target" ]]; then
        echo "error: $agent_target exists but is not a directory" >&2
        exit 1
    fi
    mkdir -p -- "$agent_target"

    while IFS= read -r -d '' source_file; do
        relative_path="${source_file#"$agent_source"/}"
        target_file="$agent_target/$relative_path"
        mkdir -p -- "$(dirname -- "$target_file")"

        # Do not back up an already-correct link when the script is rerun.
        if [[ -L "$target_file" && "$(readlink -- "$target_file")" == "$source_file" ]]; then
            continue
        fi

        if [[ -e "$target_file" || -L "$target_file" ]]; then
            backup_file="$(backup_path "$target_file")"
            mv -- "$target_file" "$backup_file"
            echo "backed up $target_file -> $backup_file"
        fi

        ln -s -- "$source_file" "$target_file"
    done < <(find "$agent_source" \( -type f -o -type l \) -print0)

    echo "$agent_name: ok"
done < <(find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
