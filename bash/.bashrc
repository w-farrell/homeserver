# ~/.bashrc - shared for Proxmox host + containers/VMs

#############################
# 1. Non-interactive shells #
#############################
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

####################
# 2. Basic options #
####################
# History
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=5000
HISTFILESIZE=10000
shopt -s histappend
PROMPT_DIRTRIM=3

# Better globbing
shopt -s cdspell
shopt -s checkwinsize
shopt -s no_empty_cmd_completion

######################
# 3. Color detection #
######################
# Ensure TERM is something sensible
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    TERM=xterm-256color
fi

# Check if terminal supports color
_color_support=0
if command -v tput >/dev/null 2>&1; then
    if [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
        _color_support=1
    fi
fi

####################
# 4. Useful aliases#
####################
if [ "$_color_support" -eq 1 ]; then
    alias ls='ls --color=auto'
    alias ll='ls -alF --color=auto'
    alias la='ls -A --color=auto'
    alias grep='grep --color=auto'
    alias egrep='egrep --color=auto'
    alias fgrep='fgrep --color=auto'
else
    alias ll='ls -alF'
    alias la='ls -A'
fi

alias ..='cd ..'
alias ...='cd ../..'
alias l='ls'
alias c='clear'

# Safer rm/mv/cp (comment out if you don't like prompts)
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Source user-defined extra aliases if present
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

################################
# 5. Helper: git branch name   #
################################
git_branch() {
    command -v git >/dev/null 2>&1 || return
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return
    printf '%s' "$branch"
}

#####################################
# 6. Helper: role (PVE/CT/VM/other) #
#####################################
pve_role() {
    # Proxmox node has /etc/pve/.version
    if [ -f /etc/pve/.version ]; then
        printf 'PVE'
        return
    fi

    # Try to detect containers/VMs via systemd-detect-virt if available
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local vt
        vt=$(systemd-detect-virt --quiet --container && echo container || echo none 2>/dev/null)
        if [ "$vt" = "container" ]; then
            printf 'CT'
            return
        fi

        vt=$(systemd-detect-virt --quiet && systemd-detect-virt 2>/dev/null)
        if [ "$vt" != "none" ] && [ -n "$vt" ]; then
            # KVM, qemu, vmware, etc.
            printf 'VM'
            return
        fi
    fi

    # Fallback: treat as generic Linux host
    printf 'LINUX'
}

########################################
# 7. Colored, status-aware PVE prompt  #
########################################
pve_prompt() {
    # Capture exit status of last command *before* we do anything else
    local last_status=$?

    # Colors (only if supported)
    local c_reset='' c_red='' c_green='' c_yellow='' c_blue='' c_magenta='' c_cyan=''
    if [ "$_color_support" -eq 1 ]; then
        c_reset='\[\e[0m\]'
        c_red='\[\e[1;31m\]'
        c_green='\[\e[1;32m\]'
        c_yellow='\[\e[1;33m\]'
        c_blue='\[\e[1;34m\]'
        c_magenta='\[\e[1;35m\]'
        c_cyan='\[\e[1;36m\]'
    fi

    # Role and color by role
    local role role_color
    role=$(pve_role)
    case "$role" in
        PVE)
            role_color=$c_red    # bright red: dangerous, real node
            ;;
        CT)
            role_color=$c_green  # green: containers feel "safe"
            ;;
        VM)
            role_color=$c_magenta
            ;;
        *)
            role_color=$c_cyan
            ;;
    esac

    # Status icon
    local status_symbol status_color
    if [ $last_status -eq 0 ]; then
        status_symbol="✔"
        status_color=$c_green
    else
        status_symbol="✘"
        status_color=$c_red
    fi

    # Git branch (if any)
    local branch branch_str=""
    branch=$(git_branch)
    if [ -n "$branch" ]; then
        branch_str=" ${c_yellow}(${branch})${c_reset}"
    fi

    # Build PS1:
    # ✔ [PVE:intrepid] /path (branch)
    # $
    PS1="${status_color}${status_symbol}${c_reset} ${role_color}[${role}:\h]${c_reset} ${c_blue}\w${c_reset}${branch_str}\n\$ "
}

# Use pve_prompt for every interactive prompt
PROMPT_COMMAND=pve_prompt

#############################
# 8. Misc quality-of-life   #
#############################
# Less dumb-less
export LESS='-R'

# Make sure EDITOR is reasonable
if command -v nano >/dev/null 2>&1; then
    export EDITOR=nano
fi

