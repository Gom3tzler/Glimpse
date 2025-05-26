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
        elif [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
            echo "Warning: PRIMARY_SERVER set to 'plex' but only Emby credentials provided"
            echo "Auto-switching PRIMARY_SERVER to 'emby'"
            PRIMARY_SERVER="emby"
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
        elif [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
            echo "Warning: PRIMARY_SERVER set to 'jellyfin' but only Emby credentials provided"
            echo "Auto-switching PRIMARY_SERVER to 'emby'"
            PRIMARY_SERVER="emby"
        else
            echo "Error: PRIMARY_SERVER=jellyfin but no valid credentials provided for any server"
            exit 1
        fi
    fi
elif [ "$PRIMARY_SERVER" = "emby" ]; then
    if [ -z "$EMBY_URL" ] || [ -z "$EMBY_TOKEN" ]; then
        if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
            echo "Warning: PRIMARY_SERVER set to 'emby' but only Plex credentials provided"
            echo "Auto-switching PRIMARY_SERVER to 'plex'"
            PRIMARY_SERVER="plex"
        elif [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
            echo "Warning: PRIMARY_SERVER set to 'emby' but only Jellyfin credentials provided"
            echo "Auto-switching PRIMARY_SERVER to 'jellyfin'"
            PRIMARY_SERVER="jellyfin"
        else
            echo "Error: PRIMARY_SERVER=emby but no valid credentials provided for any server"
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
    elif [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
        echo "PRIMARY_SERVER not set or invalid, defaulting to 'emby' based on available credentials"
        PRIMARY_SERVER="emby"
    else
        echo "Error: No valid credentials provided for any media server"
        echo "Please set PLEX_URL/PLEX_TOKEN, JELLYFIN_URL/JELLYFIN_TOKEN, or EMBY_URL/EMBY_TOKEN"
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

if [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
    echo "$CRON_SCHEDULE root cd /app && $PYTHON_PATH /app/scripts/jellyfin_data_fetcher.py --url \"$EMBY_URL\" --token \"$EMBY_TOKEN\" --output /app/data/emby >> /var/log/cron.log 2>&1" >>/etc/cron.d/media-cron
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

# Create directory structure for all servers
mkdir -p /app/web/plex
mkdir -p /app/web/jellyfin
mkdir -p /app/web/emby

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
    elif [ "$server_type" = "emby" ]; then
        # Emby themed offline page
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
            background: linear-gradient(135deg, #0f1419 0%, #1a2332 50%, #0d1b2a 100%);
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
            color: #52c41a;
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
            filter: hue-rotate(100deg);
        }
        button {
            background: linear-gradient(135deg, #52c41a, #389e0d);
            color: #fff;
            border: none;
            padding: 12px 20px;
            border-radius: 24px;
            font-weight: bold;
            cursor: pointer;
            font-size: 16px;
            transition: all 0.3s;
            box-shadow: 0 4px 15px rgba(82, 196, 26, 0.3);
        }
        button:hover {
            background: linear-gradient(135deg, #389e0d, #237804);
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(82, 196, 26, 0.4);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📶</div>
        <h1>You're Offline</h1>
        <p>It looks like you're not connected to the internet. REPLACE_APP_TITLE needs a connection to show your Emby content.</p>
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
  "name": "Glimpse Media Viewer",
  "short_name": "Glimpse",
  "description": "A sleek, responsive web application for browsing your Plex/Jellyfin/Emby media server",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#101010",
  "theme_color": "#101010",
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
    elif [ "$server_type" = "emby" ]; then
        # Emby themed manifest
        cat >/app/web/manifest.json <<EOF
{
  "name": "Glimpse Media Viewer",
  "short_name": "Glimpse",
  "description": "A sleek, responsive web application for browsing your Plex/Jellyfin/Emby media server",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0f1419",
  "theme_color": "#0f1419",
  "orientation": "any",
  "icons": [
    {
      "src": "/images/emby/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/images/emby/android-chrome-512x512.png",
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
  "name": "Glimpse Media Viewer",
  "short_name": "Glimpse",
  "description": "A sleek, responsive web application for browsing your Plex/Jellyfin/Emby media server",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#131313",
  "theme_color": "#131313",
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
            sed -i 's/<meta name="theme-color" content="[^"]*">/<meta name="theme-color" content="#101010">/' /app/web/index.html
        elif [ "$server_type" = "emby" ]; then
            sed -i 's/<meta name="theme-color" content="[^"]*">/<meta name="theme-color" content="#0f1419">/' /app/web/index.html
        else
            sed -i 's/<meta name="theme-color" content="[^"]*">/<meta name="theme-color" content="#131313">/' /app/web/index.html
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

    # Update title for main index files (primary server gets indicator too)
    if [[ "$index_file" == "/app/web/index.html" ]]; then
        # This is the main index, add Jellyfin indicator
        current_title=$(grep -o '<title>[^<]*</title>' "$index_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g' | sed 's/ - Emby//g')
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

EOF

    # Insert Jellyfin theme CSS after the existing styles but before closing </style>
    sed -i '/<\/style>/e cat /tmp/jellyfin_theme.css' "$index_file"

    # Clean up temporary file
    rm -f /tmp/jellyfin_theme.css
}

apply_emby_theme() {
    local index_file=$1
    echo "Applying Emby theme to $index_file"

    # Update image paths to point to emby directory
    echo "Updating image paths to use emby directory"

    # Update logo image path - be specific to avoid double replacement
    sed -i 's|src="images/logo\.png"|src="images/emby/logo.png"|g' "$index_file"
    sed -i 's|src="../images/logo\.png"|src="../images/emby/logo.png"|g' "$index_file"

    # Update specific favicon and meta tag images
    sed -i 's|href="images/android-chrome-192x192\.png"|href="images/emby/android-chrome-192x192.png"|g' "$index_file"
    sed -i 's|href="/images/android-chrome-192x192\.png"|href="/images/emby/android-chrome-192x192.png"|g' "$index_file"
    sed -i 's|href="../images/android-chrome-192x192\.png"|href="../images/emby/android-chrome-192x192.png"|g' "$index_file"

    sed -i 's|href="images/android-chrome-592x592\.png"|href="images/emby/android-chrome-592x592.png"|g' "$index_file"
    sed -i 's|href="/images/android-chrome-592x592\.png"|href="/images/emby/android-chrome-592x592.png"|g' "$index_file"
    sed -i 's|href="../images/android-chrome-592x592\.png"|href="../images/emby/android-chrome-592x592.png"|g' "$index_file"

    sed -i 's|href="images/apple-touch-icon\.png"|href="images/emby/apple-touch-icon.png"|g' "$index_file"
    sed -i 's|href="../images/apple-touch-icon\.png"|href="../images/emby/apple-touch-icon.png"|g' "$index_file"

    sed -i 's|href="images/favicon-32x32\.png"|href="images/emby/favicon-32x32.png"|g' "$index_file"
    sed -i 's|href="../images/favicon-32x32\.png"|href="../images/emby/favicon-32x32.png"|g' "$index_file"

    sed -i 's|href="images/favicon-16x16\.png"|href="images/emby/favicon-16x16.png"|g' "$index_file"
    sed -i 's|href="../images/favicon-16x16\.png"|href="../images/emby/favicon-16x16.png"|g' "$index_file"

    # Update title for main index files (primary server gets indicator too)
    if [[ "$index_file" == "/app/web/index.html" ]]; then
        # This is the main index, add Emby indicator
        current_title=$(grep -o '<title>[^<]*</title>' "$index_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g' | sed 's/ - Emby//g')
        sed -i "s|<title>.*</title>|<title>$clean_title - Emby</title>|" "$index_file"
        echo "Updated main index title to: $clean_title - Emby"
    fi

    # Create temporary file with Emby CSS overrides
    cat >/tmp/emby_theme.css <<'EOF'

        /* Emby Theme Overrides */
        :root {
            --primary-color: #52c41a !important;
            --primary-hover: #389e0d !important;
            --primary-light: rgba(82, 196, 26, 0.1) !important;
            --bg-color: #0f1419 !important;
            --secondary-bg: #1a2332 !important;
            --header-bg: #162029 !important;
            --tab-bg: #2a3441 !important;
        }
        
        /* Ensure full screen coverage without affecting layout */
        html {
            min-height: 100vh;
        }
        
        /* Emby gradient background */
        body {
            background: linear-gradient(135deg, #0f1419 0%, #1a2332 50%, #0d1b2a 100%) !important;
            background-attachment: fixed !important;
            background-size: cover !important;
            background-repeat: no-repeat !important;
            min-height: 100vh;
        }
        
        /* Emby accent color for active elements */
        .tab.active,
        .sort-button.active,
        .genre-button.active {
            background: linear-gradient(135deg, #52c41a, #389e0d) !important;
            color: white !important;
        }
        
        /* Emby hover effects */
        .tab:hover:not(.active),
        .sort-button:hover:not(.active),
        .genre-button:hover:not(.active),
        .server-toggle-button:hover,
        .roulette-button:hover,
        .modal-try-again-btn:hover {
            background-color: rgba(82, 196, 26, 0.2) !important;
        }
        
        /* Emby media item hover - no glow, better contrast */
        .media-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2) !important;
        }
        
        /* Emby poster container - better contrast against dark background */
        .media-item {
            background-color: #2a3441 !important;
        }
        
        /* Emby scroll indicators */
        .scroll-to-top {
            background: linear-gradient(135deg, #52c41a, #389e0d) !important;
            color: #ffffff !important;
        }
        
        .scroll-to-top:hover {
            background: linear-gradient(135deg, #389e0d, #237804) !important;
        }

EOF

    # Insert Emby theme CSS after the existing styles but before closing </style>
    sed -i '/<\/style>/e cat /tmp/emby_theme.css' "$index_file"

    # Clean up temporary file
    rm -f /tmp/emby_theme.css
}

remove_server_toggle() {
    local index_file=$1
    echo "Hiding server toggle from $index_file (single server mode)"

    # Instead of removing HTML/JavaScript (which can cause syntax errors),
    # just hide the server toggle elements with CSS and make the function safe

    # Add CSS to hide server toggle elements
    cat >>"$index_file" <<'EOF'
<style>
/* Hide server toggle in single server mode */
.server-toggle,
.server-toggle-button,
.server-dropdown {
    display: none !important;
    visibility: hidden !important;
}
</style>

<script>
// Override toggleServer function to be safe in single server mode
if (typeof toggleServer !== 'undefined') {
    window.toggleServer = function() {
        console.log("Server toggle disabled - only one server configured");
        return false;
    };
} else {
    window.toggleServer = function() {
        console.log("Server toggle disabled - only one server configured");
        return false;
    };
}
</script>
EOF
}

# Function to create index.html for a specific server
create_server_index() {
    local server_type=$1
    local data_path=$2
    local output_file=$3

    echo "Creating server index for $server_type at $output_file"

    # Copy the main index.html as a template
    cp /app/web/index.html "$output_file"

    # Set the title immediately based on the route type
    if [[ "$output_file" == *"/plex/index.html" ]]; then
        # This is a Plex secondary route
        current_title=$(grep -o '<title>[^<]*</title>' "$output_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g' | sed 's/ - Emby//g')
        sed -i "s|<title>.*</title>|<title>$clean_title - Plex</title>|" "$output_file"
        echo "Set Plex secondary route title: $clean_title - Plex"
    elif [[ "$output_file" == *"/jellyfin/index.html" ]]; then
        # This is a Jellyfin secondary route
        current_title=$(grep -o '<title>[^<]*</title>' "$output_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g' | sed 's/ - Emby//g')
        sed -i "s|<title>.*</title>|<title>$clean_title - Jellyfin</title>|" "$output_file"
        echo "Set Jellyfin secondary route title: $clean_title - Jellyfin"
    elif [[ "$output_file" == *"/emby/index.html" ]]; then
        # This is an Emby secondary route
        current_title=$(grep -o '<title>[^<]*</title>' "$output_file" | sed 's/<title>\(.*\)<\/title>/\1/')
        clean_title=$(echo "$current_title" | sed 's/ - Jellyfin//g' | sed 's/ - Plex//g' | sed 's/ - Emby//g')
        sed -i "s|<title>.*</title>|<title>$clean_title - Emby</title>|" "$output_file"
        echo "Set Emby secondary route title: $clean_title - Emby"
    fi

    # For sub-directory routes, we need to use relative paths from the sub-directory
    if [ "$output_file" != "/app/web/index.html" ]; then
        # Reset any existing server-specific paths first
        sed -i "s|data/jellyfin/movies\.json|data/movies.json|g" "$output_file"
        sed -i "s|data/jellyfin/tvshows\.json|data/tvshows.json|g" "$output_file"
        sed -i "s|data/jellyfin/posters/|data/posters/|g" "$output_file"
        sed -i "s|data/jellyfin/backdrops/|data/backdrops/|g" "$output_file"
        sed -i "s|data/plex/movies\.json|data/movies.json|g" "$output_file"
        sed -i "s|data/plex/tvshows\.json|data/tvshows.json|g" "$output_file"
        sed -i "s|data/plex/posters/|data/posters/|g" "$output_file"
        sed -i "s|data/plex/backdrops/|data/backdrops/|g" "$output_file"
        sed -i "s|data/emby/movies\.json|data/movies.json|g" "$output_file"
        sed -i "s|data/emby/tvshows\.json|data/tvshows.json|g" "$output_file"
        sed -i "s|data/emby/posters/|data/posters/|g" "$output_file"
        sed -i "s|data/emby/backdrops/|data/backdrops/|g" "$output_file"

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

# Function to count configured servers
count_configured_servers() {
    local count=0

    if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
        count=$((count + 1))
    fi

    if [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
        count=$((count + 1))
    fi

    if [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
        count=$((count + 1))
    fi

    echo $count
}

# Function to configure multi-server dropdown (for 2+ servers)
configure_multi_server_dropdown() {
    echo "Configuring multi-server dropdown system for 2+ servers"

    # Create routes for all secondary servers
    if [ "$PRIMARY_SERVER" != "plex" ] && [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
        create_server_index "plex" "data/plex" "/app/web/plex/index.html"
    fi
    if [ "$PRIMARY_SERVER" != "jellyfin" ] && [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
        create_server_index "jellyfin" "data/jellyfin" "/app/web/jellyfin/index.html"
    fi
    if [ "$PRIMARY_SERVER" != "emby" ] && [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
        create_server_index "emby" "data/emby" "/app/web/emby/index.html"
    fi

    # Replace toggle button with dropdown for all routes
    replace_toggle_with_dropdown "/app/web/index.html" "$PRIMARY_SERVER"

    if [ -f "/app/web/plex/index.html" ]; then
        replace_toggle_with_dropdown "/app/web/plex/index.html" "plex"
    fi
    if [ -f "/app/web/jellyfin/index.html" ]; then
        replace_toggle_with_dropdown "/app/web/jellyfin/index.html" "jellyfin"
    fi
    if [ -f "/app/web/emby/index.html" ]; then
        replace_toggle_with_dropdown "/app/web/emby/index.html" "emby"
    fi
}

# Function to replace toggle button with dropdown
replace_toggle_with_dropdown() {
    local index_file=$1
    local current_server=$2

    echo "Replacing toggle button with dropdown in $index_file (current: $current_server)"

    # Build dropdown options
    local dropdown_options=""
    local current_path=""

    # Determine current path based on file location
    if [[ "$index_file" == "/app/web/index.html" ]]; then
        current_path="/"
    elif [[ "$index_file" == *"/plex/index.html" ]]; then
        current_path="/plex/"
    elif [[ "$index_file" == *"/jellyfin/index.html" ]]; then
        current_path="/jellyfin/"
    elif [[ "$index_file" == *"/emby/index.html" ]]; then
        current_path="/emby/"
    fi

    # Add options for all configured servers
    if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
        local plex_path="/"
        local plex_relative_path=""

        if [ "$PRIMARY_SERVER" = "plex" ]; then
            plex_path="/"
            if [[ "$index_file" == "/app/web/index.html" ]]; then
                plex_relative_path="/"
            else
                plex_relative_path="../"
            fi
        else
            plex_path="/plex/"
            if [[ "$index_file" == "/app/web/index.html" ]]; then
                plex_relative_path="plex/"
            else
                plex_relative_path="../plex/"
            fi
        fi

        local plex_selected=""
        if [ "$current_server" = "plex" ]; then
            plex_selected=" selected disabled"
        fi

        dropdown_options="$dropdown_options<option value=\"$plex_relative_path\"$plex_selected>📺 Plex</option>"
    fi

    if [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
        local jellyfin_path="/"
        local jellyfin_relative_path=""

        if [ "$PRIMARY_SERVER" = "jellyfin" ]; then
            jellyfin_path="/"
            if [[ "$index_file" == "/app/web/index.html" ]]; then
                jellyfin_relative_path="/"
            else
                jellyfin_relative_path="../"
            fi
        else
            jellyfin_path="/jellyfin/"
            if [[ "$index_file" == "/app/web/index.html" ]]; then
                jellyfin_relative_path="jellyfin/"
            else
                jellyfin_relative_path="../jellyfin/"
            fi
        fi

        local jellyfin_selected=""
        if [ "$current_server" = "jellyfin" ]; then
            jellyfin_selected=" selected disabled"
        fi

        dropdown_options="$dropdown_options<option value=\"$jellyfin_relative_path\"$jellyfin_selected>🌊 Jellyfin</option>"
    fi

    if [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
        local emby_path="/"
        local emby_relative_path=""

        if [ "$PRIMARY_SERVER" = "emby" ]; then
            emby_path="/"
            if [[ "$index_file" == "/app/web/index.html" ]]; then
                emby_relative_path="/"
            else
                emby_relative_path="../"
            fi
        else
            emby_path="/emby/"
            if [[ "$index_file" == "/app/web/index.html" ]]; then
                emby_relative_path="emby/"
            else
                emby_relative_path="../emby/"
            fi
        fi

        local emby_selected=""
        if [ "$current_server" = "emby" ]; then
            emby_selected=" selected disabled"
        fi

        dropdown_options="$dropdown_options<option value=\"$emby_relative_path\"$emby_selected>🟢 Emby</option>"
    fi

    # Create the dropdown HTML and JavaScript
    cat >>"$index_file" <<EOF

<style>
/* Server Dropdown Styles */
.server-dropdown {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-left: 15px;
}

.server-dropdown select {
    background-color: var(--tab-bg);
    color: var(--light-text);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 20px;
    padding: 6px 12px;
    font-weight: 500;
    font-size: 0.9rem;
    cursor: pointer;
    transition: all var(--transition-speed);
    outline: none;
    appearance: none;
    background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%23ffffff' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
    background-position: right 8px center;
    background-repeat: no-repeat;
    background-size: 16px;
    padding-right: 32px;
    min-width: 120px;
}

.server-dropdown select:hover {
    background-color: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.2);
}

.server-dropdown select:focus {
    box-shadow: 0 0 0 2px var(--primary-color);
    border-color: var(--primary-color);
}

.server-dropdown option {
    background-color: var(--secondary-bg);
    color: var(--light-text);
    padding: 8px 12px;
}

.server-dropdown option:disabled {
    color: var(--primary-color);
    font-weight: 600;
}

/* Mobile styles */
@media screen and (max-width: 768px) {
    .server-dropdown {
        margin-left: 10px;
    }
    
    .server-dropdown select {
        min-width: 100px;
        font-size: 0.85rem;
        padding: 6px 8px;
        padding-right: 28px;
    }
    
    /* Mobile menu dropdown */
    .mobile-menu .server-dropdown {
        width: 100%;
        margin-left: 0;
        margin-top: 10px;
    }
    
    .mobile-menu .server-dropdown select {
        width: 100%;
        min-width: unset;
        padding: 10px 12px;
        padding-right: 32px;
        font-size: 0.9rem;
    }
}
</style>

<script>
// Replace existing server toggle functionality with dropdown
document.addEventListener('DOMContentLoaded', function() {
    // Hide existing toggle buttons
    const toggleButtons = document.querySelectorAll('.server-toggle-button');
    toggleButtons.forEach(button => {
        button.style.display = 'none';
    });
    
    // Create dropdown for desktop
    const serverToggle = document.querySelector('.server-toggle');
    if (serverToggle) {
        serverToggle.innerHTML = \`
            <div class="server-dropdown">
                <select onchange="switchServer(this.value)">
                    <option value="" disabled>Switch Server</option>
                    $dropdown_options
                </select>
            </div>
        \`;
    }
    
    // Create dropdown for mobile menu
    const mobileMenu = document.querySelector('.mobile-menu');
    if (mobileMenu) {
        // Find the server toggle button in mobile menu and replace it
        const mobileToggleButton = mobileMenu.querySelector('.server-toggle-button');
        if (mobileToggleButton) {
            mobileToggleButton.style.display = 'none';
            
            // Add dropdown after the genre button
            const genreButton = mobileMenu.querySelector('#mobile-genre-button');
            if (genreButton) {
                const mobileDropdownHtml = \`
                    <div class="server-dropdown">
                        <select onchange="switchServer(this.value); document.querySelector('.mobile-menu').classList.remove('open');">
                            <option value="" disabled>Switch Server</option>
                            $dropdown_options
                        </select>
                    </div>
                \`;
                genreButton.insertAdjacentHTML('afterend', mobileDropdownHtml);
            }
        }
    }
});

// Function to handle server switching
function switchServer(path) {
    if (path && path !== '/') {
        // Clear themed cache before switching
        if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
            try {
                const messageChannel = new MessageChannel();
                navigator.serviceWorker.controller.postMessage(
                    { type: 'CLEAR_THEMED_CACHE' },
                    [messageChannel.port2]
                );
            } catch (error) {
                console.log('Could not clear service worker cache:', error);
            }
        }
        
        window.location.href = path;
    }
}

// Override the old toggleServer function to prevent errors
window.toggleServer = function() {
    console.log("Using dropdown instead of toggle");
    return false;
};
</script>
EOF
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

        # Update title to include Plex indicator
        sed -i "s/<title>$APP_TITLE<\/title>/<title>$APP_TITLE - Plex<\/title>/" /app/web/index.html
        echo "Updated primary index title to: $APP_TITLE - Plex"

    elif [ "$PRIMARY_SERVER" = "jellyfin" ]; then
        echo "Setting up primary server as Jellyfin"
        # Main index.html points to jellyfin data
        sed -i "s|'data/movies\.json'|'data/jellyfin/movies.json'|g" /app/web/index.html
        sed -i "s|\"data/movies\.json\"|\"data/jellyfin/movies.json\"|g" /app/web/index.html
        sed -i "s|'data/tvshows\.json'|'data/jellyfin/tvshows.json'|g" /app/web/index.html
        sed -i "s|\"data/tvshows\.json\"|\"data/jellyfin/tvshows.json\"|g" /app/web/index.html
        sed -i "s|data/posters/|data/jellyfin/posters/|g" /app/web/index.html
        sed -i "s|data/backdrops/|data/jellyfin/backdrops/|g" /app/web/index.html

        # Update title to include Jellyfin indicator
        sed -i "s/<title>$APP_TITLE<\/title>/<title>$APP_TITLE - Jellyfin<\/title>/" /app/web/index.html
        echo "Updated primary index title to: $APP_TITLE - Jellyfin"

    else # emby
        echo "Setting up primary server as Emby"
        # Main index.html points to emby data
        sed -i "s|'data/movies\.json'|'data/emby/movies.json'|g" /app/web/index.html
        sed -i "s|\"data/movies\.json\"|\"data/emby/movies.json\"|g" /app/web/index.html
        sed -i "s|'data/tvshows\.json'|'data/emby/tvshows.json'|g" /app/web/index.html
        sed -i "s|\"data/tvshows\.json\"|\"data/emby/tvshows.json\"|g" /app/web/index.html
        sed -i "s|data/posters/|data/emby/posters/|g" /app/web/index.html
        sed -i "s|data/backdrops/|data/emby/backdrops/|g" /app/web/index.html

        # Update title to include Emby indicator
        sed -i "s/<title>$APP_TITLE<\/title>/<title>$APP_TITLE - Emby<\/title>/" /app/web/index.html
        echo "Updated primary index title to: $APP_TITLE - Emby"
    fi

    # Handle server toggle based on configuration
    server_count=$(count_configured_servers)
    echo "Number of configured servers: $server_count"

    if [ "$server_count" -eq 1 ]; then
        echo "Only one server configured - removing server toggle functionality"
        remove_server_toggle "/app/web/index.html"

        # Add server name to title for single server mode too
        current_title=$(grep -o '<title>[^<]*</title>' /app/web/index.html | sed 's/<title>\(.*\)<\/title>/\1/')
        if [[ "$current_title" != *" - "* ]]; then
            # Only add server name if it's not already there
            if [ "$PRIMARY_SERVER" = "plex" ]; then
                sed -i "s/<title>$current_title<\/title>/<title>$current_title - Plex<\/title>/" /app/web/index.html
                echo "Updated single server title to: $current_title - Plex"
            elif [ "$PRIMARY_SERVER" = "jellyfin" ]; then
                sed -i "s/<title>$current_title<\/title>/<title>$current_title - Jellyfin<\/title>/" /app/web/index.html
                echo "Updated single server title to: $current_title - Jellyfin"
            elif [ "$PRIMARY_SERVER" = "emby" ]; then
                sed -i "s/<title>$current_title<\/title>/<title>$current_title - Emby<\/title>/" /app/web/index.html
                echo "Updated single server title to: $current_title - Emby"
            fi
        fi

        # Create themed manifest and offline page based on single server type
        create_themed_manifest "$PRIMARY_SERVER" "$APP_TITLE"
        create_themed_offline "$PRIMARY_SERVER" "$APP_TITLE"

        # Apply theme based on single server type
        if [ "$PRIMARY_SERVER" = "jellyfin" ]; then
            apply_jellyfin_theme "/app/web/index.html"
        elif [ "$PRIMARY_SERVER" = "emby" ]; then
            apply_emby_theme "/app/web/index.html"
        else
            # No theme application needed - index.html is already Plex-themed
            echo "Plex is primary server - using default index.html styling"
        fi
    else
        echo "Multiple servers configured - setting up server dropdown functionality"

        # Create themed manifest and offline page based on primary server
        create_themed_manifest "$PRIMARY_SERVER" "$APP_TITLE"
        create_themed_offline "$PRIMARY_SERVER" "$APP_TITLE"

        # Use dropdown for 2+ servers (simplified logic)
        echo "Using dropdown menu for $server_count servers"
        configure_multi_server_dropdown

        # NOW apply themes after routes are created
        echo "Applying themes to all routes..."

        # Apply theme to main index based on primary server
        if [ "$PRIMARY_SERVER" = "jellyfin" ]; then
            apply_jellyfin_theme "/app/web/index.html"
        elif [ "$PRIMARY_SERVER" = "emby" ]; then
            apply_emby_theme "/app/web/index.html"
        fi
        # Plex primary needs no theme - it's the default

        # Apply themes to all secondary routes
        if [ -f "/app/web/plex/index.html" ]; then
            echo "Plex secondary route uses default styling"
        fi

        if [ -f "/app/web/jellyfin/index.html" ]; then
            apply_jellyfin_theme "/app/web/jellyfin/index.html"
        fi

        if [ -f "/app/web/emby/index.html" ]; then
            apply_emby_theme "/app/web/emby/index.html"
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

# Fetch Emby data if configured (using jellyfin fetcher since APIs are compatible)
if [ -n "$EMBY_URL" ] && [ -n "$EMBY_TOKEN" ]; then
    echo "Fetching Emby data using Jellyfin API compatibility"
    $PYTHON_PATH /app/scripts/jellyfin_data_fetcher.py --url "$EMBY_URL" --token "$EMBY_TOKEN" --output /app/data/emby
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
echo "Configured servers: $(count_configured_servers)"

# Start supervisor (which will start both nginx and cron)
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
