#!/bin/zsh
# Script to run molecule tests for the SSH Ansible role

# Function to display usage
function show_usage() {
    echo "Usage: $0 [DISTRO]"
    echo
    echo "Run molecule tests for the SSH Ansible role"
    echo
    echo "Arguments:"
    echo "  DISTRO    Distribution to test with (default: debian11)"
    echo "            Supported: debian11, debian12, ubuntu2004, ubuntu2404"
    echo
    echo "Examples:"
    echo "  $0              # Test with Debian 11"
    echo "  $0 ubuntu2004   # Test with Ubuntu 20.04"
    echo
}

# Show help if requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Exit on any error
set -e

# Define colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Virtual environment path
VENV_PATH=".venv"

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Docker is required for molecule tests.${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker is not running. Please start Docker daemon.${NC}"
    exit 1
fi

# Check if molecule is installed in the virtual environment
if [ ! -f "${VENV_PATH}/bin/molecule" ]; then
    echo -e "${YELLOW}Molecule virtual environment not found or not set up correctly.${NC}"
    echo -e "Creating Python virtual environment and installing dependencies..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "${VENV_PATH}" ]; then
        python3 -m venv "${VENV_PATH}"
    fi
    
    # Install dependencies
    "${VENV_PATH}/bin/pip" install molecule molecule-docker pytest-testinfra ansible ansible-lint
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install molecule and dependencies.${NC}"
        exit 1
    fi

    # Install required Ansible collections
    echo -e "${YELLOW}Installing required Ansible collections...${NC}"
    source "${VENV_PATH}/bin/activate" && ansible-galaxy collection install -r requirements.yml
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install Ansible collections.${NC}"
        exit 1
    fi
fi

# Display test information
echo -e "${GREEN}=== SSH Role Test ===${NC}"
echo "Python virtual environment: ${VENV_PATH}"

# Pull Docker image in advance to avoid timeout issues
echo -e "${YELLOW}Pulling Docker image...${NC}"
docker pull geerlingguy/docker-${1:-debian11}-ansible:latest

# Set up environment variables
export MOLECULE_DISTRO=${1:-debian11}
export MOLECULE_NO_LOG=false
export MOLECULE_ROLE_NAME_CHECK=0

echo -e "${YELLOW}Running molecule test with ${MOLECULE_DISTRO}...${NC}"

# Run the test in the virtual environment with direct command execution
source "${VENV_PATH}/bin/activate" && molecule test

# Check for success
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Tests completed successfully!${NC}"
else
    echo -e "${RED}Tests failed.${NC}"
    exit 1
fi
