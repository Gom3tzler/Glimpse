FROM python:3.9-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    cron \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install requests

# Set up directories
RUN mkdir -p /app/web /app/data /app/scripts

# Copy Python script
COPY scripts/plex_data_fetcher.py /app/scripts/
RUN chmod +x /app/scripts/plex_data_fetcher.py

# Copy web files
COPY web/ /app/web/

# Remove default Nginx configuration and add our custom one
RUN rm -f /etc/nginx/sites-enabled/default
COPY config/nginx.conf /etc/nginx/conf.d/default.conf
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Create empty crontab file
RUN touch /etc/cron.d/plex-cron
RUN chmod 0644 /etc/cron.d/plex-cron

# Create symlink to the data directory
RUN ln -s /app/data /app/web/data

WORKDIR /app

# Expose port for the web server
EXPOSE 80

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
