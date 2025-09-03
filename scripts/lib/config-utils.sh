#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Configuration Utilities Library
# Description: Shared functions for handling both JSON and YAML configuration files
# Usage: source this file from other scripts to access configuration utilities
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# Configuration Format Detection
# ──────────────────────────────────────────────────────────────────────────────

detect_config_format() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "unknown"
        return 1
    fi
    
    case "$file_path" in
        *.yaml|*.yml)
            echo "yaml"
            ;;
        *.json)
            echo "json"
            ;;
        *)
            # Try to detect based on content if extension is ambiguous
            if head -n 5 "$file_path" | grep -q "^[[:space:]]*{"; then
                echo "json"
            elif head -n 5 "$file_path" | grep -q "^[[:space:]]*-\|^[a-zA-Z]"; then
                echo "yaml"
            else
                echo "unknown"
                return 1
            fi
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Configuration File Discovery
# ──────────────────────────────────────────────────────────────────────────────

find_config_file() {
    local base_path="$1"  # e.g., "./environments/dev/api-config"
    local default_name="$2"  # e.g., "api-config"
    
    # If base_path already has an extension, use it directly
    if [[ "$base_path" == *.yaml ]] || [[ "$base_path" == *.yml ]] || [[ "$base_path" == *.json ]]; then
        if [[ -f "$base_path" ]]; then
            echo "$base_path"
            return 0
        else
            return 1
        fi
    fi
    
    # Try different extensions in order of preference (YAML first)
    local extensions=("yaml" "yml" "json")
    
    for ext in "${extensions[@]}"; do
        local candidate="${base_path}.${ext}"
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    
    # If base_path is a directory, look for default config files
    if [[ -d "$base_path" ]]; then
        for ext in "${extensions[@]}"; do
            local candidate="${base_path}/${default_name}.${ext}"
            if [[ -f "$candidate" ]]; then
                echo "$candidate"
                return 0
            fi
        done
    fi
    
    return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# Configuration Validation
# ──────────────────────────────────────────────────────────────────────────────

validate_config_syntax() {
    local file_path="$1"
    local format=$(detect_config_format "$file_path")
    
    case "$format" in
        "json")
            if command -v jq &> /dev/null; then
                jq empty "$file_path" 2>/dev/null
            else
                echo "jq is required for JSON validation" >&2
                return 1
            fi
            ;;
        "yaml")
            if command -v yq &> /dev/null; then
                # Detect yq version and use appropriate syntax
                if yq --version 2>/dev/null | grep -q "mikefarah/yq"; then
                    # Go yq v4+ (mikefarah/yq)
                    yq eval '.' "$file_path" >/dev/null 2>&1
                else
                    # Python yq or other version - try alternative syntax
                    yq . "$file_path" >/dev/null 2>&1 || yq eval '.' "$file_path" >/dev/null 2>&1
                fi
            else
                echo "yq is required for YAML validation" >&2
                return 1
            fi
            ;;
        *)
            echo "Unknown or unsupported configuration format: $format" >&2
            return 1
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Configuration Parsing
# ──────────────────────────────────────────────────────────────────────────────

parse_config() {
    local file_path="$1"
    local query="$2"  # jq/yq query expression
    local format=$(detect_config_format "$file_path")
    
    case "$format" in
        "json")
            if command -v jq &> /dev/null; then
                jq "$query" "$file_path" 2>/dev/null
            else
                echo "jq is required for JSON parsing" >&2
                return 1
            fi
            ;;
        "yaml")
            if command -v yq &> /dev/null; then
                # Convert jq query to yq syntax if needed
                local yq_query="$query"
                # Basic query translation (can be extended)
                case "$query" in
                    "length")
                        yq_query="length"
                        ;;
                    ".[]")
                        yq_query=".[]"
                        ;;
                    "empty")
                        yq_query="."
                        ;;
                    *)
                        # For complex queries, try to use jq-compatible syntax
                        yq_query="$query"
                        ;;
                esac
                yq eval "$yq_query" "$file_path" 2>/dev/null
            else
                echo "yq is required for YAML parsing" >&2
                return 1
            fi
            ;;
        *)
            echo "Unknown or unsupported configuration format: $format" >&2
            return 1
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Configuration Content Retrieval
# ──────────────────────────────────────────────────────────────────────────────

get_config_content() {
    local file_path="$1"
    local format=$(detect_config_format "$file_path")
    
    case "$format" in
        "json")
            cat "$file_path"
            ;;
        "yaml")
            if command -v yq &> /dev/null; then
                # Convert YAML to JSON for consistent processing
                yq eval -o=json '.' "$file_path" 2>/dev/null
            else
                echo "yq is required for YAML processing" >&2
                return 1
            fi
            ;;
        *)
            echo "Unknown or unsupported configuration format: $format" >&2
            return 1
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Array Processing for Configuration
# ──────────────────────────────────────────────────────────────────────────────

get_config_array_items() {
    local file_path="$1"
    local format=$(detect_config_format "$file_path")
    
    case "$format" in
        "json")
            if command -v jq &> /dev/null; then
                jq -c '.[]' "$file_path" 2>/dev/null
            else
                echo "jq is required for JSON array processing" >&2
                return 1
            fi
            ;;
        "yaml")
            if command -v yq &> /dev/null; then
                # Convert to compact JSON format for consistent array processing
                yq eval -o=json -I=0 '.[]' "$file_path" 2>/dev/null
            else
                echo "yq is required for YAML array processing" >&2
                return 1
            fi
            ;;
        *)
            echo "Unknown or unsupported configuration format: $format" >&2
            return 1
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Dependency Checking
# ──────────────────────────────────────────────────────────────────────────────

check_config_dependencies() {
    local missing_deps=()
    
    # Check for jq (required for JSON)
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    # Check for yq (required for YAML)
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Missing dependencies for configuration processing:" >&2
        printf '  - %s\n' "${missing_deps[@]}" >&2
        echo "" >&2
        echo "Install missing dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "jq")
                    echo "  - jq: apt-get install jq  # or brew install jq" >&2
                    ;;
                "yq")
                    echo "  - yq: pip install yq  # or brew install yq" >&2
                    ;;
            esac
        done
        return 1
    fi
    
    return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# Environment Variable Substitution (Enhanced for YAML)
# ──────────────────────────────────────────────────────────────────────────────

substitute_env_vars_in_config() {
    local content="$1"
    local format="$2"  # "json" or "yaml"
    
    # Use the same substitution logic but preserve format-specific structure
    while [[ $content =~ \$\{([^}]+)\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${!var_name:-}"
        if [[ -z "$var_value" ]]; then
            # For production use, you might want to handle this differently
            echo "Warning: Environment variable '$var_name' is not set, leaving placeholder" >&2
        else
            content="${content//\$\{$var_name\}/$var_value}"
        fi
    done
    
    echo "$content"
}

# ──────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ──────────────────────────────────────────────────────────────────────────────

get_config_format_display_name() {
    local format="$1"
    case "$format" in
        "json") echo "JSON" ;;
        "yaml") echo "YAML" ;;
        *) echo "Unknown" ;;
    esac
}

is_config_format_supported() {
    local format="$1"
    case "$format" in
        "json"|"yaml") return 0 ;;
        *) return 1 ;;
    esac
}