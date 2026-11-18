if status is-interactive
    # Starship custom prompt
    if command -v starship >/dev/null 2>&1
        starship init fish | source
        disable_transience 2>/dev/null
    end

    # Direnv + Zoxide
    command -v direnv >/dev/null 2>&1 && direnv hook fish | source
    command -v zoxide >/dev/null 2>&1 && zoxide init fish | source

    # Better ls (eza)
    if command -v eza >/dev/null 2>&1
        set -gx EZA_CONFIG_DIR "$HOME/.config/eza"
        alias ls='eza --icons --group-directories-first -1'
    end

    # Yazi CWD wrapper function (yy)
    function yy
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    # Abbrs
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'
    abbr lt 'eza --tree --level=2 --icons'
    abbr tree 'eza --tree --icons'

    abbr -a update "sudo pacman -Syu"
    abbr -a install "sudo pacman -S"
    abbr -a remove "sudo pacman -Rns"
    abbr -a search "pacman -Ss"
    abbr -a clean "sudo pacman -Sc"

    # Custom colours
    cat ~/.local/state/caelestia/sequences.txt 2> /dev/null

    # For jumping between prompts in foot terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end

	# Redraw prompt on custom user signal (SIGUSR1)
    function _reload_theme_prompt --on-signal SIGUSR1
        commandline -f repaint
    end

    # Custom fish config
    set -q XDG_CONFIG_HOME && set -l cConf $XDG_CONFIG_HOME/caelestia || set -l cConf $HOME/.config/caelestia
    source $cConf/user-config.fish 2> /dev/null
end


# Add local bin to PATH
set -gx PATH "$HOME/.local/bin" $PATH
