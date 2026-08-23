#!/usr/bin/env bash

# Copyright (C) 2026 Diwas Neupane
# SPDX-License-Identifier: Apache-2.0
# Omarchy (Arch Linux) Setup Script

# *******************************************************************************
# - Sets up an Omarchy/Arch Linux development environment.
# - Installs git, OpenSSH, GnuPG, a text editor, and GitHub CLI.
# - Generates SSH and GPG keys for GitHub.
# - Supports SSH/GPG backup and restoration.
# - Supports restoring keys from a GitHub repository.
# - Author: Diwas Neupane (techdiwas)
# - Version: omarchy:1.0
# - Last modified: 20260823
#
# Omarchy is Arch-based, so this script uses pacman instead of apt/dpkg.
# It intentionally does not modify /etc/pacman.conf or Omarchy's internal files.
# *******************************************************************************

set -o pipefail

SCRIPT_VERSION="20260823"

# --- helpers ------------------------------------------------------------------

say() {
    printf '%s\n' "$*"
}

abort() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_omarchy() {
    if [[ ! -f /etc/arch-release ]]; then
        abort "This script expects an Arch Linux base (Omarchy). /etc/arch-release was not found."
    fi

    if ! command_exists pacman; then
        abort "pacman is not available. This is not a supported Omarchy/Arch environment."
    fi
}

# --- shell/profile settings ---------------------------------------------------

change_settings() {
    local input=""

    echo "-- Edit shell profile settings (~/.bashrc)? [Y/n]"
    read -r input
    if [[ "$input" == "Y" || "$input" == "y" || -z "$input" ]]; then
        "${EDITOR:-nvim}" "${HOME}/.bashrc"
    fi
}

# Omarchy uses Bash as part of its normal shell/session setup. Keep user changes
# in ~/.bashrc instead of modifying files under /usr/share/omarchy.
setup_shell_environment() {
    local bashrc="${HOME}/.bashrc"
    touch "$bashrc"

    if ! grep -qxF 'export GPG_TTY=$(tty 2>/dev/null || true)' "$bashrc"; then
        cat >>"$bashrc" <<'BASHRC'

# Set GPG_TTY for GPG passphrase handling.
export GPG_TTY=$(tty 2>/dev/null || true)
BASHRC
        say "-- Added GPG_TTY to ~/.bashrc."
    else
        say "-- GPG_TTY is already configured in ~/.bashrc."
    fi
}

# Keep this compatible with the original script's Downloads-based restore flow.
setup_storage() {
    if [[ -d "$HOME/Downloads" ]]; then
        say "-- Downloads directory exists."
    else
        say "-- Downloads directory is missing."
        mkdir -p "$HOME/Downloads" || abort "Could not create $HOME/Downloads."
        say "-- Downloads directory created at $HOME/Downloads."
    fi
}

# --- package management -------------------------------------------------------

update_environment() {
    say "-- Updating Arch Linux packages..."
    sudo pacman -Syu --noconfirm
}

install_packages() {
    local packages=(git openssh gnupg)
    local extra_packages=()
    local package_name=""
    local input=""

    say "-----------------------------------"
    say "-- Installing required packages ..."
    say "-----------------------------------"

    # nano is kept as a fallback editor; Omarchy systems commonly already have
    # Neovim, so Git uses nvim when available.
    packages+=(nano github-cli)

    echo "-- Do you want to install additional packages (y/N)?"
    read -r input
    if [[ "$input" == "Y" || "$input" == "y" ]]; then
        echo "-- Enter package names separated by spaces:"
        read -r -a extra_packages
        packages+=("${extra_packages[@]}")
    fi

    sudo pacman -S --needed --noconfirm "${packages[@]}" \
        || abort "Package installation failed."

    say "-- Required packages have been installed."
}

# --- identity/input validation ------------------------------------------------

validate_email() {
    local email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    [[ "$1" =~ $email_regex ]]
}

check_inputs() {
    echo "-- Enter your Git username/name:"
    read -r username
    while [[ -z "$username" ]]; do
        echo "-- Username/name cannot be empty. Try again:"
        read -r username
    done

    while true; do
        echo "-- Enter your email address:"
        read -r user_email
        if validate_email "$user_email"; then
            break
        fi
        echo "-- Invalid email address format. Please try again."
    done
}

# --- editor -------------------------------------------------------------------

config_editor() {
    if command_exists nvim; then
        git config --global core.editor "nvim"
        say "-- Git editor configured as Neovim."
    elif command_exists nano; then
        git config --global core.editor "nano"
        say "-- Git editor configured as nano."
    fi
}

# --- GitHub CLI ----------------------------------------------------------------

install_gh() {
    if command_exists gh; then
        say "-- GitHub CLI (gh) is already installed."
        return 0
    fi

    say "-- Installing GitHub CLI from the Arch repositories..."
    sudo pacman -S --needed --noconfirm github-cli \
        || abort "Could not install GitHub CLI."
}

config_gh() {
    install_gh
    say "-- Starting GitHub CLI authentication..."
    gh auth login
}

# --- SSH ----------------------------------------------------------------------

generate_an_ssh_key() {
    local ssh_key="${HOME}/.ssh/id_ed25519"

    say "---------------------------------------"
    say "-- Generating an SSH key for GitHub ..."
    say "---------------------------------------"

    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    if [[ -f "${ssh_key}" ]]; then
        say "-- ${ssh_key} already exists; leaving it unchanged."
    else
        ssh-keygen -t ed25519 -C "$user_email" -f "$ssh_key" \
            || abort "SSH key generation failed."
    fi

    # Use an existing agent when possible; otherwise start one for this shell.
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        eval "$(ssh-agent -s)" >/dev/null
    fi

    ssh-add "$ssh_key" || abort "Could not add SSH key to ssh-agent."
    say "-- SSH key is ready."
}

restore_ssh_key() {
    local int_storage="$HOME/Downloads"
    local key_name=""
    local source_dir=""

    say "--------------------"
    say "-- Restoring SSH key"
    say "--------------------"

    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    if [[ -f "$HOME/id_ed25519" && -f "$HOME/id_ed25519.pub" ]]; then
        key_name="id_ed25519"
        source_dir="$HOME"
    elif [[ -f "$int_storage/id_ed25519" && -f "$int_storage/id_ed25519.pub" ]]; then
        key_name="id_ed25519"
        source_dir="$int_storage"
    elif [[ -f "$HOME/id_rsa" && -f "$HOME/id_rsa.pub" ]]; then
        key_name="id_rsa"
        source_dir="$HOME"
    elif [[ -f "$int_storage/id_rsa" && -f "$int_storage/id_rsa.pub" ]]; then
        key_name="id_rsa"
        source_dir="$int_storage"
    else
        abort "No SSH key backup found in $HOME or $int_storage."
    fi

    if [[ "$source_dir" != "$HOME" ]]; then
        cp -f "$source_dir/$key_name" "$source_dir/$key_name.pub" "$HOME/"
    fi

    mv -f "$HOME/$key_name" "$HOME/$key_name.pub" "$HOME/.ssh/"
    chmod 600 "$HOME/.ssh/$key_name"
    chmod 644 "$HOME/.ssh/$key_name.pub"

    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        eval "$(ssh-agent -s)" >/dev/null
    fi
    ssh-add "$HOME/.ssh/$key_name" || abort "Could not add restored SSH key to ssh-agent."

    say "-- SSH key restored: $HOME/.ssh/$key_name"
}

backup_ssh_key() {
    local key_name=""

    say "------------------------"
    say "-- Backing up SSH key..."
    say "------------------------"

    if [[ -f "$HOME/.ssh/id_ed25519" && -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        key_name="id_ed25519"
    elif [[ -f "$HOME/.ssh/id_rsa" && -f "$HOME/.ssh/id_rsa.pub" ]]; then
        key_name="id_rsa"
    else
        abort "No supported SSH key found in $HOME/.ssh."
    fi

    cp -f "$HOME/.ssh/$key_name" "$HOME/.ssh/$key_name.pub" "$HOME/" \
        || abort "Could not back up the SSH key."
    chmod 600 "$HOME/$key_name"
    chmod 644 "$HOME/$key_name.pub"

    say "-- SSH backup completed in $HOME."
    say "-- WARNING: $key_name is a private key. Do not upload it to a public repository."
}

show_ssh_public_key() {
    local key="${HOME}/.ssh/id_ed25519.pub"

    if [[ ! -f "$key" ]]; then
        key="${HOME}/.ssh/id_rsa.pub"
    fi

    [[ -f "$key" ]] || abort "No SSH public key found."

    say "------------------------------------------"
    say "-- Your SSH public key is displayed below:"
    say "------------------------------------------"
    cat "$key"
}

# --- GPG ----------------------------------------------------------------------

generate_a_gpg_key() {
    local gpg_key_id=""

    say "--------------------------------------"
    say "-- Generating a GPG key for GitHub ..."
    say "--------------------------------------"

    gpg --full-generate-key || abort "GPG key generation failed."
    gpg --list-secret-keys --keyid-format=long

    echo "-- Enter GPG key ID:"
    read -r gpg_key_id
    [[ -n "$gpg_key_id" ]] || abort "GPG key ID cannot be empty."

    mkdir -p "${HOME}/.gnupg"
    chmod 700 "${HOME}/.gnupg"
    gpg --armor --export "$gpg_key_id" >"${HOME}/.gnupg/id_gpg" \
        || abort "Could not export the GPG public key."

    git config --global commit.gpgsign true
    git config --global user.signingkey "$gpg_key_id"
    say "-- GPG key has been generated and Git signing is enabled."
}

config_git_for_gpg_key() {
    say "---------------------------------------"
    say "-- Configuring Git for your GPG key ..."
    say "---------------------------------------"

    git config --global user.email "$user_email"
    git config --global user.name "$username"
    git config --global commit.gpgsign true

    setup_shell_environment
    say "-- Git and GPG configuration completed."
}

show_gpg_public_key() {
    local key_file="${HOME}/.gnupg/id_gpg"

    if [[ -f "$key_file" ]]; then
        say "------------------------------------------"
        say "-- Your GPG public key is displayed below:"
        say "------------------------------------------"
        cat "$key_file"
        rm -f "$key_file"
    else
        say "-- Exporting the selected GPG public key..."
        gpg --armor --export "$gpg_key_id"
    fi
}

backup_gpg_key() {
    say "------------------------"
    say "-- Backing up GPG key..."
    say "------------------------"

    gpg --export --export-options backup --output "$HOME/id_gpg_public" "$user_email" \
        || abort "Could not export the GPG public key."
    gpg --export-secret-keys --export-options backup --output "$HOME/id_gpg_private" \
        || abort "Could not export the GPG private key."
    gpg --export-ownertrust >"$HOME/gpg_ownertrust" \
        || abort "Could not export GPG ownertrust."

    chmod 600 "$HOME/id_gpg_public" "$HOME/id_gpg_private" "$HOME/gpg_ownertrust"
    say "-- GPG backup completed in $HOME."
    say "-- WARNING: id_gpg_private contains your private key. Store it securely."
}

restore_gpg_key() {
    local int_storage="$HOME/Downloads"
    local gpg_key_id=""

    say "--------------------"
    say "-- Restoring GPG key"
    say "--------------------"

    mkdir -p "${HOME}/.gnupg"
    chmod 700 "${HOME}/.gnupg"

    if [[ -f "$HOME/id_gpg_public" && -f "$HOME/id_gpg_private" && -f "$HOME/gpg_ownertrust" ]]; then
        say "-- GPG backup files found in $HOME."
    elif [[ -f "$int_storage/id_gpg_public" && -f "$int_storage/id_gpg_private" && -f "$int_storage/gpg_ownertrust" ]]; then
        cp -f "$int_storage/id_gpg_public" "$int_storage/id_gpg_private" "$int_storage/gpg_ownertrust" "$HOME/"
        chmod 600 "$HOME/id_gpg_public" "$HOME/id_gpg_private" "$HOME/gpg_ownertrust"
        say "-- GPG backup files copied from $int_storage."
    else
        abort "No complete GPG backup found in $HOME or $int_storage."
    fi

    gpg --import "$HOME/id_gpg_public" || abort "Could not import the GPG public key."
    gpg --import "$HOME/id_gpg_private" || abort "Could not import the GPG private key."
    gpg --import-ownertrust "$HOME/gpg_ownertrust" || abort "Could not restore GPG ownertrust."

    gpg --list-secret-keys --keyid-format=long
    echo "-- Enter GPG key ID:"
    read -r gpg_key_id
    [[ -n "$gpg_key_id" ]] || abort "GPG key ID cannot be empty."

    git config --global commit.gpgsign true
    git config --global user.signingkey "$gpg_key_id"

    rm -f "$HOME/id_gpg_public" "$HOME/id_gpg_private" "$HOME/gpg_ownertrust"
    say "-- GPG key restored and configured for Git signing."
}

# --- GitHub repository restore ------------------------------------------------

clone_github_repo() {
    local github_repo_name=""
    local github_username=""
    local repo_url=""
    local repo_dir=""

    echo "-- GitHub Username?"
    read -r github_username
    echo "-- GitHub Repository Name?"
    read -r github_repo_name

    [[ -n "$github_username" && -n "$github_repo_name" ]] \
        || abort "GitHub username and repository name are required."

    repo_url="https://github.com/${github_username}/${github_repo_name}.git"
    repo_dir="${HOME}/${github_repo_name}"

    rm -rf "$repo_dir"
    git clone "$repo_url" "$repo_dir" \
        || abort "Could not clone $repo_url"

    local found_gpg=0
    local found_ssh=0

    if [[ -f "$repo_dir/id_gpg_public" && -f "$repo_dir/id_gpg_private" && -f "$repo_dir/gpg_ownertrust" ]]; then
        cp -f "$repo_dir/id_gpg_public" "$repo_dir/id_gpg_private" "$repo_dir/gpg_ownertrust" "$HOME/"
        chmod 600 "$HOME/id_gpg_public" "$HOME/id_gpg_private" "$HOME/gpg_ownertrust"
        found_gpg=1
    fi

    if [[ -f "$repo_dir/id_ed25519" && -f "$repo_dir/id_ed25519.pub" ]]; then
        cp -f "$repo_dir/id_ed25519" "$repo_dir/id_ed25519.pub" "$HOME/"
        chmod 600 "$HOME/id_ed25519"
        chmod 644 "$HOME/id_ed25519.pub"
        found_ssh=1
    elif [[ -f "$repo_dir/id_rsa" && -f "$repo_dir/id_rsa.pub" ]]; then
        cp -f "$repo_dir/id_rsa" "$repo_dir/id_rsa.pub" "$HOME/"
        chmod 600 "$HOME/id_rsa"
        chmod 644 "$HOME/id_rsa.pub"
        found_ssh=1
    fi

    rm -rf "$repo_dir"

    (( found_gpg )) && say "-- GPG backup copied to $HOME."
    (( found_ssh )) && say "-- SSH backup copied to $HOME."

    if (( !found_gpg && !found_ssh )); then
        abort "Repository cloned, but no supported SSH/GPG backup files were found."
    fi

    say "-- Repository restore staging completed."
    say "-- Run rssh and/or rgpg from the menu to install the restored keys."
}

# --- main ---------------------------------------------------------------------

WorkNow() {
    local answer=""

    say "$0, v$SCRIPT_VERSION"
    require_omarchy
    check_inputs

    echo "-- What do you want to do today?"
    echo "-- Setup Omarchy Environment (s)."
    echo "-- Setup Omarchy Environment + Configure SSH and GPG Keys (ssg)."
    echo "-- Restore from GitHub (rgit)."
    echo "-- Restore SSH Key (rssh)."
    echo "-- Restore GPG Key (rgpg)."
    echo "-- Backup SSH Key (bssh)."
    echo "-- Backup GPG Key (bgpg)."
    read -r answer

    case "$answer" in
        bssh)
            backup_ssh_key
            ;;
        bgpg)
            backup_gpg_key
            ;;
        rgit)
            clone_github_repo
            ;;
        rssh)
            restore_ssh_key
            ;;
        rgpg)
            restore_gpg_key
            config_git_for_gpg_key
            config_editor
            install_gh
            config_gh
            ;;
        s)
            change_settings
            setup_storage
            update_environment
            install_packages
            setup_shell_environment
            config_editor
            ;;
        ssg)
            change_settings
            setup_storage
            update_environment
            install_packages
            setup_shell_environment
            config_gh
            generate_an_ssh_key
            generate_a_gpg_key
            config_git_for_gpg_key
            config_editor
            show_ssh_public_key
            show_gpg_public_key
            say "-- Copy the displayed public keys to GitHub."
            ;;
        *)
            say "-- No valid action selected."
            exit 0
            ;;
    esac
}

WorkNow
