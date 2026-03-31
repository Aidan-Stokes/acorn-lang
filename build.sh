#!/bin/bash

# Acorn Compiler Build Script
# Supports: Ubuntu/Debian, Arch Linux, Cachyos, and other Linux distributions
# Usage: ./build.sh [options]
#
# Options:
#   -h, --help    Show this help message
#   -r, --release Build release binary
#   -c, --clean   Clean build artifacts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default settings
BUILD_TYPE="debug"
CLEAN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Acorn Compiler Build Script"
            echo ""
            echo "Usage: ./build.sh [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo "  -r, --release Build release binary"
            echo "  -c, --clean   Clean build artifacts"
            echo ""
            echo "Requirements:"
            echo "  - Odin compiler (https://github.com/odin-lang/Odin)"
            echo "  - LLVM (llvm, llc, clang)"
            echo ""
            exit 0
            ;;
        -r|--release)
            BUILD_TYPE="release"
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Detect package manager and install dependencies
install_deps() {
    echo -e "${YELLOW}Checking dependencies...${NC}"

    # Check for Odin
    if ! command -v odin &> /dev/null; then
        echo -e "${YELLOW}Odin not found. Installing...${NC}"

        if command -v pacman &> /dev/null; then
            # Arch Linux / Cachyos / Manjaro
            echo "Detected: Arch Linux (pacman)"
            sudo pacman -S --noconfirm odin llvm clang
        elif command -v apt-get &> /dev/null; then
            # Debian / Ubuntu
            echo "Detected: Debian/Ubuntu (apt)"
            sudo apt-get update
            sudo apt-get install -y llvm clang

            # Install Odin if not in repos
            if ! command -v odin &> /dev/null; then
                echo "Installing Odin from GitHub..."
                wget -q https://github.com/odin-lang/Odin/releases/latest/download/odin-linux-amd64.zip
                unzip -q odin-linux-amd64.zip
                sudo mv odin /usr/local/bin/
                rm odin-linux-amd64.zip
            fi
        elif command -v dnf &> /dev/null; then
            # Fedora / RHEL
            echo "Detected: Fedora (dnf)"
            sudo dnf install -y llvm llvm-devel clang
            if ! command -v odin &> /dev/null; then
                wget -q https://github.com/odin-lang/Odin/releases/latest/download/odin-linux-amd64.zip
                unzip -q odin-linux-amd64.zip
                sudo mv odin /usr/local/bin/
                rm odin-linux-amd64.zip
            fi
        elif command -v zypper &> /dev/null; then
            # openSUSE
            echo "Detected: openSUSE (zypper)"
            sudo zypper install -y llvm-devel clang
            if ! command -v odin &> /dev/null; then
                wget -q https://github.com/odin-lang/Odin/releases/latest/download/odin-linux-amd64.zip
                unzip -q odin-linux-amd64.zip
                sudo mv odin /usr/local/bin/
                rm odin-linux-amd64.zip
            fi
        else
            echo -e "${RED}Unsupported distribution${NC}"
            echo "Please install Odin and LLVM manually:"
            echo "  1. Download Odin: https://github.com/odin-lang/Odin"
            echo "  2. Install LLVM: pacman -S llvm clang (Arch) or apt install llvm clang (Debian)"
            exit 1
        fi
    else
        echo -e "${GREEN}Odin found${NC}"
    fi

    # Check for LLVM
    if ! command -v llc &> /dev/null; then
        echo -e "${RED}LLVM (llc) not found${NC}"
        echo "Please install LLVM:"
        if command -v pacman &> /dev/null; then
            echo "  sudo pacman -S llvm clang"
        elif command -v apt-get &> /dev/null; then
            echo "  sudo apt-get install llvm clang"
        fi
        exit 1
    fi

    echo -e "${GREEN}All dependencies satisfied!${NC}"
}

# Find Odin
find_odin() {
    ODIN="${ODIN:-odin}"
    if ! command -v "$ODIN" &> /dev/null; then
        echo -e "${RED}Error: Odin compiler not found${NC}"
        echo "Please install Odin: https://github.com/odin-lang/Odin"
        exit 1
    fi
}

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    rm -f acorn acorn_generated.* *.o *.s *.ll
    rm -f /tmp/acorn_* 2>/dev/null || true
    echo -e "${GREEN}Clean complete!${NC}"
    exit 0
fi

# Install dependencies and find Odin
install_deps
find_odin

echo -e "${YELLOW}Building Acorn compiler...${NC}"
echo ""

# Build command (works across all platforms)
odin build . -build-mode:exe -file -out:acorn

# Verify build
if [ -f "./acorn" ]; then
    echo ""
    echo -e "${GREEN}Build successful!${NC}"
    echo ""
    ./acorn --version
    echo ""
    echo "To run: ./acorn <command> <file>"
    echo "To test: ./acorn build examples/00_hello_world.acorn -o hello && ./hello"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi
