#!/bin/bash
set -e

# Set default primary server
PRIMARY_SERVER=${PRIMARY_SERVER:-"plex"}

# Check for required environment variables based on primary server
if [ "$PRIMARY_SERVER" = "plex" ]; then
    if [ -z "$PLEX_URL" ] || [ -z "$PLEX_TOKEN" ]; then
        echo "Error: PLEX_URL and PLEX_TOKEN environment variables must be set when PRIMARY_SERVER=plex"
        exit 1
    fi
elif [ "$PRIMARY_SERVER" = "jellyfin" ]; then
    if [ -z "$JELLYFIN_URL" ] || [ -z "$JELLYFIN_TOKEN" ]; then
        echo "Error: JELLYFIN_URL and JELLYFIN_TOKEN environment variables must be set when PRIMARY_SERVER=jellyfin"
        exit 1
    fi
else
    echo "Error: PRIMARY_SERVER must be either 'plex' or 'jellyfin'"
    exit 1
fi

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

    # Create secondary server index files - always point to their specific directories
    # Plex route always points to data/plex/
    if [ -n "$PLEX_URL" ] && [ -n "$PLEX_TOKEN" ]; then
        create_server_index "plex" "data/plex" "/app/web/plex/index.html"
    fi

    # Jellyfin route always points to data/jellyfin/
    if [ -n "$JELLYFIN_URL" ] && [ -n "$JELLYFIN_TOKEN" ]; then
        create_server_index "jellyfin" "data/jellyfin" "/app/web/jellyfin/index.html"
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
