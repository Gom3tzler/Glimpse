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

# Function to create themed offline.html
create_themed_offline() {
    local server_type=$1
    local app_title=$2

    echo "Creating $server_type themed offline.html"

    if [ "$server_type" = "jellyfin" ]; then
        # Jellyfin themed offline page
        cat >/app/web/offline.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Offline - REPLACE_APP_TITLE</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
            background: linear-gradient(135deg, #101010 0%, #181818 50%, #1a1a2e 100%);
            background-attachment: fixed;
            color: #fff;
            text-align: center;
            padding: 40px 20px;
            margin: 0;
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .container {
            max-width: 500px;
        }
        h1 {
            color: #00a4dc;
            margin-bottom: 20px;
            font-size: 2.5rem;
            font-weight: 700;
        }
        p {
            font-size: 18px;
            line-height: 1.6;
            margin-bottom: 30px;
            color: rgba(255, 255, 255, 0.9);
        }
        .icon {
            font-size: 64px;
            margin-bottom: 30px;
            filter: hue-rotate(200deg);
        }
        button {
            background: linear-gradient(135deg, #00a4dc, #7b68ee);
            color: #fff;
            border: none;
            padding: 12px 20px;
            border-radius: 24px;
            font-weight: bold;
            cursor: pointer;
            font-size: 16px;
            transition: all 0.3s;
            box-shadow: 0 4px 15px rgba(0, 164, 220, 0.3);
        }
        button:hover {
            background: linear-gradient(135deg, #0288c2, #6a5acd);
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(0, 164, 220, 0.4);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📶</div>
        <h1>You're Offline</h1>
        <p>It looks like you're not connected to the internet. REPLACE_APP_TITLE needs a connection to show your Jellyfin content.</p>
        <button onclick="window.location.reload()">Try Again</button>
    </div>
</body>
</html>
EOF
    else
        # Plex themed offline page (default)
        cat >/app/web/offline.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Offline - REPLACE_APP_TITLE</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
            background-color: #1a1a1a;
            color: #fff;
            text-align: center;
            padding: 40px 20px;
            margin: 0;
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .container {
            max-width: 500px;
        }
        h1 {
            color: #e5a00d;
            margin-bottom: 20px;
            font-size: 2.5rem;
            font-weight: 700;
        }
        p {
            font-size: 18px;
            line-height: 1.6;
            margin-bottom: 30px;
        }
        .icon {
            font-size: 64px;
            margin-bottom: 30px;
        }
        button {
            background-color: #e5a00d;
            color: #000;
            border: none;
            padding: 12px 20px;
            border-radius: 24px;
            font-weight: bold;
            cursor: pointer;
            font-size: 16px;
            transition: all 0.3s;
        }
        button:hover {
            background-color: #f1b020;
            transform: translateY(-2px);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📶</div>
        <h1>You're Offline</h1>
        <p>It looks like you're not connected to the internet. REPLACE_APP_TITLE needs a connection to show your Plex content.</p>
        <button onclick="window.location.reload()">Try Again</button>
    </div>
</body>
</html>
EOF
    fi

    # Replace the app title placeholder
    sed -i "s/REPLACE_APP_TITLE/$app_title/g" /app/web/offline.html

    # Set proper permissions
    chown www-data:www-data /app/web/offline.html 2>/dev/null || echo "Note: Could not set permissions on offline.html"
}

create_themed_manifest() {
    local server_type=$1
    local app_title=$2

    echo "Creating $server_type themed manifest.json"

    if [ "$server_type" = "jellyfin" ]; then
        # Jellyfin themed manifest
        cat >/app/web/manifest.json <<EOF
{
  "name": "$app_title",
  "short_name": "$app_title",
  "description": "A sleek, responsive web application for browsing your Jellyfin media library",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#101010",
  "theme_color": "#00a4dc",
  "orientation": "any",
  "icons": [
    {
      "src": "/images/jellyfin/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/images/jellyfin/android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF
    else
        # Plex themed manifest (default)
        cat >/app/web/manifest.json <<EOF
{
  "name": "$app_title",
  "short_name": "$app_title",
  "description": "A sleek, responsive web application for browsing your Plex media library",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a1a",
  "theme_color": "#e5a00d",
  "orientation": "any",
  "icons": [
    {
      "src": "/images/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/images/android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF
    fi

    # Set proper permissions
    chown www-data:www-data /app/web/manifest.json 2>/dev/null || echo "Note: Could not set permissions on manifest.json"

    # Also update the HTML meta theme-color tag
    if [ -f /app/web/index.html ]; then
        if [ "$server_type" = "jellyfin" ]; then
            sed -i 's/<meta name="theme-color" content="[^"]*">/<meta name="theme-color" content="#00a4dc">/' /app/web/index.html
        else
            sed -i 's/<meta name="theme-color" content="[^"]*">/<meta name="theme-color" content="#e5a00d">/' /app/web/index.html
        fi
    fi
}

apply_jellyfin_theme() {
    local index_file=$1
    echo "Applying Jellyfin theme to $index_file"

    # Update image paths to point to jellyfin directory
    echo "Updating image paths to use jellyfin directory"

    # Update logo image path - be specific to avoid double replacement
    sed -i 's|src="images/logo\.png"|src="images/jellyfin/logo.png"|g' "$index_file"
    sed -i 's|src="../images/logo\.png"|src="../images/jellyfin/logo.png"|g' "$index_file"

    # Update specific favicon and meta tag images
    sed -i 's|href="images/android-chrome-192x192\.png"|href="images/jellyfin/android-chrome-192x192.png"|g' "$index_file"
    sed -i 's|href="/images/android-chrome-192x192\.png"|href="/images/jellyfin/android-chrome-192x192.png"|g' "$index_file"
    sed -i 's|href="../images/android-chrome-192x192\.png"|href="../images/jellyfin/android-chrome-192x192.png"|g' "$index_file"

    sed -i 's|href="images/android-chrome-592x592\.png"|href="images/jellyfin/android-chrome-592x592.png"|g' "$index_file"
    sed -i 's|href="/images/android-chrome-592x592\.png"|href="/images/jellyfin/android-chrome-592x592.png"|g' "$index_file"
    sed -i 's|href="../images/android-chrome-592x592\.png"|href="../images/jellyfin/android-chrome-592x592.png"|g' "$index_file"

    sed -i 's|href="images/apple-touch-icon\.png"|href="images/jellyfin/apple-touch-icon.png"|g' "$index_file"
    sed -i 's|href="../images/apple-touch-icon\.png"|href="../images/jellyfin/apple-touch-icon.png"|g' "$index_file"

    sed -i 's|href="images/favicon-32x32\.png"|href="images/jellyfin/favicon-32x32.png"|g' "$index_file"
    sed -i 's|href="../images/favicon-32x32\.png"|href="../images/jellyfin/favicon-32x32.png"|g' "$index_file"

    sed -i 's|href="images/favicon-16x16\.png"|href="images/jellyfin/favicon-16x16.png"|g' "$index_file"
    sed -i 's|href="../images/favicon-16x16\.png"|href="../images/jellyfin/favicon-16x16.png"|g' "$index_file"

    # Update manifest.json path if it exists
    sed -i 's|href="/manifest\.json"|href="/manifest.json"|g' "$index_file"
    sed -i 's|href="../manifest\.json"|href="../manifest.json"|g' "$index_file"

    # Update title for main index files (primary server gets indicator too)
    if [[ "$index_file" == "/app/web/index.html" ]]; then
        # This is the main index, add Jellyfin indicator
        current_title=$(grep -o '<title>[^<]*</title>' "$index_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g')
        sed -i "s|<title>.*</title>|<title>$clean_title - Jellyfin</title>|" "$index_file"
        echo "Updated main index title to: $clean_title - Jellyfin"
    fi

    # Create temporary file with Jellyfin CSS overrides
    cat >/tmp/jellyfin_theme.css <<'EOF'

        /* Jellyfin Theme Overrides */
        :root {
            --primary-color: #00a4dc !important;
            --primary-hover: #0288c2 !important;
            --primary-light: rgba(0, 164, 220, 0.1) !important;
            --bg-color: #101010 !important;
            --secondary-bg: #181818 !important;
            --header-bg: #141414 !important;
            --tab-bg: #252525 !important;
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
        .server-toggle-button:hover,
        .roulette-button:hover,
        .modal-try-again-btn:hover {
            background-color: rgba(0, 164, 220, 0.2) !important;
        }
        
        /* Jellyfin media item hover - no glow, better contrast */
        .media-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2) !important;
        }
        
        /* Jellyfin poster container - better contrast against dark background */
        .media-item {
            background-color: #252525 !important;
        }
        
        /* Jellyfin scroll indicators */
        .scroll-to-top {
            background: linear-gradient(135deg, #00a4dc, #7b68ee) !important;
            color: #ffffff !important;
        }
        
        .scroll-to-top:hover {
            background: linear-gradient(135deg, #0288c2, #6a5acd) !important;
        }
        
        /* Jellyfin modal backdrop */
        .modal-backdrop::after {
            background: linear-gradient(to bottom, rgba(16, 16, 16, 0.3) 0%, #101010 100%) !important;
        }
        
        /* Jellyfin header styling */
        .header {
            background-color: #141414 !important;
            border-bottom: 1px solid rgba(0, 164, 220, 0.2) !important;
        }
        
        /* Jellyfin search input styling */
        .search-input {
            background-color: rgba(24, 24, 24, 0.8) !important;
            border: 1px solid rgba(0, 164, 220, 0.3) !important;
            color: #ffffff !important;
        }
        
        .search-input:focus {
            background-color: rgba(24, 24, 24, 0.9) !important;
            box-shadow: 0 0 0 2px rgba(0, 164, 220, 0.4) !important;
            border-color: rgba(0, 164, 220, 0.6) !important;
        }
        
        .search-input::placeholder {
            color: rgba(255, 255, 255, 0.6) !important;
        }
        
        .search-clear {
            color: rgba(255, 255, 255, 0.6) !important;
        }
        
        .search-clear:hover {
            color: #00a4dc !important;
            background-color: rgba(0, 164, 220, 0.1) !important;
        }
        
        /* Jellyfin genre styling */
        .genre-tag {
            background-color: rgba(0, 164, 220, 0.15) !important;
            border: 1px solid rgba(0, 164, 220, 0.3) !important;
            color: #00a4dc !important;
        }
        
        .genre-tag:hover {
            background-color: rgba(0, 164, 220, 0.25) !important;
            border-color: rgba(0, 164, 220, 0.5) !important;
        }
        
        /* Jellyfin genre dropdown/drawer styling */
        .genre-menu,
        .genre-drawer {
            background-color: #181818 !important;
            border: 1px solid rgba(0, 164, 220, 0.2) !important;
        }
        
        .genre-item:hover {
            background-color: rgba(0, 164, 220, 0.15) !important;
        }
        
        .genre-item.active {
            background-color: rgba(0, 164, 220, 0.2) !important;
            color: #00a4dc !important;
        }
        
        /* Jellyfin modal styling */
        .modal-content {
            background-color: #181818 !important;
        }
        
        .modal-header {
            border-bottom: 1px solid rgba(0, 164, 220, 0.2) !important;
        }
        
        .modal-title {
            color: #ffffff !important;
        }
        
        .modal-year {
            color: rgba(255, 255, 255, 0.7) !important;
        }
        
        .metadata-item {
            background-color: rgba(0, 164, 220, 0.15) !important;
            color: #ffffff !important;
        }
        
        .modal-section-title {
            color: #00a4dc !important;
        }
        
        .cast-item {
            background-color: rgba(0, 164, 220, 0.08) !important;
        }
        
        .cast-name {
            color: #ffffff !important;
        }
        
        .cast-role {
            color: rgba(255, 255, 255, 0.7) !important;
        }
        
        /* Jellyfin trailer button */
        .watch-trailer-btn {
            background: linear-gradient(135deg, #00a4dc, #7b68ee) !important;
            color: #ffffff !important;
        }
        
        .watch-trailer-btn:hover {
            background: linear-gradient(135deg, #0288c2, #6a5acd) !important;
        }
        
        /* Jellyfin mobile menu */
        .mobile-menu {
            background-color: #141414 !important;
        }
        
        /* Jellyfin tabs styling */
        .tab {
            background-color: #252525 !important;
        }
        
        .sort-button,
        .genre-button {
            background-color: #252525 !important;
        }
        
        /* Jellyfin genre drawer styling */
        .genre-drawer {
            background-color: #181818 !important;
        }
        
        .genre-drawer-header {
            border-bottom: 1px solid rgba(0, 164, 220, 0.2) !important;
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

    echo "Creating server index for $server_type at $output_file"

    # Copy the main index.html as a template
    cp /app/web/index.html "$output_file"

    # Add mobile install button if it doesn't exist
    if ! grep -q "mobile-install-button" "$output_file"; then
        echo "Adding mobile install button to $output_file"
        # Find the server toggle button and add the install button after it
        sed -i '/<!-- Mobile Server Toggle/,/<\/button>/ {
            /<\/button>/ a\
            <!-- Mobile Install Button (will be shown/hidden by JavaScript) -->\
            <button class="sort-button install-button mobile-install-button" style="display: none;">\
                <span class="install-icon">📱</span>\
                <span class="install-text">Install App</span>\
            </button>
        }' "$output_file"
    fi

    # Set the title immediately based on the route type
    if [[ "$output_file" == *"/plex/index.html" ]]; then
        # This is a Plex secondary route
        current_title=$(grep -o '<title>[^<]*</title>' "$output_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g')
        sed -i "s|<title>.*</title>|<title>$clean_title - Plex</title>|" "$output_file"
        echo "Set Plex secondary route title: $clean_title - Plex"
    elif [[ "$output_file" == *"/jellyfin/index.html" ]]; then
        # This is a Jellyfin secondary route
        current_title=$(grep -o '<title>[^<]*</title>' "$output_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g')
        sed -i "s|<title>.*</title>|<title>$clean_title - Jellyfin</title>|" "$output_file"
        echo "Set Jellyfin secondary route title: $clean_title - Jellyfin"
    fi

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

        # Create themed manifest and offline page based on primary server
        create_themed_manifest "$PRIMARY_SERVER" "$APP_TITLE"
        create_themed_offline "$PRIMARY_SERVER" "$APP_TITLE"

        # Create routes FIRST, before applying themes
        if [ "$PRIMARY_SERVER" = "plex" ]; then
            # Plex is primary, so create Jellyfin route only
            echo "Creating secondary server route: /jellyfin/"
            create_server_index "jellyfin" "data/jellyfin" "/app/web/jellyfin/index.html"
            # When viewing secondary Jellyfin, switch back to primary (root)
            update_server_toggle "/app/web/jellyfin/index.html" "Plex" "../" "true"
        else
            # Jellyfin is primary, so create Plex route only
            echo "Creating secondary server route: /plex/"
            create_server_index "plex" "data/plex" "/app/web/plex/index.html"
            # When viewing secondary Plex, switch back to primary (root)
            update_server_toggle "/app/web/plex/index.html" "Jellyfin" "../" "true"
        fi

        # NOW apply themes after routes are created
        if [ "$PRIMARY_SERVER" = "plex" ]; then
            # Main index shows Plex, so switch to Jellyfin (secondary)
            update_server_toggle "/app/web/index.html" "Jellyfin" "jellyfin" "false"
            # No theme application needed for main index - it's already Plex-themed
            # Apply Jellyfin theme to the secondary route
            apply_jellyfin_theme "/app/web/jellyfin/index.html"
        else
            # Main index shows Jellyfin, so switch to Plex (secondary)
            update_server_toggle "/app/web/index.html" "Plex" "plex" "false"
            # Apply Jellyfin theme to main index
            apply_jellyfin_theme "/app/web/index.html"
            # No theme application needed for Plex secondary route - it uses original styling
        fi
    else
        echo "Only one server configured - removing server toggle functionality"
        remove_server_toggle "/app/web/index.html"

        # Create themed manifest and offline page based on single server type
        create_themed_manifest "$PRIMARY_SERVER" "$APP_TITLE"
        create_themed_offline "$PRIMARY_SERVER" "$APP_TITLE"

        # Apply theme based on single server type
        if [ "$PRIMARY_SERVER" = "jellyfin" ]; then
            apply_jellyfin_theme "/app/web/index.html"
        else
            # No theme application needed - index.html is already Plex-themed
            echo "Plex is primary server - using default index.html styling"
        fi
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
