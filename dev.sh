#!/run/current-system/profile/bin/env bash

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

guix shell --container \
    --share="$SCRIPT_DIRECTORY/.container-home/.cache/amp"="$HOME/.cache/amp" \
    --share="$SCRIPT_DIRECTORY/.container-home/.config/amp"="$HOME/.config/amp" \
    --share="$SCRIPT_DIRECTORY/.container-home/.local/share/amp"="$HOME/.local/share/amp" \
    --share="$SCRIPT_DIRECTORY/.container-home/.zshrc"="$HOME/.zshrc" \
    --share="$SCRIPT_DIRECTORY/.." \
    --expose="$HOME/.terminfo" \
    --expose='/gnu/store' \
    --preserve='^TERMINFO$' \
    --preserve='^TERM$' \
    --network \
    --no-cwd \
    --emulate-fhs \
    --cwd="$SCRIPT_DIRECTORY" \
    --manifest="$SCRIPT_DIRECTORY/manifest.scm" \
    -- env PROMPT="%F{red}┌─╼[%F{green}%m:%2~%F{red}(dev)]"$'\n'"└╼ %{%f%}" zsh -l
