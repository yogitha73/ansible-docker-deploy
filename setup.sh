#!/bin/bash

# Automated Apache Container Deployment - Setup Script
# This script prepares the environment for running the Ansible playbook

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Script configuration
SCRIPT_NAME="setup.sh"
SCRIPT_VERSION="1.0"
LOG_FILE="setup.log"
REQUIRED_PYTHON_VERSION="3.6"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING" "$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR" "$1"
}

# Banner function
print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║               APACHE CONTAINER DEPLOYMENT                   ║
║                     SETUP SCRIPT                            ║
╠══════════════════════════════════════════════════════════════╣
║ This script will prepare your environment for automated     ║
║ Apache container deployment using Ansible and Docker.       ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Some operations will be performed with sudo privileges."
        return 0
    else
        print_info "Running as non-root user: $(whoami)"
        return 1
    fi
}

# Check operating system
check_os() {
    print_info "Checking operating system compatibility..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_success "Linux operating system detected"
        
        # Check specific distribution
        if command -v lsb_release &> /dev/null; then
            local distro=$(lsb_release -si)
            local version=$(lsb_release -sr)
            print_info "Distribution: ${distro} ${version}"
        elif [[ -f /etc/os-release ]]; then
            local distro=$(grep '^NAME=' /etc/os-release | cut -d'"' -f2)
            print_info "Distribution: ${distro}"
        fi
        
        return 0
    else
        print_error "Unsupported operating system: $OSTYPE"
        print_error "This script requires a Linux-based operating system"
        return 1
    fi
}

# Check Python version
check_python() {
    print_info "Checking Python installation..."
    
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version | cut -d' ' -f2)
        print_success "Python 3 found: version ${python_version}"
        
        # Check if version meets requirements
        local major_version=$(echo $python_version | cut -d'.' -f1)
        local minor_version=$(echo $python_version | cut -d'.' -f2)
        
        if [[ $major_version -eq 3 ]] && [[ $minor_version -ge 6 ]]; then
            print_success "Python version meets requirements (>= ${REQUIRED_PYTHON_VERSION})"
            return 0
        else
            print_error "Python version ${python_version} is too old. Required: >= ${REQUIRED_PYTHON_VERSION}"
            return 1
        fi
    else
        print_error "Python 3 not found. Please install Python 3.6 or higher."
        return 1
    fi
}

# Check pip installation
check_pip() {
    print_info "Checking pip installation..."
    
    if command -v pip3 &> /dev/null; then
        local pip_version=$(pip3 --version | cut -d' ' -f2)
        print_success "pip3 found: version ${pip_version}"
        return 0
    elif command -v pip &> /dev/null; then
        local pip_version=$(pip --version | cut -d' ' -f2)
        print_success "pip found: version ${pip_version}"
        return 0
    else
        print_warning "pip not found. Attempting to install..."
        install_pip
        return $?
    fi
}

# Install pip
install_pip() {
    print_info "Installing pip..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y python3-pip
    elif command -v yum &> /dev/null; then
        sudo yum install -y python3-pip
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3-pip
    else
        print_error "Package manager not supported. Please install pip manually."
        return 1
    fi
    
    if command -v pip3 &> /dev/null; then
        print_success "pip3 installed successfully"
        return 0
    else
        print_error "Failed to install pip3"
        return 1
    fi
}

# Upgrade pip
upgrade_pip() {
    print_info "Upgrading pip to latest version..."
    
    if python3 -m pip install --upgrade pip; then
        print_success "pip upgraded successfully"
        return 0
    else
        print_error "Failed to upgrade pip"
        return 1
    fi
}

# Install Ansible
install_ansible() {
    print_info "Installing Ansible..."
    
    if pip3 install ansible; then
        print_success "Ansible installed successfully"
        
        # Verify installation
        if command -v ansible &> /dev/null; then
            local ansible_version=$(ansible --version | head -n1 | cut -d' ' -f2)
            print_success "Ansible version: ${ansible_version}"
            return 0
        else
            print_error "Ansible installation verification failed"
            return 1
        fi
    else
        print_error "Failed to install Ansible"
        return 1
    fi
}

# Install Docker SDK for Python
install_docker_sdk() {
    print_info "Installing Docker SDK for Python..."
    
    if pip3 install docker; then
        print_success "Docker SDK for Python installed successfully"
        
        # Test import
        if python3 -c "import docker; print('Docker SDK import successful')"; then
            print_success "Docker SDK import test passed"
            return 0
        else
            print_error "Docker SDK import test failed"
            return 1
        fi
    else
        print_error "Failed to install Docker SDK for Python"
        return 1
    fi
}

# Check Docker installation
check_docker() {
    print_info "Checking Docker installation..."
    
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | sed 's/,//')
        print_success "Docker found: version ${docker_version}"
        
        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            print_success "Docker daemon is running"
            
            # Check if user can run Docker without sudo
            if docker ps &> /dev/null; then
                print_success "Docker access configured correctly"
                return 0
            else
                print_warning "Docker requires sudo access. User may need to be added to docker group."
                print_info "Run: sudo usermod -aG docker \$USER && newgrp docker"
                return 1
            fi
        else
            print_error "Docker daemon is not running"
            print_info "Start Docker with: sudo systemctl start docker"
            return 1
        fi
    else
        print_error "Docker not found. Please install Docker first."
        print_info "Install Docker with: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
        return 1
    fi
}

# Install Ansible collections
install_ansible_collections() {
    print_info "Installing required Ansible collections..."
    
    # Install community.docker collection
    if ansible-galaxy collection install community.docker; then
        print_success "community.docker collection installed"
        return 0
    else
        print_error "Failed to install community.docker collection"
        return 1
    fi
}

# Verify project files
verify_project_files() {
    print_info "Verifying project files..."
    
    local required_files=(
        "docker_deploy.yml"
        "index.html"
        "ansible.cfg"
        "inventory.ini"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_success "All required project files found"
        return 0
    else
        print_error "Missing ${#missing_files[@]} required files"
        return 1
    fi
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    
    local directories=(
        "logs"
        "backups"
        "tmp"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if mkdir -p "$dir"; then
                print_success "Created directory: $dir"
            else
                print_error "Failed to create directory: $dir"
                return 1
            fi
        else
            print_info "Directory already exists: $dir"
        fi
    done
    
    return 0
}

# Set file permissions
set_permissions() {
    print_info "Setting appropriate file permissions..."
    
    # Set script permissions
    chmod +x scripts/*.sh 2>/dev/null || true
    
    # Set playbook permissions
    chmod 644 *.yml 2>/dev/null || true
    chmod 644 *.yaml 2>/dev/null || true
    
    # Set configuration permissions
    chmod 644 *.cfg 2>/dev/null || true
    chmod 644 *.ini 2>/dev/null || true
    
    print_success "File permissions set"
    return 0
}

# Generate summary report
generate_summary() {
    print_info "Generating setup summary..."
    
    local summary_file="setup_summary.txt"
    
    cat > "$summary_file" << EOF
# Apache Container Deployment - Setup Summary
Generated: $(date)
Hostname: $(hostname)
User: $(whoami)
Working Directory: $(pwd)

## System Information
$(uname -a)

## Python Environment
$(python3 --version 2>/dev/null || echo "Python 3: Not available")
$(pip3 --version 2>/dev/null || echo "pip3: Not available")

## Ansible Information
$(ansible --version 2>/dev/null | head -n1 || echo "Ansible: Not available")

## Docker Information
$(docker --version 2>/dev/null || echo "Docker: Not available")
$(docker info --format "{{.ServerVersion}}" 2>/dev/null || echo "Docker Daemon: Not running")

## Project Files Status
EOF
    
    local required_files=(
        "docker_deploy.yml"
        "index.html"
        "ansible.cfg"
        "inventory.ini"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "✓ $file: Present" >> "$summary_file"
        else
            echo "✗ $file: Missing" >> "$summary_file"
        fi
    done
    
    print_success "Setup summary saved to: $summary_file"
    return 0
}

# Main setup function
main() {
    print_banner
    
    print_info "Starting setup process..."
    print_info "Script: ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    print_info "Log file: ${LOG_FILE}"
    
    # Initialize log file
    echo "# Apache Container Deployment Setup Log" > "$LOG_FILE"
    echo "# Started: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    local exit_code=0
    
    # Run setup checks and installations
    check_os || exit_code=1
    check_python || exit_code=1
    check_pip || exit_code=1
    
    if [[ $exit_code -eq 0 ]]; then
        upgrade_pip || print_warning "Failed to upgrade pip"
        install_ansible || exit_code=1
        install_docker_sdk || exit_code=1
        install_ansible_collections || exit_code=1
    fi
    
    check_docker || print_warning "Docker issues detected - deployment may fail"
    verify_project_files || exit_code=1
    create_directories || exit_code=1
    set_permissions || print_warning "Failed to set some permissions"
    generate_summary || print_warning "Failed to generate summary"
    
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_success "Setup completed successfully!"
        print_info "You can now run the deployment with:"
        print_info "  ansible-playbook -i inventory.ini docker_deploy.yml"
    else
        print_error "Setup completed with errors. Please review the log file: ${LOG_FILE}"
        print_info "Fix the issues above before running the deployment."
    fi
    
    echo ""
    print_info "Setup log saved to: ${LOG_FILE}"
    print_info "Setup complete: $(date)"
    
    exit $exit_code
}

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Apache Container Deployment Setup

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -v, --version   Show version information
    --check-only    Run checks without installing anything

DESCRIPTION:
    This script prepares your environment for the Apache container deployment
    project by installing required dependencies and verifying system compatibility.

REQUIREMENTS:
    - Linux operating system
    - Python 3.6 or higher
    - Internet connectivity
    - sudo privileges (for package installation)

EXAMPLES:
    $0                    # Run full setup
    $0 --check-only       # Check requirements only
    $0 --help            # Show this help

EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        echo "$SCRIPT_NAME v$SCRIPT_VERSION"
        exit 0
        ;;
    --check-only)
        print_banner
        print_info "Running checks only (no installations)..."
        check_os
        check_python
        check_pip
        check_docker
        verify_project_files
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        print_info "Use --help for usage information"
        exit 1
        ;;
esac
