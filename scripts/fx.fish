# fx - One command to switch to enhanced fish
# Install: source this file or add to ~/.config/fish/functions/fx.fish
#
# Usage: fx

function fx -d "Switch to enhanced fish with tracing"
    # Install if needed
    if not test -f ~/.config/fish/conf.d/flow-shell-wrappers.fish
        fishx install
    end

    # Exec into enhanced fish
    exec ~/.local/bin/fish
end
