# 🎬 Glimpse Media Viewer

A sleek, responsive web application for browsing and viewing your Plex media library content. This dockerized solution fetches metadata and artwork from your Plex server and presents it in an elegant, user-friendly interface.

![Glimpse Media Viewer Screenshot](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/screenshot-main-updated-3.png)

![Glimpse Media Viewer Screenshot](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/screenshot-details-updated-3.png)

## ✨ Features

- **Modern Interface**: Clean, responsive design that works on mobile and desktop
- **Media Browsing**: View your Movies and TV Shows with poster art
- **Search Capability**: Quickly find content across your libraries
- **Detailed View**: See cast information, genres, and descriptions
- **Watch Movie Trailers**: Preview content directly from the interface
- **Random Content Selection**: "Roll the Dice" feature for discovering random Movies or TV Shows
- **Genre Filters**: Easily filter media by genre
- **Sort A–Z / Z–A**: Alphabetical sorting
- **Sort by Date Added (Ascending / Descending)**: Sort media by when it was added
- **MD5 Checksum Verification**: Only downloads images when they've changed
- **Dockerized**: Easy deployment with Docker and Docker Compose
- **Customizable**: Configure update schedule, app title, and more
- **Installable as PWA**: Access your media library like a native app on any device

## ❤️ Support this project

[![Donate](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/donate-button.png)](https://www.buymeacoffee.com/jeremehancock)

## 🔧 Prerequisites

- Docker and Docker Compose installed on your host system
- A running Plex Media Server
- Plex authentication token
- Basic knowledge of Docker and containerization

## 🚀 Installation

### 1: Grab Docker Compose

Create a directory for your data

```bash
mkdir -p Glimpse/data
```

Create a docker-compose.yml file

```bash
curl -o Glimpse/docker-compose.yml https://raw.githubusercontent.com/jeremehancock/Glimpse/main/docker-compose.yml
```

Change to Glimpse directory

```bash
cd Glimpse
```

### 2. Configure Docker Compose

Edit `docker-compose.yml` to set your Plex server details:

```yaml
environment:
  - PLEX_URL=http://your-plex-server:32400
  - PLEX_TOKEN=your-plex-token
  - CRON_SCHEDULE=0 */6 * * * # Update every 6 hours
  - TZ=UTC # Your timezone
  - APP_TITLE=Glimpse # Custom app title
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

| Variable        | Description                       | Default                       |
| --------------- | --------------------------------- | ----------------------------- |
| `PLEX_URL`      | URL of your Plex server           | _Required_                    |
| `PLEX_TOKEN`    | Authentication token for Plex     | _Required_                    |
| `CRON_SCHEDULE` | When to update data (cron format) | `0 */6 * * *` (every 6 hours) |
| `TZ`            | Timezone for scheduled tasks      | `UTC`                         |
| `APP_TITLE`     | Custom title for the application  | `Glimpse`                     |

### Finding Your Plex Token

You can find your Plex authentication token (X-Plex-Token) by following these steps:

Log in to your Plex Web App
Browse to any media item
Click the 3 dots menu and select "Get Info"
In the info dialog, click "View XML"
In the URL of the new tab, find the "X-Plex-Token=" parameter
For more detailed instructions, visit the [Plex support article](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).

## 🏗️ Project Structure

```
glimpse-media-viewer/
│
├── docker-compose.yml        # Docker Compose configuration
├── Dockerfile                # Docker build configuration
│
├── scripts/
│   └── plex_data_fetcher.py  # Python script to fetch Plex data
│
├── web/
│   ├── index.html            # Frontend web interface
│   ├── manifest.json         # PWA manifest file
│   ├── sw.js                 # Service worker for PWA functionality
│   ├── offline.html          # Offline fallback page
│   └── images/               # Icons and images
│       ├── icon.png          # Original app icon
│       ├── android-chrome-192x192.png  # App icon (192×192)
│       ├── android-chrome-512x512.png  # App icon (512×512)
│       ├── apple-touch-icon.png        # Apple Touch icon (180x180)
│       ├── favicon.ico                 # Favicon
│       ├── favicon-16x16.png           # Favicon (16x16)
│       └── favicon-32x32.png           # Favicon (32x32)
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
    ├── posters/              # Movie and TV show posters
    │   ├── movies/           # Movie poster images
    │   └── tvshows/          # TV show poster images
    └── backdrops/            # Movie and TV show backgrounds
        ├── movies/           # Movie backdrop images
        └── tvshows/          # TV show backdrop images
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
- CRON_SCHEDULE=0 0 * * * # Once a day at midnight
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
  - "9090:80" # Change to your desired port
```

### Customizing the App Title

Set the `APP_TITLE` environment variable:

```yaml
- APP_TITLE=My Movie Collection
```

## 🔍 Troubleshooting

### Viewing Logs

View all container logs

```bash
docker-compose logs
```

Follow logs in real-time

```bash
docker-compose logs -f
```

View specific service logs

```bash
docker-compose logs glimpse-media-viewer
```

### Manual Data Update

To trigger a data update manually:

```bash
docker exec glimpse-media-viewer bash -c 'python /app/scripts/plex_data_fetcher.py --url "$PLEX_URL" --token "$PLEX_TOKEN" --output /app/data'
```

### Common Issues

#### Default Nginx Page Shows Instead of the App

If you see the default Nginx welcome page, there might be an issue with the configuration:

Check if the app files are present

```bash
docker exec glimpse-media-viewer ls -la /app/web
```

Check Nginx configuration

```bash
docker exec glimpse-media-viewer cat /etc/nginx/conf.d/default.conf
```

Restart Nginx

```bash
docker exec glimpse-media-viewer nginx -s reload
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

## 🤖 AI Assistance Disclosure

This tool was developed with assistance from AI language models.
