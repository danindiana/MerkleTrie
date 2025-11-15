#!/usr/bin/env bash
#
# Bare Metal Setup Script for MerkleTrie
# Prepares a fresh system for MerkleTrie deployment
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MIN_OTP_VERSION=25
REBAR3_VERSION=3.23.0
REBAR3_URL="https://s3.amazonaws.com/rebar3/rebar3"

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root. This is not recommended for development."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$(echo $DISTRIB_ID | tr '[:upper:]' '[:lower:]')
        VER=$DISTRIB_RELEASE
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        VER=$(uname -r)
    fi

    log_info "Detected OS: $OS $VER"
}

install_erlang_ubuntu() {
    log_info "Installing Erlang/OTP on Ubuntu/Debian..."

    sudo apt-get update
    sudo apt-get install -y wget gnupg2 software-properties-common

    # Add Erlang Solutions repository
    wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
    sudo dpkg -i erlang-solutions_2.0_all.deb
    rm erlang-solutions_2.0_all.deb

    sudo apt-get update
    sudo apt-get install -y \
        erlang \
        erlang-dev \
        erlang-parsetools \
        erlang-dialyzer \
        erlang-crypto \
        erlang-ssl \
        build-essential \
        git \
        curl \
        vim

    log_success "Erlang/OTP installed successfully"
}

install_erlang_fedora() {
    log_info "Installing Erlang/OTP on Fedora/RHEL/CentOS..."

    sudo dnf install -y \
        erlang \
        erlang-crypto \
        erlang-ssl \
        erlang-parsetools \
        erlang-dialyzer \
        gcc \
        gcc-c++ \
        make \
        git \
        curl \
        vim

    log_success "Erlang/OTP installed successfully"
}

install_erlang_arch() {
    log_info "Installing Erlang/OTP on Arch Linux..."

    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm \
        erlang \
        base-devel \
        git \
        curl \
        vim

    log_success "Erlang/OTP installed successfully"
}

install_erlang_macos() {
    log_info "Installing Erlang/OTP on macOS..."

    if ! command -v brew &> /dev/null; then
        log_error "Homebrew not found. Please install from https://brew.sh"
        exit 1
    fi

    brew update
    brew install erlang rebar3 git

    log_success "Erlang/OTP installed successfully"
}

install_erlang() {
    if command -v erl &> /dev/null; then
        local version=$(erl -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' -noshell)
        log_info "Erlang/OTP already installed: $version"

        if [ "${version}" -ge "$MIN_OTP_VERSION" ]; then
            log_success "Erlang/OTP version is sufficient"
            return 0
        else
            log_warn "Erlang/OTP version $version is below minimum required version $MIN_OTP_VERSION"
        fi
    fi

    case "$OS" in
        ubuntu|debian)
            install_erlang_ubuntu
            ;;
        fedora|rhel|centos|rocky|almalinux)
            install_erlang_fedora
            ;;
        arch|manjaro)
            install_erlang_arch
            ;;
        darwin)
            install_erlang_macos
            ;;
        *)
            log_error "Unsupported OS: $OS"
            log_info "Please install Erlang/OTP $MIN_OTP_VERSION+ manually"
            exit 1
            ;;
    esac
}

install_rebar3() {
    if command -v rebar3 &> /dev/null; then
        local version=$(rebar3 version | head -n1)
        log_info "Rebar3 already installed: $version"
        return 0
    fi

    if [ -x ./rebar3 ]; then
        log_info "Rebar3 found in current directory"
        return 0
    fi

    log_info "Downloading rebar3..."
    wget "$REBAR3_URL" -O rebar3
    chmod +x rebar3

    # Optionally install system-wide
    read -p "Install rebar3 system-wide? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo mv rebar3 /usr/local/bin/
        log_success "Rebar3 installed to /usr/local/bin/rebar3"
    else
        log_success "Rebar3 installed to ./rebar3"
    fi
}

setup_directories() {
    log_info "Setting up directories..."

    mkdir -p data
    mkdir -p logs
    mkdir -p tests/current

    log_success "Directories created"
}

fetch_dependencies() {
    log_info "Fetching project dependencies..."

    local REBAR3_CMD
    if command -v rebar3 &> /dev/null; then
        REBAR3_CMD=rebar3
    else
        REBAR3_CMD=./rebar3
    fi

    $REBAR3_CMD get-deps
    $REBAR3_CMD compile

    log_success "Dependencies fetched and compiled"
}

run_tests() {
    log_info "Running test suite..."

    local REBAR3_CMD
    if command -v rebar3 &> /dev/null; then
        REBAR3_CMD=rebar3
    else
        REBAR3_CMD=./rebar3
    fi

    $REBAR3_CMD eunit || log_warn "Some tests failed (this may be expected)"

    log_success "Test suite completed"
}

run_smoke_test() {
    if [ -f ./scripts/smoke-test.sh ]; then
        log_info "Running smoke tests..."
        chmod +x ./scripts/smoke-test.sh
        ./scripts/smoke-test.sh || log_warn "Some smoke tests failed"
    else
        log_warn "Smoke test script not found, skipping"
    fi
}

display_system_info() {
    echo ""
    echo "=========================================="
    echo "  System Information"
    echo "=========================================="
    echo ""

    if command -v erl &> /dev/null; then
        echo -e "${CYAN}Erlang/OTP:${NC}"
        echo "  Version: $(erl -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' -noshell)"
        echo "  ERTS: $(erl -eval 'io:format("~s", [erlang:system_info(version)]), halt().' -noshell)"
    fi

    if command -v rebar3 &> /dev/null; then
        echo ""
        echo -e "${CYAN}Rebar3:${NC}"
        rebar3 version | head -n1
    elif [ -x ./rebar3 ]; then
        echo ""
        echo -e "${CYAN}Rebar3:${NC}"
        ./rebar3 version | head -n1
    fi

    echo ""
    echo -e "${CYAN}System:${NC}"
    echo "  OS: $OS $VER"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"

    if command -v free &> /dev/null; then
        echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    fi

    echo "  CPUs: $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'unknown')"
    echo ""
}

setup_systemd_service() {
    log_info "Would you like to set up a systemd service? (requires root)"
    read -p "Setup systemd service? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    local SERVICE_FILE="/tmp/merkletrie.service"
    local INSTALL_PATH=$(pwd)
    local USER=$(whoami)

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=MerkleTrie Database Service
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$INSTALL_PATH
Environment="HOME=/home/$USER"
ExecStart=$INSTALL_PATH/_build/prod/rel/trie/bin/trie start
ExecStop=$INSTALL_PATH/_build/prod/rel/trie/bin/trie stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo mv "$SERVICE_FILE" /etc/systemd/system/merkletrie.service
    sudo systemctl daemon-reload

    log_success "Systemd service created: /etc/systemd/system/merkletrie.service"
    log_info "Enable with: sudo systemctl enable merkletrie"
    log_info "Start with: sudo systemctl start merkletrie"
}

main() {
    echo ""
    echo "=========================================="
    echo "  MerkleTrie Bare Metal Setup"
    echo "=========================================="
    echo ""

    check_root
    detect_os
    install_erlang
    install_rebar3
    setup_directories
    fetch_dependencies
    run_tests
    run_smoke_test
    display_system_info

    echo ""
    echo "=========================================="
    log_success "Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Run 'make shell' to start interactive development"
    echo "  2. Run 'make test' to run the full test suite"
    echo "  3. Run 'make release' to build a production release"
    echo "  4. Check the Makefile for more commands: 'make help'"
    echo ""

    setup_systemd_service

    log_info "MerkleTrie is ready to use!"
}

# Run main function
main "$@"
