#!/bin/bash
set -e
# Check for required environment variables
if [ -z "$PLEX_URL" ] || [ -z "$PLEX_TOKEN" ]; then
    echo "Error: PLEX_URL and PLEX_TOKEN environment variables must be set"
    exit 1
fi
# Set default app title if not provided
APP_TITLE=${APP_TITLE:-"Glimpse"}
echo "Using application title: $APP_TITLE"
# Set default cron schedule if not provided
CRON_SCHEDULE=${CRON_SCHEDULE:-"0 */6 * * *"}
# Find Python path
PYTHON_PATH=$(which python)
echo "Python path: $PYTHON_PATH"
# Create the cron job with PATH and absolute path to Python
echo "PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin" > /etc/cron.d/plex-cron
echo "$CRON_SCHEDULE root cd /app && $PYTHON_PATH /app/scripts/plex_data_fetcher.py --url \"$PLEX_URL\" --token \"$PLEX_TOKEN\" --output /app/data >> /var/log/cron.log 2>&1" >> /etc/cron.d/plex-cron
# Apply cron job
crontab /etc/cron.d/plex-cron
# Update the app title in the HTML file
if [ -f /app/web/index.html ]; then
    echo "Updating app title to: $APP_TITLE"
    # Replace title tag content
    sed -i "s/<title>.*<\/title>/<title>$APP_TITLE<\/title>/" /app/web/index.html
    # Replace h1 content (preserve the logo icon span)
    sed -i "s/<h1>.*<\/h1>/<h1><span class=\"logo-icon\">🎬<\/span>$APP_TITLE<\/h1>/" /app/web/index.html
    echo "Title updated successfully"
else
    echo "Warning: index.html not found in /app/web/"
fi
# Ensure nginx configuration is correct
# Create a simple test page to check if nginx is serving from the correct directory
echo "<!DOCTYPE html><html><head><title>Nginx Test</title></head><body><h1>Nginx is working from /app/web!</h1></body></html>" > /app/web/test.html
# Run the initial data fetch
echo "Running initial data fetch..."
$PYTHON_PATH /app/scripts/plex_data_fetcher.py --url "$PLEX_URL" --token "$PLEX_TOKEN" --output /app/data
# Make sure the data directory is accessible by nginx
chown -R www-data:www-data /app/data
chown -R www-data:www-data /app/web
# Print debugging info
echo "Checking Nginx configurations:"
ls -la /etc/nginx/conf.d/
ls -la /etc/nginx/sites-enabled/ || echo "No sites-enabled directory"
echo "Checking web directory:"
ls -la /app/web/
# Start supervisor (which will start both nginx and cron)
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
