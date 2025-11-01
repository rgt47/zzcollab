# ==========================================================================
# ZSH CONFIGURATION - REFACTORED FOR ZZCOLLAB DOCKER FILTERING
# ==========================================================================
#
# 🍎 MACOS-SPECIFIC CONTENT GROUPED FOR EASY IDENTIFICATION:
#
# The following sections contain macOS-specific content that will be
# automatically filtered out when creating Docker-compatible .zshrc_docker:
#
# - Section 3: macOS-specific configuration (Homebrew paths, etc.)
# - Section 8: Plugin management (brew --prefix paths)
# - Section 10: macOS-specific aliases (open, Skim, etc.)
# - Section 11: macOS-specific functions (Mathematica, etc.)
# - Section 12: macOS-specific external tools (conda paths, etc.)
#
# All sections marked with 🍎 will be removed or replaced in Docker containers.
#
# ==========================================================================

# ==========================================================================
# 1. ENVIRONMENT & SECURITY
# ==========================================================================

# Security: Source sensitive environment variables from separate file
[[ -f ~/.env ]] && source ~/.env

# ==========================================================================
# 2. CORE SHELL CONFIGURATION (Cross-platform)
# ==========================================================================

# Basic exports
export EDITOR="vim"
export DOCKER_BUILDKIT=1
export GITHUB_USER="rgt47"

# TeX configuration
export TEXINPUTS=".:$HOME/shr/images:$HOME/shr:"
export BIBINPUTS=".:$HOME/shr/bibfiles:$HOME/shr"

# ==========================================================================
# 3. MACOS-SPECIFIC CONFIGURATION
# ==========================================================================
# 🍎 ALL MACOS-SPECIFIC SETTINGS GROUPED HERE FOR EASY IDENTIFICATION

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS-specific application configuration
    export HOMEBREW_AUTO_UPDATE_SECS="604800"

    # macOS PATH configuration (includes Homebrew paths)
    # SECURITY FIX: Removed leading "." from PATH
    export PATH="$HOME/bin:$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
else
    # Linux PATH configuration
    export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
fi

# ==========================================================================
# 4. CORE SHELL OPTIONS (Cross-platform)
# ==========================================================================

# Directory shortcuts
cdpath=($HOME/Dropbox $HOME/Dropbox/prj $HOME/Dropbox/sbx $HOME/Dropbox/work)

# Basic shell options
setopt auto_cd auto_pushd pushd_ignore_dups pushdminus
setopt PROMPT_SUBST

# Vi mode
bindkey -v

# ==========================================================================
# 5. HISTORY MANAGEMENT (Cross-platform)
# ==========================================================================

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_DUPS INC_APPEND_HISTORY HIST_VERIFY

# ==========================================================================
# 6. COMPLETION & NAVIGATION (Cross-platform)
# ==========================================================================

# PERFORMANCE: Completion system with caching (only rebuild once per day)
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
compdef _dirs d

# ==========================================================================
# 7. PROMPT & VCS INTEGRATION (Cross-platform)
# ==========================================================================

# Version control setup
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%b '

# Custom prompt
PROMPT='%F{cyan}%m%f %F{green}%*%f %F{yellow}${${PWD:A}/$HOME/~}%f %F{red}${vcs_info_msg_0_}%f$ %(?:☕  :☔  )'

# ==========================================================================
# 8. PLUGIN MANAGEMENT (Platform-aware)
# ==========================================================================

# Load plugins based on OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux plugin paths
    [[ -s /home/z/.autojump/etc/profile.d/autojump.sh ]] && source /home/z/.autojump/etc/profile.d/autojump.sh
    [[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
    [[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # 🍎 macOS plugin paths (uses Homebrew)
    # PERFORMANCE: Cache brew --prefix to avoid slow command on every shell startup
    if [[ -z "$BREW_PREFIX" ]]; then
        export BREW_PREFIX="/opt/homebrew"
    fi
    [[ -f "$BREW_PREFIX/etc/profile.d/autojump.sh" ]] && source "$BREW_PREFIX/etc/profile.d/autojump.sh"
    [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Plugin configuration
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=red,bold,underline'

# ==========================================================================
# 9. TOOL-SPECIFIC CONFIGURATION (Cross-platform)
# ==========================================================================

# FZF configuration
if type rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden'
    export FZF_DEFAULT_OPTS='-m --height 50% --border --reverse'
fi

# ==========================================================================
# 10. ALIASES (Cross-platform)
# ==========================================================================

# Navigation aliases
alias -- -='cd -'
alias -g ...='../..'

# File listing with color support (OS-aware)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (BSD ls) - check if GNU ls is installed via coreutils
    if command -v gls &> /dev/null; then
        alias ls='gls --color=auto'
        alias ll='gls -lh --color=auto'
    else
        alias ls='ls -G'
        alias ll='ls -lhG'
    fi
else
    # Linux (GNU ls)
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
fi

# Directory stack navigation
alias lt='eza -lrha -sold'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'

# Color support for common tools
alias grep='grep --color=auto'

# diff with color (OS-aware)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS diff doesn't support --color, check for GNU diff
    if command -v gdiff &> /dev/null; then
        alias diff='gdiff --color=auto'
    fi
else
    alias diff='diff --color=auto'
fi

# Application shortcuts
alias za='zathura'
alias hh='history'
alias R='R --quiet --no-save'
alias mm='mutt'
alias v='vim'
alias ZZ='exit'

# Config editing
alias vc='vim ~/.vimrc'
alias vz='vim ~/Dropbox/dotfiles/zsh_eval'
alias sz='source ~/.zshrc'

# Safety aliases
alias tp='trash-put -v'
# alias rm='echo "This is not the command you are looking for."; false'

# ==========================================================================
# 🍎 MACOS-SPECIFIC ALIASES
# ==========================================================================

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS application shortcuts
    alias sk='open -a Skim'
fi

# ==========================================================================
# 11. CUSTOM FUNCTIONS (Cross-platform)
# ==========================================================================

# Directory listing function
ddd() {
    if [[ -n $1 ]]; then
        dirs "$@"
    else
        dirs -v | head -n 10
    fi
}

# File finder with cd
ff() {
    local file
    file=$(rg --files "${1:-.}" 2>/dev/null | fzf --select-1 --exit-0)
    if [[ -n "$file" ]]; then
        cd "$(dirname "$file")" || return 1
    fi
}

# PDF finder with zathura (IMPROVED: converted from alias to function with error handling)
pp() {
    local pdf
    pdf=$(rg --files 2>/dev/null | rg "\.pdf$" | fzf)
    if [[ -n "$pdf" ]]; then
        zathura "$pdf" &
    fi
}

# R file finder with vim (IMPROVED: converted from alias to function with error handling)
rr() {
    local rfile
    rfile=$(rg --files 2>/dev/null | rg "\.(R|Rmd)$" | fzf)
    if [[ -n "$rfile" ]]; then
        vim "$rfile"
    fi
}

# ==========================================================================
# 🍎 MACOS-SPECIFIC FUNCTIONS
# ==========================================================================

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mathematica script runner (macOS only) - IMPROVED: added error handling
    mma() {
        if [[ -z "$1" ]]; then
            echo "Usage: mma <script.wl>" >&2
            return 1
        fi
        if [[ ! -f "$1" ]]; then
            echo "Error: File '$1' not found" >&2
            return 1
        fi
        /Applications/Mathematica.app/Contents/MacOS/WolframKernel -script "$1"
    }
fi

# ==========================================================================
# 12. EXTERNAL TOOL INTEGRATION
# ==========================================================================

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# XQuartz DISPLAY variable for Docker GUI apps (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -z "$DISPLAY" ]]; then
        export DISPLAY=:0
    fi
fi

# Conda initialization (platform-aware)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # 🍎 macOS conda path
    _CONDA_ROOT="/opt/miniconda3"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux conda path (adjust if different)
    _CONDA_ROOT="$HOME/miniconda3"
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if [[ -n "$_CONDA_ROOT" && -f "$_CONDA_ROOT/bin/conda" ]]; then
    __conda_setup="$("$_CONDA_ROOT/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
    if [[ $? -eq 0 ]]; then
        eval "$__conda_setup"
    else
        if [[ -f "$_CONDA_ROOT/etc/profile.d/conda.sh" ]]; then
            . "$_CONDA_ROOT/etc/profile.d/conda.sh"
        else
            export PATH="$_CONDA_ROOT/bin:$PATH"
        fi
    fi
    unset __conda_setup
fi
unset _CONDA_ROOT
# <<< conda initialize <<<
