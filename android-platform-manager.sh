#!/usr/bin/env bash
#
# android-platform-manager.sh - Manage Android SDK platform configurations
# Description: Switch between platform configurations using symlinks
#              Supports profiles, multiple platforms, and interactive mode
#

set -e

# ============================================================================
# Configuration
# ============================================================================

readonly SDK="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
readonly PLATFORMS_ALL="$SDK/platforms-all"
readonly PLATFORMS_ACTIVE="$SDK/platforms"
readonly PROFILES_DIR="$SDK/.platform-profiles"

# Colors
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_RESET='\033[0m'

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

fatal() {
    error "$*"
    exit 1
}

# ============================================================================
# Validation Functions
# ============================================================================

check_sdk_structure() {
    if [ ! -d "$SDK" ]; then
        fatal "Android SDK not found at: $SDK"
    fi
    
    if [ ! -d "$PLATFORMS_ALL" ]; then
        fatal "platforms-all directory not found at: $PLATFORMS_ALL"
    fi
    
    # Create profiles directory if it doesn't exist
    mkdir -p "$PROFILES_DIR"
}

validate_platform() {
    local platform="$1"
    
    if [ ! -d "$PLATFORMS_ALL/$platform" ]; then
        error "Platform not found: $platform"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Platform Discovery
# ============================================================================

list_available_platforms() {
    if [ ! -d "$PLATFORMS_ALL" ]; then
        echo ""
        return
    fi
    
    ls -1 "$PLATFORMS_ALL" 2>/dev/null | sort -V
}

list_active_platforms() {
    if [ ! -d "$PLATFORMS_ACTIVE" ]; then
        echo ""
        return
    fi
    
    # List only symlinks (active platforms)
    find "$PLATFORMS_ACTIVE" -maxdepth 1 -type l -printf "%f\n" 2>/dev/null | sort -V
}

show_platforms_status() {
    echo "=== Available Platforms ==="
    local available
    available=$(list_available_platforms)
    
    if [ -z "$available" ]; then
        warn "No platforms found in $PLATFORMS_ALL"
        return
    fi
    
    local active
    active=$(list_active_platforms)
    
    while IFS= read -r platform; do
        if echo "$active" | grep -q "^${platform}$"; then
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $platform (active)"
        else
            echo "    $platform"
        fi
    done <<< "$available"
    
    echo ""
}

# ============================================================================
# Platform Activation
# ============================================================================

clear_active_platforms() {
    log "Clearing active platforms..."
    
    if [ -d "$PLATFORMS_ACTIVE" ]; then
        # Remove only symlinks, keep real directories
        find "$PLATFORMS_ACTIVE" -maxdepth 1 -type l -delete
    else
        mkdir -p "$PLATFORMS_ACTIVE"
    fi
}

activate_platform() {
    local platform="$1"
    
    if ! validate_platform "$platform"; then
        return 1
    fi
    
    local target_link="$PLATFORMS_ACTIVE/$platform"
    
    # Remove if already exists
    [ -L "$target_link" ] && rm "$target_link"
    
    # Create symlink
    ln -s "../platforms-all/$platform" "$target_link"
    
    log "Activated: $platform"
    return 0
}

activate_multiple_platforms() {
    local platforms=("$@")
    local activated=0
    local failed=0
    
    clear_active_platforms
    
    for platform in "${platforms[@]}"; do
        if activate_platform "$platform"; then
            ((activated++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    success "Activated $activated platform(s)"
    [ $failed -gt 0 ] && error "Failed: $failed" || true
    
    return 0
}

# ============================================================================
# Profile Management
# ============================================================================

list_profiles() {
    if [ ! -d "$PROFILES_DIR" ]; then
        echo ""
        return
    fi
    
    ls -1 "$PROFILES_DIR" 2>/dev/null | sed 's/\.profile$//'
}

save_profile() {
    local profile_name="$1"
    local platforms=("${@:2}")
    
    if [ -z "$profile_name" ]; then
        fatal "Profile name required"
    fi
    
    if [ ${#platforms[@]} -eq 0 ]; then
        fatal "At least one platform required"
    fi
    
    local profile_file="$PROFILES_DIR/${profile_name}.profile"
    
    # Validate all platforms before saving
    for platform in "${platforms[@]}"; do
        if ! validate_platform "$platform"; then
            fatal "Invalid platform: $platform"
        fi
    done
    
    # Save profile
    printf "%s\n" "${platforms[@]}" > "$profile_file"
    
    success "Profile saved: $profile_name"
    log "Platforms: ${platforms[*]}"
}

load_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.profile"
    
    if [ ! -f "$profile_file" ]; then
        fatal "Profile not found: $profile_name"
    fi
    
    log "Loading profile: $profile_name"
    
    local platforms=()
    while IFS= read -r platform; do
        [ -n "$platform" ] && platforms+=("$platform")
    done < "$profile_file"
    
    if [ ${#platforms[@]} -eq 0 ]; then
        fatal "Profile is empty: $profile_name"
    fi
    
    activate_multiple_platforms "${platforms[@]}"
}

delete_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.profile"
    
    if [ ! -f "$profile_file" ]; then
        fatal "Profile not found: $profile_name"
    fi
    
    rm "$profile_file"
    success "Profile deleted: $profile_name"
}

show_profile_info() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.profile"
    
    if [ ! -f "$profile_file" ]; then
        fatal "Profile not found: $profile_name"
    fi
    
    echo "Profile: $profile_name"
    echo "Platforms:"
    while IFS= read -r platform; do
        echo "  - $platform"
    done < "$profile_file"
}

list_profiles_detailed() {
    echo "=== Saved Profiles ==="
    
    local profiles
    profiles=$(list_profiles)
    
    if [ -z "$profiles" ]; then
        warn "No profiles saved"
        return
    fi
    
    while IFS= read -r profile; do
        local count=$(wc -l < "$PROFILES_DIR/${profile}.profile")
        echo "  $profile ($count platform(s))"
    done <<< "$profiles"
    
    echo ""
}

# ============================================================================
# Interactive Mode
# ============================================================================

interactive_select_platforms() {
    local available
    available=$(list_available_platforms)
    
    if [ -z "$available" ]; then
        fatal "No platforms available"
    fi
    
    echo "=== Select Platforms ==="
    echo ""
    
    local platforms=()
    local index=1
    local platform_array=()
    
    while IFS= read -r platform; do
        platform_array+=("$platform")
        echo "  [$index] $platform"
        ((index++))
    done <<< "$available"
    
    echo ""
    echo "Enter platform numbers (space-separated, e.g., 1 3 5):"
    read -p "> " selections
    
    for selection in $selections; do
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#platform_array[@]}" ]; then
            platforms+=("${platform_array[$((selection-1))]}")
        else
            warn "Invalid selection: $selection"
        fi
    done
    
    if [ ${#platforms[@]} -eq 0 ]; then
        fatal "No valid platforms selected"
    fi
    
    activate_multiple_platforms "${platforms[@]}"
}

# ============================================================================
# Usage
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Manage Android SDK platform configurations using symlinks

COMMANDS:
    list                        List all available platforms with status
    activate <platform...>      Activate one or more platforms
    clear                       Clear all active platforms
    
    profile-list                List all saved profiles
    profile-save <name> <platform...>    Save platforms as a profile
    profile-load <name>         Load and activate a profile
    profile-show <name>         Show profile details
    profile-delete <name>       Delete a profile
    
    interactive                 Interactive platform selection
    
    status                      Show current active platforms

OPTIONS:
    -h, --help                  Show this help message

EXAMPLES:
    # Activate single platform
    $(basename "$0") activate android-28
    
    # Activate multiple platforms
    $(basename "$0") activate android-28 android-30 android-34
    
    # Save current selection as profile
    $(basename "$0") profile-save dev android-28 android-30
    
    # Load profile
    $(basename "$0") profile-load dev
    
    # Interactive mode
    $(basename "$0") interactive
    
    # List all platforms
    $(basename "$0") list

ENVIRONMENT:
    ANDROID_SDK_ROOT            Android SDK location (default: ~/Android/Sdk)

EOF
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Check SDK structure
    check_sdk_structure
    
    # Parse command
    local command="${1:-}"
    
    case "$command" in
        ""|status)
            show_platforms_status
            echo "=== Active Platforms ==="
            ls -l "$PLATFORMS_ACTIVE" 2>/dev/null | grep "^l" | awk '{print "  " $9 " -> " $11}' || echo "  (none)"
            ;;
        
        list)
            show_platforms_status
            ;;
        
        activate)
            shift
            if [ $# -eq 0 ]; then
                fatal "Usage: $(basename "$0") activate <platform...>"
            fi
            activate_multiple_platforms "$@"
            ;;
        
        clear)
            clear_active_platforms
            success "All platforms cleared"
            ;;
        
        profile-list)
            list_profiles_detailed
            ;;
        
        profile-save)
            shift
            if [ $# -lt 2 ]; then
                fatal "Usage: $(basename "$0") profile-save <name> <platform...>"
            fi
            save_profile "$@"
            ;;
        
        profile-load)
            if [ -z "$2" ]; then
                fatal "Usage: $(basename "$0") profile-load <name>"
            fi
            load_profile "$2"
            ;;
        
        profile-show)
            if [ -z "$2" ]; then
                fatal "Usage: $(basename "$0") profile-show <name>"
            fi
            show_profile_info "$2"
            ;;
        
        profile-delete)
            if [ -z "$2" ]; then
                fatal "Usage: $(basename "$0") profile-delete <name>"
            fi
            delete_profile "$2"
            ;;
        
        interactive)
            interactive_select_platforms
            ;;
        
        -h|--help)
            show_usage
            exit 0
            ;;
        
        *)
            # Legacy mode: single platform activation
            if validate_platform "$command"; then
                activate_multiple_platforms "$command"
            else
                error "Unknown command: $command"
                echo ""
                show_usage
                exit 1
            fi
            ;;
    esac
}

main "$@"

exit 0

