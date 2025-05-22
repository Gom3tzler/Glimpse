#!/bin/bash
set -e

# Set default primary server
PRIMARY_SERVER=${PRIMARY_SERVER:-"plex"}

# Smart primary server detection based on available credentials
original_primary_server="$PRIMARY_SERVER"

# Auto-detect and correct PRIMARY_SERVER based on available credentials
if [ "$PRIMARY_SERVER" = "plex" ]; then
    if [ -z "$PLEX_URL" ] || [ -z "$PLEX_TOKEN" ]; then
        if [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
            echo "Warning: PRIMARY_SERVER set to 'plex' but only Jellyfin credentials provided"
            echo "Auto-switching PRIMARY_SERVER to 'jellyfin'"
            PRIMARY_SERVER="jellyfin"
        else
            echo "Error: PRIMARY_SERVER=plex but no valid credentials provided for any server"
            exit 1
        fi
    fi
elif [ "$PRIMARY_SERVER" = "jellyfin" ]; then
    if [ -z "$JELLYFIN_URL" ] || [ -z "$JELLYFIN_TOKEN" ]; then
        if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
            echo "Warning: PRIMARY_SERVER set to 'jellyfin' but only Plex credentials provided"
            echo "Auto-switching PRIMARY_SERVER to 'plex'"
            PRIMARY_SERVER="plex"
        else
            echo "Error: PRIMARY_SERVER=jellyfin but no valid credentials provided for any server"
            exit 1
        fi
    fi
else
    # If PRIMARY_SERVER is not set or invalid, auto-detect
    if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
        echo "PRIMARY_SERVER not set or invalid, defaulting to 'plex' based on available credentials"
        PRIMARY_SERVER="plex"
    elif [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
        echo "PRIMARY_SERVER not set or invalid, defaulting to 'jellyfin' based on available credentials"
        PRIMARY_SERVER="jellyfin"
    else
        echo "Error: No valid credentials provided for any media server"
        echo "Please set PLEX_URL/PLEX_TOKEN or JELLYFIN_URL/JELLYFIN_TOKEN"
        exit 1
    fi
fi

# Log the final decision
if [ "$original_primary_server" != "$PRIMARY_SERVER" ]; then
    echo "PRIMARY_SERVER changed from '$original_primary_server' to '$PRIMARY_SERVER'"
fi
echo "Using PRIMARY_SERVER: $PRIMARY_SERVER"

# Set default app title if not provided
APP_TITLE=${APP_TITLE:-"Glimpse"}
echo "Using application title: $APP_TITLE"

# Set default cron schedule if not provided
CRON_SCHEDULE=${CRON_SCHEDULE:-"0 */6 * * *"}

# Set default sort method
SORT_BY_DATE_ADDED=${SORT_BY_DATE_ADDED:-"false"}
echo "Default sort by date added: $SORT_BY_DATE_ADDED"

# Find Python path
PYTHON_PATH=$(which python)
echo "Python path: $PYTHON_PATH"

# Create the cron job with PATH
echo "PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin" >/etc/cron.d/media-cron

# Add cron jobs for each configured server
if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
    echo "$CRON_SCHEDULE root cd /app && $PYTHON_PATH /app/scripts/plex_data_fetcher.py --url \"$PLEX_URL\" --token \"$PLEX_TOKEN\" --output /app/data/plex >> /var/log/cron.log 2>&1" >>/etc/cron.d/media-cron
fi

if [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
    echo "$CRON_SCHEDULE root cd /app && $PYTHON_PATH /app/scripts/jellyfin_data_fetcher.py --url \"$JELLYFIN_URL\" --token \"$JELLYFIN_TOKEN\" --output /app/data/jellyfin >> /var/log/cron.log 2>&1" >>/etc/cron.d/media-cron
fi

# Apply cron job
crontab /etc/cron.d/media-cron

# Migrate existing data to new structure for backward compatibility
migrate_existing_data() {
    echo "Checking for existing data to migrate..."

    # Check if there are files directly in /app/data that should be moved to /app/data/plex
    if [ -f "/app/data/movies.json" ] || [ -f "/app/data/tvshows.json" ] || [ -d "/app/data/posters" ] || [ -d "/app/data/backdrops" ]; then
        echo "Found existing Plex data in /app/data - migrating to /app/data/plex/"

        # Create plex directory if it doesn't exist
        mkdir -p /app/data/plex

        # Move JSON files
        if [ -f "/app/data/movies.json" ]; then
            echo "Moving movies.json to plex directory"
            mv /app/data/movies.json /app/data/plex/
        fi

        if [ -f "/app/data/tvshows.json" ]; then
            echo "Moving tvshows.json to plex directory"
            mv /app/data/tvshows.json /app/data/plex/
        fi

        # Move image directories
        if [ -d "/app/data/posters" ]; then
            echo "Moving posters directory to plex directory"
            mv /app/data/posters /app/data/plex/
        fi

        if [ -d "/app/data/backdrops" ]; then
            echo "Moving backdrops directory to plex directory"
            mv /app/data/backdrops /app/data/plex/
        fi

        # Move checksums file if it exists
        if [ -f "/app/data/checksums.pkl" ]; then
            echo "Moving checksums.pkl to plex directory"
            mv /app/data/checksums.pkl /app/data/plex/
        fi

        echo "Migration completed successfully"

        # Set permissions on moved files
        chown -R www-data:www-data /app/data/plex/ 2>/dev/null || echo "Note: Could not set permissions on migrated files"
    else
        echo "No existing data found to migrate"
    fi
}

# Run migration before setting up new structure
migrate_existing_data

# Create directory structure for both servers
mkdir -p /app/web/plex
mkdir -p /app/web/jellyfin

# Function to apply Jellyfin theme to index file
apply_jellyfin_theme() {
    local index_file=$1
    echo "Applying Jellyfin theme to $index_file"

    # Create temporary file with Jellyfin CSS overrides
    cat >/tmp/jellyfin_theme.css <<'EOF'

        /* Jellyfin Theme Overrides */
        :root {
            --primary-color: #00a4dc;
            --primary-hover: #0288c2;
            --primary-light: rgba(0, 164, 220, 0.1);
            --bg-color: #101010;
            --secondary-bg: #181818;
            --header-bg: #141414;
            --tab-bg: #252525;
        }
        
        /* Ensure full screen coverage without affecting layout */
        html {
            min-height: 100vh;
        }
        
        /* Jellyfin gradient background */
        body {
            background: linear-gradient(135deg, #101010 0%, #181818 50%, #1a1a2e 100%) !important;
            background-attachment: fixed !important;
            background-size: cover !important;
            background-repeat: no-repeat !important;
            min-height: 100vh;
        }
        
        /* Jellyfin accent color for active elements */
        .tab.active,
        .sort-button.active,
        .genre-button.active {
            background: linear-gradient(135deg, #00a4dc, #7b68ee) !important;
            color: white !important;
        }
        
        /* Jellyfin hover effects */
        .tab:hover:not(.active),
        .sort-button:hover:not(.active),
        .genre-button:hover:not(.active),
        .server-toggle-button:hover {
            background-color: rgba(0, 164, 220, 0.2) !important;
        }
        
        /* Jellyfin media item hover */
        .media-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 25px rgba(0, 164, 220, 0.3) !important;
        }
        
        /* Jellyfin scroll indicators */
        .scroll-to-top {
            background: linear-gradient(135deg, #00a4dc, #7b68ee) !important;
        }
        
        /* Jellyfin modal backdrop */
        .modal-backdrop::after {
            background: linear-gradient(to bottom, rgba(16, 16, 16, 0.3) 0%, #101010 100%) !important;
        }
        
        /* Jellyfin header styling */
        .header {
            background-color: #141414 !important;
            border-bottom: 1px solid rgba(0, 164, 220, 0.2);
        }
EOF

    # Insert Jellyfin theme CSS after the existing styles but before closing </style>
    sed -i '/<\/style>/e cat /tmp/jellyfin_theme.css' "$index_file"

    # Update the app title in browser tab if we're theming the main index
    if [[ "$index_file" == *"/index.html" ]] && [[ "$index_file" != *"/jellyfin/index.html" ]]; then
        # Get current title and add Jellyfin indicator
        current_title=$(grep -o '<title>[^<]*</title>' "$index_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        if [[ "$current_title" != *"Jellyfin"* ]]; then
            sed -i "s/<title>$current_title<\/title>/<title>$current_title - Jellyfin<\/title>/" "$index_file"
        fi
    fi

    # Clean up temporary file
    rm -f /tmp/jellyfin_theme.css
}

# Function to apply Plex theme (default/existing theme)
apply_plex_theme() {
    local index_file=$1
    echo "Applying Plex theme to $index_file (default colors)"

    # Update the app title in browser tab if we're theming the main index
    if [[ "$index_file" == *"/index.html" ]] && [[ "$index_file" != *"/plex/index.html" ]]; then
        # Get current title and add Plex indicator
        current_title=$(grep -o '<title>[^<]*</title>' "$index_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        if [[ "$current_title" != *"Plex"* ]]; then
            sed -i "s/<title>$current_title<\/title>/<title>$current_title - Plex<\/title>/" "$index_file"
        fi
    fi

    # Plex uses the default theme, so no additional CSS needed
}
remove_server_toggle() {
    local index_file=$1
    echo "Removing server toggle from $index_file"

    # Remove the desktop server toggle div and its contents
    sed -i '/<div class="server-toggle">/,/<\/div>/d' "$index_file"

    # Remove the mobile server toggle button
    sed -i '/<!-- Mobile Server Toggle/,/>/d' "$index_file"
    sed -i '/<button class="sort-button server-toggle-button"/d' "$index_file"

    # Remove the server toggle CSS
    sed -i '/\/\* Server Toggle Styles \*\//,/}/d' "$index_file"

    # Remove the server toggle JavaScript function
    sed -i '/\/\/ Server toggle functionality/,/}/d' "$index_file"
}

# Function to update server toggle text and path
update_server_toggle() {
    local index_file=$1
    local switch_to_server=$2
    local switch_to_path=$3
    local is_primary=$4 # New parameter to indicate if this is the primary server

    echo "Updating server toggle in $index_file: Switch to $switch_to_server"

    # First, reset any existing toggle text back to placeholders
    sed -i 's/Switch to Plex/Switch to SERVER_NAME/g' "$index_file"
    sed -i 's/Switch to Jellyfin/Switch to SERVER_NAME/g' "$index_file"

    # Reset ONLY the toggle button path, not the data paths
    # Look for the specific pattern in the toggleServer function
    sed -i 's/newPath = "[^"]*";/newPath = "SERVER_PATH\/";/g' "$index_file"

    # Now update with the correct values
    sed -i "s/Switch to SERVER_NAME/Switch to $switch_to_server/g" "$index_file"

    # Update the path - if switching to primary server, go to root, otherwise go to specific route
    if [ "$is_primary" = "true" ]; then
        # Going to primary server - use root path
        sed -i "s/SERVER_PATH\//\//g" "$index_file"
    else
        # Going to secondary server - use specific route
        local escaped_path=$(echo "$switch_to_path" | sed 's/\//\\\//g')
        sed -i "s/SERVER_PATH/$escaped_path/g" "$index_file"
    fi
}

# Function to create index.html for a specific server
create_server_index() {
    local server_type=$1
    local data_path=$2
    local output_file=$3

    # Copy the main index.html as a template
    cp /app/web/index.html "$output_file"

    # For sub-directory routes, we need to use relative paths from the sub-directory
    if [ "$output_file" != "/app/web/index.html" ]; then
        # For /plex/ and /jellyfin/ routes, update data paths with ../
        sed -i "s|'data/movies\.json'|'../${data_path}/movies.json'|g" "$output_file"
        sed -i "s|\"data/movies\.json\"|\"../${data_path}/movies.json\"|g" "$output_file"
        sed -i "s|'data/tvshows\.json'|'../${data_path}/tvshows.json'|g" "$output_file"
        sed -i "s|\"data/tvshows\.json\"|\"../${data_path}/tvshows.json\"|g" "$output_file"
        sed -i "s|data/posters/|../${data_path}/posters/|g" "$output_file"
        sed -i "s|data/backdrops/|../${data_path}/backdrops/|g" "$output_file"

        # If the main index was already modified for a primary server, we need to undo those changes first
        # Replace any existing data/jellyfin/ or data/plex/ paths back to data/ then apply the new paths
        sed -i "s|data/jellyfin/movies\.json|data/movies.json|g" "$output_file"
        sed -i "s|data/jellyfin/tvshows\.json|data/tvshows.json|g" "$output_file"
        sed -i "s|data/jellyfin/posters/|data/posters/|g" "$output_file"
        sed -i "s|data/jellyfin/backdrops/|data/backdrops/|g" "$output_file"
        sed -i "s|data/plex/movies\.json|data/movies.json|g" "$output_file"
        sed -i "s|data/plex/tvshows\.json|data/tvshows.json|g" "$output_file"
        sed -i "s|data/plex/posters/|data/posters/|g" "$output_file"
        sed -i "s|data/plex/backdrops/|data/backdrops/|g" "$output_file"

        # Now apply the correct paths with ../
        sed -i "s|'data/movies\.json'|'../${data_path}/movies.json'|g" "$output_file"
        sed -i "s|\"data/movies\.json\"|\"../${data_path}/movies.json\"|g" "$output_file"
        sed -i "s|'data/tvshows\.json'|'../${data_path}/tvshows.json'|g" "$output_file"
        sed -i "s|\"data/tvshows\.json\"|\"../${data_path}/tvshows.json\"|g" "$output_file"
        sed -i "s|data/posters/|../${data_path}/posters/|g" "$output_file"
        sed -i "s|data/backdrops/|../${data_path}/backdrops/|g" "$output_file"

        # Fix asset paths that should remain relative to root
        sed -i 's|src="images/|src="../images/|g' "$output_file"
        sed -i 's|href="images/|href="../images/|g' "$output_file"
        sed -i 's|href="/manifest.json"|href="../manifest.json"|g' "$output_file"
        sed -i 's|href="/images/|href="../images/|g' "$output_file"
        sed -i 's|register("/sw.js")|register("../sw.js")|g' "$output_file"
    else
        # For main index.html, just update the data paths directly
        sed -i "s|'data/movies\.json'|'${data_path}/movies.json'|g" "$output_file"
        sed -i "s|\"data/movies\.json\"|\"${data_path}/movies.json\"|g" "$output_file"
        sed -i "s|'data/tvshows\.json'|'${data_path}/tvshows.json'|g" "$output_file"
        sed -i "s|\"data/tvshows\.json\"|\"${data_path}/tvshows.json\"|g" "$output_file"
        sed -i "s|data/posters/|${data_path}/posters/|g" "$output_file"
        sed -i "s|data/backdrops/|${data_path}/backdrops/|g" "$output_file"
    fi
}

# Update the main index.html based on primary server
if [ -f /app/web/index.html ]; then
    echo "Updating app title to: $APP_TITLE"
    # Replace title tag content
    sed -i "s/<title>.*<\/title>/<title>$APP_TITLE<\/title>/" /app/web/index.html
    # Replace h1 content (preserve the logo icon span)
    sed -i "s/<h1>.*<\/h1>/<h1><span class=\"logo-icon\"><img src=\"images\/logo.png\" \/><\/span>$APP_TITLE<\/h1>/" /app/web/index.html

    # Update the default sort method in the JavaScript
    if [ "$SORT_BY_DATE_ADDED" = "true" ]; then
        echo "Setting default sort method to date added"
        sed -i "s/let currentSortMethod = 'alpha';/let currentSortMethod = 'date';/" /app/web/index.html
    fi

    # Update data paths based on primary server
    if [ "$PRIMARY_SERVER" = "plex" ]; then
        echo "Setting up primary server as Plex"
        # Main index.html points to plex data
        sed -i "s|'data/movies\.json'|'data/plex/movies.json'|g" /app/web/index.html
        sed -i "s|\"data/movies\.json\"|\"data/plex/movies.json\"|g" /app/web/index.html
        sed -i "s|'data/tvshows\.json'|'data/plex/tvshows.json'|g" /app/web/index.html
        sed -i "s|\"data/tvshows\.json\"|\"data/plex/tvshows.json\"|g" /app/web/index.html
        sed -i "s|data/posters/|data/plex/posters/|g" /app/web/index.html
        sed -i "s|data/backdrops/|data/plex/backdrops/|g" /app/web/index.html
    else
        echo "Setting up primary server as Jellyfin"
        # Main index.html points to jellyfin data
        sed -i "s|'data/movies\.json'|'data/jellyfin/movies.json'|g" /app/web/index.html
        sed -i "s|\"data/movies\.json\"|\"data/jellyfin/movies.json\"|g" /app/web/index.html
        sed -i "s|'data/tvshows\.json'|'data/jellyfin/tvshows.json'|g" /app/web/index.html
        sed -i "s|\"data/tvshows\.json\"|\"data/jellyfin/tvshows.json\"|g" /app/web/index.html
        sed -i "s|data/posters/|data/jellyfin/posters/|g" /app/web/index.html
        sed -i "s|data/backdrops/|data/jellyfin/backdrops/|g" /app/web/index.html
    fi

    # Handle server toggle based on configuration
    # Check if both servers are configured
    both_servers_configured=false
    if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ] && [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
        both_servers_configured=true
        echo "Both servers configured - keeping server toggle functionality"

        # Update the toggle button text based on primary server for main index
        if [ "$PRIMARY_SERVER" = "plex" ]; then
            # Main index shows Plex, so switch to Jellyfin (secondary)
            update_server_toggle "/app/web/index.html" "Jellyfin" "jellyfin" "false"
        else
            # Main index shows Jellyfin, so switch to Plex (secondary)
            update_server_toggle "/app/web/index.html" "Plex" "plex" "false"
        fi
    else
        echo "Only one server configured - removing server toggle functionality"
        remove_server_toggle "/app/web/index.html"
    fi

    # Handle server toggle based on configuration
    # Check if both servers are configured
    both_servers_configured=false
    if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ] && [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
        both_servers_configured=true
        echo "Both servers configured - keeping server toggle functionality"

        # Update the toggle button for main index and apply theme
        if [ "$PRIMARY_SERVER" = "plex" ]; then
            # Main index shows Plex, so switch to Jellyfin (secondary)
            update_server_toggle "/app/web/index.html" "Jellyfin" "jellyfin" "false"
            apply_plex_theme "/app/web/index.html"
        else
            # Main index shows Jellyfin, so switch to Plex (secondary)
            update_server_toggle "/app/web/index.html" "Plex" "plex" "false"
            apply_jellyfin_theme "/app/web/index.html"
        fi
    else
        echo "Only one server configured - removing server toggle functionality"
        remove_server_toggle "/app/web/index.html"

        # Apply theme based on single server type
        if [ "$PRIMARY_SERVER" = "jellyfin" ]; then
            apply_jellyfin_theme "/app/web/index.html"
        else
            apply_plex_theme "/app/web/index.html"
        fi
    fi

    # Create route ONLY for secondary servers
    if [ "$both_servers_configured" = true ]; then
        if [ "$PRIMARY_SERVER" = "plex" ]; then
            # Plex is primary, so create Jellyfin route only
            echo "Creating secondary server route: /jellyfin/"
            create_server_index "jellyfin" "data/jellyfin" "/app/web/jellyfin/index.html"
            # When viewing secondary Jellyfin, switch back to primary (root)
            update_server_toggle "/app/web/jellyfin/index.html" "Plex" "../" "true"
            apply_jellyfin_theme "/app/web/jellyfin/index.html"
        else
            # Jellyfin is primary, so create Plex route only
            echo "Creating secondary server route: /plex/"
            create_server_index "plex" "data/plex" "/app/web/plex/index.html"
            # When viewing secondary Plex, switch back to primary (root)
            update_server_toggle "/app/web/plex/index.html" "Jellyfin" "../" "true"
            apply_plex_theme "/app/web/plex/index.html"
        fi
    else
        # Single server setup - no secondary routes needed
        echo "Single server setup - no secondary routes created"
    fi

    echo "Configuration updated successfully"
else
    echo "Warning: index.html not found in /app/web/"
fi

# Create symlinks for data directories
# Remove existing symlink if it exists
rm -f /app/web/data

# Always create the main data symlink pointing to /app/data
ln -sf /app/data /app/web/data

# Ensure nginx configuration is correct
echo "<!DOCTYPE html><html><head><title>Nginx Test</title></head><body><h1>Nginx is working from /app/web!</h1></body></html>" >/app/web/test.html

# Run the initial data fetch - each server goes to its own directory
echo "Running initial data fetch"

# Fetch Plex data if configured
if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
    echo "Fetching Plex data"
    $PYTHON_PATH /app/scripts/plex_data_fetcher.py --url "$PLEX_URL" --token "$PLEX_TOKEN" --output /app/data/plex
fi

# Fetch Jellyfin data if configured
if [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
    echo "Fetching Jellyfin data"
    $PYTHON_PATH /app/scripts/jellyfin_data_fetcher.py --url "$JELLYFIN_URL" --token "$JELLYFIN_TOKEN" --output /app/data/jellyfin
fi

# Make sure the data directory is accessible by nginx
chown -R www-data:www-data /app/data
chown -R www-data:www-data /app/web

# Print debugging info
echo "Checking Nginx configurations:"
ls -la /etc/nginx/conf.d/
ls -la /etc/nginx/sites-enabled/ || echo "No sites-enabled directory"
echo "Checking web directory:"
ls -la /app/web/
echo "Primary server: $PRIMARY_SERVER"

# Start supervisor (which will start both nginx and cron)
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
