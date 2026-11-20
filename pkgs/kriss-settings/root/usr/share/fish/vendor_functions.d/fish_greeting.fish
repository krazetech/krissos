# KrissOS: a new terminal opens with the KrissOS emblem and a summary of this PC
# (fastfetch, configured in /etc/xdg/fastfetch/config.jsonc), not fish's welcome text.
# Your own fish_greeting in ~/.config/fish/functions replaces this one;
# `set -U fish_greeting` with nothing after it turns the greeting off.
function fish_greeting
    if set -q fish_greeting[1]; or not command -q fastfetch
        printf '%s\n' $fish_greeting
        return
    end
    fastfetch
end
