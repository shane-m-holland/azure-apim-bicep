#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Azure API Management CLI - Unified Entry Point
# Description: Single interface for all APIM operations including infrastructure 
#              deployment, API management, validation, and environment setup.
# Usage: ./apim.sh <command> <environment> [options...]
# Example: ./apim.sh deploy apis dev --parallel
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Source configuration utilities
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib/config-utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"

# ──────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ──────────────────────────────────────────────────────────────────────────────

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}❌ ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
}

# ──────────────────────────────────────────────────────────────────────────────
# Usage and Help Functions
# ──────────────────────────────────────────────────────────────────────────────

show_version() {
    echo "Azure APIM CLI v$VERSION"
    echo "Unified interface for Azure API Management operations"
}

show_help() {
    cat << 'EOF'
Azure API Management CLI - Unified Entry Point

USAGE:
    apim <command> <environment> [options...]

COMMANDS:
    setup                         Interactive environment setup
    validate                      Validate configurations and prerequisites
    
    deploy infrastructure         Deploy APIM infrastructure
    deploy apis                   Deploy APIs to APIM instance
    
    sync                         Intelligent API synchronization (only changed APIs)
    
    destroy infrastructure        Destroy APIM infrastructure
    destroy apis                  Delete APIs from APIM instance
    
    help                         Show this help message
    version                      Show version information

GLOBAL OPTIONS:
    --help, -h                   Show help for any command
    --version, -v                Show version information
    --verbose                    Enable verbose output
    --dry-run                    Preview actions without making changes

EXAMPLES:
    # Environment setup
    apim setup dev
    
    # Validation
    apim validate dev
    apim validate dev ./my-config.yaml
    
    # Infrastructure deployment
    apim deploy infrastructure dev
    apim deploy infrastructure prod --dry-run
    
    # API deployment
    apim deploy apis dev
    apim deploy apis prod ./my-apis.yaml --parallel
    
    # API synchronization (smart deployment)
    apim sync dev
    apim sync prod --force-all
    
    # Cleanup operations
    apim destroy apis dev --dry-run
    apim destroy infrastructure dev --force

CONFIGURATION:
    The CLI supports both JSON and YAML configuration files:
    - JSON: api-config.json, environments/*/config.env
    - YAML: api-config.yaml (with comments and better readability)
    
    Configuration files are auto-discovered (YAML preferred, JSON fallback).

ENVIRONMENT MANAGEMENT:
    Environments are managed in the environments/ directory using any valid name:
    - environments/dev/     - Development configuration
    - environments/staging/ - Staging configuration  
    - environments/prod/    - Production configuration
    - environments/test/    - Test configuration
    - environments/uat/     - User acceptance testing
    - environments/demo/    - Demo configuration
    
    Environment names must contain only letters, numbers, hyphens, and underscores.

For detailed help on any command, use:
    apim <command> --help

EOF
}

show_command_help() {
    local command="$1"
    local subcommand="${2:-}"
    
    case "$command" in
        "setup")
            echo "apim setup [environment]"
            echo ""
            echo "Interactive setup for new environments"
            echo ""
            echo "Arguments:"
            echo "  environment    Environment name (any valid name) - optional"
            echo ""
            echo "Examples:"
            echo "  apim setup dev"
            echo "  apim setup test"
            echo "  apim setup demo"
            echo "  apim setup"
            ;;
        "validate")
            echo "apim validate [environment] [config-file]"
            echo ""
            echo "Comprehensive validation of configurations, API specs, and prerequisites"
            echo ""
            echo "Arguments:"
            echo "  environment    Environment to validate (optional, validates all if omitted)"
            echo "  config-file    API configuration file (JSON/YAML, auto-discovered if omitted)"
            echo ""
            echo "Examples:"
            echo "  apim validate"
            echo "  apim validate dev"
            echo "  apim validate uat ./my-apis.yaml"
            echo "  apim validate test"
            ;;
        "deploy")
            case "$subcommand" in
                "infrastructure")
                    echo "apim deploy infrastructure <environment> [--dry-run]"
                    echo ""
                    echo "Deploy APIM infrastructure using Bicep templates"
                    echo ""
                    echo "Arguments:"
                    echo "  environment    Target environment (any valid name)"
                    echo ""
                    echo "Options:"
                    echo "  --dry-run      Validate deployment without creating resources"
                    echo ""
                    echo "Examples:"
                    echo "  apim deploy infrastructure dev"
                    echo "  apim deploy infrastructure test --dry-run"
                    echo "  apim deploy infrastructure uat"
                    ;;
                "apis")
                    echo "apim deploy apis <environment> [config-file] [--dry-run] [--parallel] [--verbose]"
                    echo ""
                    echo "Deploy APIs to APIM instance"
                    echo ""
                    echo "Arguments:"
                    echo "  environment    Target environment (any valid name)"
                    echo "  config-file    API configuration file (JSON/YAML, auto-discovered if omitted)"
                    echo ""
                    echo "Options:"
                    echo "  --dry-run      Validate configuration without deploying"
                    echo "  --parallel     Deploy APIs in parallel for faster execution"
                    echo "  --verbose      Show detailed deployment output"
                    echo ""
                    echo "Examples:"
                    echo "  apim deploy apis dev"
                    echo "  apim deploy apis demo ./my-apis.yaml --parallel"
                    echo "  apim deploy apis local --verbose"
                    ;;
                *)
                    echo "apim deploy <target> <environment> [options...]"
                    echo ""
                    echo "Deploy infrastructure or APIs"
                    echo ""
                    echo "Targets:"
                    echo "  infrastructure    Deploy APIM infrastructure"
                    echo "  apis             Deploy APIs to existing APIM instance"
                    echo ""
                    echo "Use 'apim deploy <target> --help' for target-specific help"
                    ;;
            esac
            ;;
        "sync")
            echo "apim sync <environment> [config-file] [--force-all] [--debug]"
            echo ""
            echo "Intelligent API synchronization - only deploys changed APIs"
            echo ""
            echo "Arguments:"
            echo "  environment    Target environment (any valid name)"
            echo "  config-file    API configuration file (JSON/YAML, auto-discovered if omitted)"
            echo ""
            echo "Options:"
            echo "  --force-all    Deploy all APIs regardless of changes"
            echo "  --debug        Enable debug mode with verbose output"
            echo ""
            echo "Examples:"
            echo "  apim sync dev"
            echo "  apim sync uat ./my-apis.yaml --force-all"
            echo "  apim sync test --debug"
            ;;
        "destroy")
            case "$subcommand" in
                "infrastructure")
                    echo "apim destroy infrastructure <environment> [--force] [--keep-rg] [--purge]"
                    echo ""
                    echo "Destroy APIM infrastructure"
                    echo ""
                    echo "Arguments:"
                    echo "  environment    Target environment (any valid name)"
                    echo ""
                    echo "Options:"
                    echo "  --force        Skip confirmation prompts"
                    echo "  --keep-rg      Keep the resource group after destroying resources"
                    echo "  --purge        Purge soft-deleted APIM instance (enables redeployment)"
                    echo ""
                    echo "Examples:"
                    echo "  apim destroy infrastructure dev"
                    echo "  apim destroy infrastructure test --purge"
                    echo "  apim destroy infrastructure demo --force"
                    ;;
                "apis")
                    echo "apim destroy apis <environment> [config-file] [--dry-run] [--force] [--verbose]"
                    echo ""
                    echo "Delete APIs from APIM instance"
                    echo ""
                    echo "Arguments:"
                    echo "  environment    Target environment (any valid name)"
                    echo "  config-file    API configuration file (JSON/YAML, auto-discovered if omitted)"
                    echo ""
                    echo "Options:"
                    echo "  --dry-run      Show what would be deleted without deleting"
                    echo "  --force        Skip confirmation prompts"
                    echo "  --verbose      Show detailed deletion progress"
                    echo ""
                    echo "Examples:"
                    echo "  apim destroy apis dev --dry-run"
                    echo "  apim destroy apis local --force"
                    echo "  apim destroy apis test --verbose"
                    ;;
                *)
                    echo "apim destroy <target> <environment> [options...]"
                    echo ""
                    echo "Destroy infrastructure or APIs"
                    echo ""
                    echo "Targets:"
                    echo "  infrastructure    Destroy APIM infrastructure"
                    echo "  apis             Delete APIs from APIM instance"
                    echo ""
                    echo "Use 'apim destroy <target> --help' for target-specific help"
                    ;;
            esac
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            echo "Use 'apim help' for available commands"
            exit 1
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Command Validation and Routing
# ──────────────────────────────────────────────────────────────────────────────

validate_environment() {
    local env="$1"
    
    # Check if environment name is empty
    if [[ -z "$env" ]]; then
        error "Environment name cannot be empty"
        exit 1
    fi
    
    # Validate environment name contains only safe characters
    # Allow alphanumeric characters, hyphens, and underscores (no spaces)
    if [[ ! "$env" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid environment name: $env"
        echo "Environment names must contain only letters, numbers, hyphens, and underscores (no spaces)"
        echo "Examples: dev, staging, prod, test, uat, demo, local, dev-v2, test_env"
        exit 1
    fi
    
    # Check if environment name is not too long (filesystem limits)
    if [[ ${#env} -gt 50 ]]; then
        error "Environment name too long: $env (maximum 50 characters)"
        exit 1
    fi
    
    # Environment is valid - the directory will be created if it doesn't exist
    return 0
}

check_script_exists() {
    local script_path="$1"
    local script_name="$2"
    
    if [[ ! -f "$script_path" ]]; then
        error "Required script not found: $script_name"
        error "Expected path: $script_path"
        exit 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        error "Script is not executable: $script_name"
        error "Run: chmod +x $script_path"
        exit 1
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Command Implementations
# ──────────────────────────────────────────────────────────────────────────────

cmd_setup() {
    local script_path="./scripts/setup-environment.sh"
    check_script_exists "$script_path" "setup-environment.sh"
    
    log "Running environment setup..."
    exec "$script_path" "$@"
}

cmd_validate() {
    local script_path="./scripts/validate-config.sh"
    check_script_exists "$script_path" "validate-config.sh"
    
    log "Running configuration validation..."
    exec "$script_path" "$@"
}

cmd_deploy_infrastructure() {
    local script_path="./scripts/deploy-infrastructure.sh"
    check_script_exists "$script_path" "deploy-infrastructure.sh"
    
    if [[ $# -lt 1 ]]; then
        error "Environment required for infrastructure deployment"
        show_command_help "deploy" "infrastructure"
        exit 1
    fi
    
    validate_environment "$1"
    log "Deploying infrastructure for environment: $1"
    exec "$script_path" "$@"
}

cmd_deploy_apis() {
    local script_path="./scripts/deploy-apis.sh"
    check_script_exists "$script_path" "deploy-apis.sh"
    
    if [[ $# -lt 1 ]]; then
        error "Environment required for API deployment"
        show_command_help "deploy" "apis"
        exit 1
    fi
    
    validate_environment "$1"
    log "Deploying APIs for environment: $1"
    exec "$script_path" "$@"
}

cmd_sync() {
    local script_path="./scripts/sync-apis.sh"
    check_script_exists "$script_path" "sync-apis.sh"
    
    if [[ $# -lt 1 ]]; then
        error "Environment required for API synchronization"
        show_command_help "sync"
        exit 1
    fi
    
    validate_environment "$1"
    log "Synchronizing APIs for environment: $1"
    exec "$script_path" "$@"
}

cmd_destroy_infrastructure() {
    local script_path="./scripts/destroy-infrastructure.sh"
    check_script_exists "$script_path" "destroy-infrastructure.sh"
    
    if [[ $# -lt 1 ]]; then
        error "Environment required for infrastructure destruction"
        show_command_help "destroy" "infrastructure"
        exit 1
    fi
    
    validate_environment "$1"
    warning "Destroying infrastructure for environment: $1"
    exec "$script_path" "$@"
}

cmd_destroy_apis() {
    local script_path="./scripts/destroy-apis.sh"
    check_script_exists "$script_path" "destroy-apis.sh"
    
    if [[ $# -lt 1 ]]; then
        error "Environment required for API destruction"
        show_command_help "destroy" "apis"
        exit 1
    fi
    
    validate_environment "$1"
    warning "Destroying APIs for environment: $1"
    exec "$script_path" "$@"
}

# ──────────────────────────────────────────────────────────────────────────────
# Main Command Processing
# ──────────────────────────────────────────────────────────────────────────────

main() {
    # Handle global options first
    case "${1:-}" in
        --version|-v)
            show_version
            exit 0
            ;;
        --help|-h|""|help)
            show_help
            exit 0
            ;;
    esac
    
    local command="$1"
    shift
    
    # Handle help for specific commands
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_command_help "$command" "${2:-}"
        exit 0
    fi
    
    # Route to appropriate command handler
    case "$command" in
        "setup")
            cmd_setup "$@"
            ;;
        "validate")
            cmd_validate "$@"
            ;;
        "deploy")
            local target="${1:-}"
            if [[ -z "$target" ]]; then
                error "Deploy target required (infrastructure or apis)"
                show_command_help "deploy"
                exit 1
            fi
            shift
            
            # Handle help for specific deploy targets
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_command_help "deploy" "$target"
                exit 0
            fi
            
            case "$target" in
                "infrastructure"|"infra")
                    cmd_deploy_infrastructure "$@"
                    ;;
                "apis"|"api")
                    cmd_deploy_apis "$@"
                    ;;
                *)
                    error "Invalid deploy target: $target"
                    show_command_help "deploy"
                    exit 1
                    ;;
            esac
            ;;
        "sync")
            cmd_sync "$@"
            ;;
        "destroy")
            local target="${1:-}"
            if [[ -z "$target" ]]; then
                error "Destroy target required (infrastructure or apis)"
                show_command_help "destroy"
                exit 1
            fi
            shift
            
            # Handle help for specific destroy targets
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_command_help "destroy" "$target"
                exit 0
            fi
            
            case "$target" in
                "infrastructure"|"infra")
                    cmd_destroy_infrastructure "$@"
                    ;;
                "apis"|"api")
                    cmd_destroy_apis "$@"
                    ;;
                *)
                    error "Invalid destroy target: $target"
                    show_command_help "destroy"
                    exit 1
                    ;;
            esac
            ;;
        "version")
            show_version
            exit 0
            ;;
        "help")
            if [[ $# -gt 0 ]]; then
                show_command_help "$1" "${2:-}"
            else
                show_help
            fi
            exit 0
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            echo "Available commands: setup, validate, deploy, sync, destroy, help, version"
            echo "Use 'apim help' for detailed usage information"
            exit 1
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Entry Point
# ──────────────────────────────────────────────────────────────────────────────

# Ensure we have at least one argument
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Run main command processing
main "$@"