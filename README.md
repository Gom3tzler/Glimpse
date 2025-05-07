# 🎬 Glimpse Media Viewer

A sleek, responsive web application for browsing and viewing your Plex media library content. This dockerized solution fetches metadata and artwork from your Plex server and presents it in an elegant, user-friendly interface.

![Plex Media Viewer Screenshot](https://user-images.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/screenshots/screenshot.png)

## ✨ Features

- **Modern Interface**: Clean, responsive design that works on mobile and desktop
- **Library Browsing**: View your movies and TV shows with poster art
- **Search Capability**: Quickly find content across your libraries
- **Detailed View**: See cast information, genres, and descriptions
- **Multiple Libraries**: Support for multiple Plex libraries of the same type
- **MD5 Checksum Verification**: Only downloads images when they've changed
- **Dockerized**: Easy deployment with Docker and Docker Compose
- **Customizable**: Configure update schedule, app title, and more

## 🔧 Prerequisites

- Docker and Docker Compose installed on your host system
- A running Plex Media Server
- Plex authentication token
- Basic knowledge of Docker and containerization

## 🚀 Quick Start

### Option 1: Pull from Docker Hub (Recommended)

```bash
# Create a directory for your data
mkdir -p Glimpse/data

# Create a docker-compose.yml file
curl -o Glimpse/docker-compose.yml https://raw.githubusercontent.com/jeremehancock/Glimpse/main/docker-compose.yml

# Edit the docker-compose.yml file to set your Plex server details
cd Glimpse
nano docker-compose.yml

# Start the container
docker-compose up -d
```

### Option 2: Build from Source

```bash
git clone https://github.com/jeremehancock/Glimpse.git
cd Glimpse
```

### 2. Configure Docker Compose

Edit `docker-compose.yml` to set your Plex server details:

```yaml
environment:
  - PLEX_URL=http://your-plex-server:32400
  - PLEX_TOKEN=your-plex-token
  - CRON_SCHEDULE=0 */6 * * *  # Update every 6 hours
  - TZ=UTC                     # Your timezone
  - APP_TITLE=My Plex Library  # Custom app title
```

### 3. Start the Container

```bash
docker-compose up -d
```

### 4. Access the Web Interface

Open your browser and navigate to:

```
http://your-server:9090
```

## ⚙️ Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PLEX_URL` | URL of your Plex server | *Required* |
| `PLEX_TOKEN` | Authentication token for Plex | *Required* |
| `CRON_SCHEDULE` | When to update data (cron format) | `0 */6 * * *` (every 6 hours) |
| `TZ` | Timezone for scheduled tasks | `UTC` |
| `APP_TITLE` | Custom title for the application | `Glimpse` |

### Finding Your Plex Token

Several methods exist to find your Plex token:
1. [Official Plex support article](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)
2. Using the Plex Web app (inspect network requests)
3. Using third-party scripts like [Plex Token](https://github.com/jbzdarkid/plex-token)

## 🏗️ Project Structure

```
plex-media-viewer/
│
├── docker-compose.yml        # Docker Compose configuration
├── Dockerfile                # Docker build configuration
│
├── scripts/
│   └── plex_data_fetcher.py  # Python script to fetch Plex data
│
├── web/
│   └── index.html            # Frontend web interface
│
├── config/
│   ├── entrypoint.sh         # Container entrypoint script
│   ├── nginx.conf            # Nginx configuration
│   └── supervisord.conf      # Supervisor configuration
│
└── data/                     # Persistent data directory
    ├── movies.json           # Movie metadata
    ├── tvshows.json          # TV show metadata
    ├── checksums.pkl         # MD5 checksums for media artwork
    ├── posters/
    └── backdrops/
```

## 🔄 How It Works

1. **Data Fetching**: The Python script connects to your Plex server using the provided token and fetches metadata for all movies and TV shows.
2. **Image Processing**: Media posters and backdrops are downloaded, with MD5 checksums to avoid re-downloading unchanged files.
3. **Web Server**: Nginx serves the static web interface and the downloaded data.
4. **Scheduled Updates**: Cron runs the data fetcher on the configured schedule to keep content up-to-date.
5. **Persistence**: All data is stored in a volume mapped to your host, ensuring it persists between container restarts.

## 🌐 Customization

### Changing the Update Schedule

Modify the `CRON_SCHEDULE` environment variable in your `docker-compose.yml`:

```yaml
- CRON_SCHEDULE=0 0 * * *  # Once a day at midnight
```

Common cron patterns:
- `0 */6 * * *` - Every 6 hours
- `0 0 * * *` - Daily at midnight
- `0 0 * * 0` - Weekly on Sunday
- `*/30 * * * *` - Every 30 minutes

### Changing the Port

Modify the `ports` section in `docker-compose.yml`:

```yaml
ports:
  - "8080:80"  # Change to your desired port
```

### Customizing the App Title

Set the `APP_TITLE` environment variable:

```yaml
- APP_TITLE=My Movie Collection
```

## 🔍 Troubleshooting

### Viewing Logs

```bash
# View all container logs
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# View specific service logs
docker-compose logs plex-viewer
```

### Manual Data Update

To trigger a data update manually:

```bash
docker exec plex-viewer python /app/scripts/plex_data_fetcher.py --url "$PLEX_URL" --token "$PLEX_TOKEN" --output /app/data
```

### Common Issues

#### Default Nginx Page Shows Instead of the App

If you see the default Nginx welcome page, there might be an issue with the configuration:

```bash
# Check if the app files are present
docker exec plex-viewer ls -la /app/web

# Check Nginx configuration
docker exec plex-viewer cat /etc/nginx/conf.d/default.conf

# Restart Nginx
docker exec plex-viewer nginx -s reload
```

#### Missing Images

If media images aren't displaying:

1. Check permissions on the data directory
2. Ensure the Plex server is accessible from the container
3. Verify your Plex token is valid

## 🛠️ Advanced Usage

### Using Behind a Reverse Proxy

This application works well behind a reverse proxy like Traefik or Nginx Proxy Manager. Just expose the container port and configure your proxy accordingly.

## 🔐 Security Considerations

- The Plex token provides access to your Plex server. Keep it secure.
- All data is read-only, so there's no risk of modifying your Plex library.

## 📝 License

This project is released under the MIT License. See the `LICENSE` file for details.

## AI Assistance Disclosure

This tool was developed with assistance from AI language models.
