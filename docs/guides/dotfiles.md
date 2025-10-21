# Dotfiles Setup Guide

---

## What Are Dotfiles?

Dotfiles are configuration files that customize your development environment:

- `.zshrc` - Zsh shell configuration (aliases, prompts, functions)
- `.vimrc` - Vim editor settings
- `.gitconfig` - Git configuration (username, email, aliases)
- `.Rprofile` - R startup configuration

**Key Concept**: zzcollab copies YOUR dotfiles into Docker containers so your development environment feels familiar and consistent.

---

## Why Use Dotfiles with ZZCOLLAB?

### WITHOUT DOTFILES (generic environment)

- Generic shell prompt
- No custom aliases or functions
- Default Vim configuration
- Must reconfigure Git every time

### WITH DOTFILES (personalized environment)

- Your custom prompt with Git status
- All your favorite aliases work
- Your Vim settings preserved
- Git configured automatically

**Example**: Your `.zshrc` might have:
```bash
alias ll='ls -lah'
alias gs='git status'
alias gc='git commit'
```

These work in ALL your zzcollab containers automatically!

---

## The Two Dotfiles Flags

### -d, --dotfiles-dir PATH

Copy dotfiles that ALREADY HAVE DOTS in their names

**Example directory structure**:
```
~/dotfiles/
├── .zshrc        ← Has dot already
├── .vimrc        ← Has dot already
└── .gitconfig    ← Has dot already
```

**Usage**:
```bash
zzcollab -d ~/dotfiles
# Copies: .zshrc → /home/analyst/.zshrc
#         .vimrc → /home/analyst/.vimrc
```

### -D, --dotfiles-nodot PATH

Copy dotfiles WITHOUT DOTS and ADD dots when copying

**Example directory structure**:
```
~/dotfiles/
├── zshrc         ← No dot (version control friendly)
├── vimrc         ← No dot
└── gitconfig     ← No dot
```

**Usage**:
```bash
zzcollab -D ~/dotfiles
# Copies: zshrc → /home/analyst/.zshrc
#         vimrc → /home/analyst/.vimrc
```

### Which One Should I Use?

Most people use `-D` (no-dot format) because:
- Files visible in file browsers (don't hide)
- Easier to version control on GitHub
- Less confusion with hidden files

But `-d` works great if you already have dotfiles with dots!

---

## Common Dotfiles to Include

### Essential Dotfiles

#### 1. .zshrc (Zsh configuration)

**What to include**:
- Custom prompt
- Useful aliases
- Environment variables
- Shell functions

**Example minimal .zshrc**:
```bash
# Custom prompt
PROMPT='%F{blue}%~%f %# '

# Useful aliases
alias ll='ls -lah'
alias ..='cd ..'
alias gst='git status'
alias gco='git checkout'

# R-specific helpers
alias R='R --no-save --no-restore'
```

#### 2. .gitconfig (Git configuration)

**What to include**:
- Your name and email
- Useful Git aliases
- Default branch settings

**Example**:
```ini
[user]
    name = Your Name
    email = your.email@example.com
[alias]
    st = status
    co = checkout
    ci = commit
    br = branch
[init]
    defaultBranch = main
```

#### 3. .vimrc (Vim configuration)

**What to include**:
- Syntax highlighting
- Tab settings
- Line numbers

**Example minimal .vimrc**:
```vim
syntax on
set number
set tabstop=4
set shiftwidth=4
set expandtab
```

#### 4. .Rprofile (R configuration)

**What to include**:
- CRAN mirror
- Library paths
- Custom options

**Example**:
```r
options(
  repos = c(CRAN = "https://cran.rstudio.com/"),
  stringsAsFactors = FALSE,
  max.print = 100
)
```

### Optional but Useful

5. `.tmux.conf` (tmux terminal multiplexer)
6. `.bashrc` (if you use bash instead of zsh)
7. `.inputrc` (readline configuration)

---

## Setting Up Your Dotfiles Directory

### First Time Setup

**Step 1**: Create dotfiles directory
```bash
mkdir ~/dotfiles
cd ~/dotfiles
```

**Step 2**: Add your configuration files (no-dot format recommended)
```bash
# Create basic zshrc
cat > zshrc << 'EOZ'
# Custom prompt
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '

# Useful aliases
alias ll='ls -lah'
alias gst='git status'
EOZ

# Create basic gitconfig
cat > gitconfig << 'EOG'
[user]
    name = YOUR_NAME
    email = YOUR_EMAIL
[alias]
    st = status
    co = checkout
EOG
```

**Step 3**: Version control your dotfiles (optional but recommended)
```bash
cd ~/dotfiles
git init
git add .
git commit -m "Initial dotfiles"
git remote add origin https://github.com/yourusername/dotfiles.git
git push -u origin main
```

**Step 4**: Configure zzcollab to use them
```bash
zzcollab --config set dotfiles-dir "~/dotfiles"
zzcollab --config set dotfiles-nodot true
```

**Step 5**: Test with new project
```bash
zzcollab -p test-project
make docker-zsh
# Check if your aliases and prompt work!
```

---

## Configuration File Approach

### Set Once, Use Forever

```bash
# Set your dotfiles configuration
zzcollab --config set dotfiles-dir "~/dotfiles"
zzcollab --config set dotfiles-nodot true

# Now all future projects automatically use your dotfiles
zzcollab -p project1   # Uses ~/dotfiles automatically
zzcollab -p project2   # Uses ~/dotfiles automatically
```

### Check Current Configuration

```bash
zzcollab --config get dotfiles-dir
zzcollab --config get dotfiles-nodot
```

---

## Troubleshooting

### ISSUE 1: "My aliases don't work in the container!"

**DIAGNOSIS**:
```bash
# Check if dotfiles were copied
docker run --rm TEAM/PROJECTcore-shell:latest ls -la /home/analyst/
# Look for .zshrc, .vimrc, etc.
```

**COMMON CAUSES**:
- Forgot `-d` or `-D` flag when building
- Wrong path to dotfiles directory
- Dotfiles directory empty

**SOLUTION**:
```bash
# Rebuild with correct dotfiles flag
zzcollab -t TEAM -p PROJECT -d ~/dotfiles
```

### ISSUE 2: "Which flag do I use? -d or -D?"

**EASY TEST**:
```bash
ls ~/dotfiles/

# If you see:  .zshrc  .vimrc  .gitconfig  → Use -d
# If you see:   zshrc   vimrc   gitconfig  → Use -D
```

### ISSUE 3: "Dotfiles work in zsh but not in RStudio"

**EXPLANATION**:
- RStudio doesn't load `.zshrc` (it's not a shell)

**SOLUTION**:
- Put R-specific configuration in `.Rprofile` instead

**Example .Rprofile for RStudio**:
```r
options(repos = c(CRAN = "https://cran.rstudio.com/"))
setHook("rstudio.sessionInit", function(newSession) {
  if (newSession && is.null(rstudioapi::getActiveProject()))
    setwd("/home/analyst/project")
}, action = "append")
```

### ISSUE 4: "My dotfiles have sensitive information!"

**BEST PRACTICE**:

1. **Create separate dotfiles for zzcollab** (no secrets)
   ```bash
   ~/dotfiles-zzcollab/
   ```

2. **Use environment variables instead of hardcoded values**
   ```bash
   # In .zshrc
   export GITHUB_TOKEN="${GITHUB_TOKEN}"  # Read from environment
   ```

3. **Never commit API keys or passwords to version control**

4. **Use .gitignore if you must have local-only secrets**
   ```bash
   # In ~/dotfiles/.gitignore
   gitconfig-local
   secrets.env
   ```

### ISSUE 5: "Dotfiles work locally but not for team members"

**EXPLANATION**:
- Dotfiles baked into team Docker images contain YOUR settings

**SOLUTION**:
```bash
# Team lead: Use minimal/generic dotfiles for team images
# Team members: Use their own dotfiles when joining

# Team lead builds images:
zzcollab -t TEAM -p PROJECT -d ~/dotfiles-minimal

# Team member joins with their dotfiles:
zzcollab -t TEAM -p PROJECT --use-team-image -d ~/my-dotfiles
```

### ISSUE 6: "Changes to dotfiles don't appear in container"

**CAUSE**:
- Dotfiles copied during IMAGE BUILD, not container start

**SOLUTION**:
```bash
# Must rebuild Docker image to pick up dotfile changes:
cd ~/projects/my-project
zzcollab -t TEAM -p PROJECT -d ~/dotfiles  # Rebuild
make docker-build
```

**Alternative**: Mount dotfiles for testing (advanced)
```bash
docker run -v ~/dotfiles/zshrc:/home/analyst/.zshrc ...
```

---

## Advanced: Sharing Dotfiles with Your Team

### Strategy: Version-Controlled Team Dotfiles

**1. Create team dotfiles repository**
```bash
mkdir ~/team-dotfiles
cd ~/team-dotfiles
# Add standard configuration for your lab/team
git init
git remote add origin https://github.com/yourteam/dotfiles.git
git push -u origin main
```

**2. Team members clone the dotfiles**
```bash
git clone https://github.com/yourteam/dotfiles.git ~/team-dotfiles
zzcollab --config set dotfiles-dir "~/team-dotfiles"
```

**3. Everyone gets consistent environment**
- Same aliases, same prompt, same Git config!

**4. Update team dotfiles as needed**
```bash
cd ~/team-dotfiles
git pull  # Get latest team standards
# Rebuild your images to pick up changes
```

---

## Example: Comprehensive Research Dotfiles

### ~/dotfiles/zshrc

```bash
# Research-focused Zsh configuration

# Custom prompt with Git branch
autoload -Uz vcs_info
precmd() { vcs_info }
setopt prompt_subst
PROMPT='%F{cyan}[%~]%f %F{yellow}${vcs_info_msg_0_}%f
%# '

# R and RStudio helpers
alias R='R --no-save --no-restore'
alias Rstudio='rstudio &'
alias rcheck='R CMD check --as-cran'

# Git shortcuts
alias gst='git status'
alias gco='git checkout'
alias gaa='git add -A'
alias gcm='git commit -m'
alias gp='git push'

# Project navigation
alias proj='cd /home/analyst/project'
alias data='cd /home/analyst/project/data'
alias scripts='cd /home/analyst/project/scripts'

# Docker helpers (for use on host)
alias dps='docker ps'
alias dlog='docker logs -f'
```

### ~/dotfiles/Rprofile

```r
# R environment configuration for research

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Research-friendly defaults
options(
  stringsAsFactors = FALSE,
  max.print = 100,
  scipen = 10,  # Prefer fixed over scientific notation
  warn = 1      # Show warnings as they occur
)

# Automatically load common packages (optional)
if (interactive()) {
  suppressMessages({
    library(here)
    library(usethis)
  })
  message("✅ Loaded: here, usethis")
}

# Set working directory in RStudio
setHook("rstudio.sessionInit", function(newSession) {
  if (newSession && is.null(rstudioapi::getActiveProject()))
    setwd("/home/analyst/project")
}, action = "append")
```

### ~/dotfiles/gitconfig

```ini
[user]
    name = Your Name
    email = you@example.com

[core]
    editor = vim
    autocrlf = input

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --graph --oneline --all

[init]
    defaultBranch = main

[pull]
    rebase = false
```

---

## See Also

- `zzcollab --help` - General help
- `zzcollab --help-quickstart` - Getting started
- `zzcollab --help-workflow` - Daily development workflow
- `zzcollab --help-config` - Configuration system
