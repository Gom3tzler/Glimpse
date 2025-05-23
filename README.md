# 🎬 Glimpse Media Viewer

A sleek, responsive web application for browsing and viewing your Plex or Jellyfin media library content. This dockerized solution fetches metadata and artwork from your media server and presents it in an elegant, user-friendly interface with support for both Plex and Jellyfin servers.

![Glimpse Media Viewer Plex Main](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/screenshot-main-plex.png)

![Glimpse Media Viewer Plex Details](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/screenshot-details-plex.png)

![Glimpse Media Viewer Jellyfin Main](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/screenshot-main-jellyfin.png)

![Glimpse Media Viewer Jellyfin Details](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/screenshot-details-jellyfin.png)

## ✨ Features

- **Modern Interface**: Clean, responsive design that works on mobile and desktop
- **Multi-Server Support**: Connect to Plex, Jellyfin, or both servers simultaneously
- **Media Browsing**: View your Movies and TV Shows with poster art
- **Search Capability**: Quickly find content across your libraries
- **Detailed View**: See cast information, genres, and descriptions
- **Watch Movie Trailers**: Preview content directly from the interface
- **Random Content Selection**: "Roll the Dice" feature for discovering random Movies or TV Shows
- **Genre Filters**: Easily filter media by genre
- **Sort A–Z / Z–A**: Alphabetical sorting
- **Sort by Date Added (Ascending / Descending)**: Sort media by when it was added
- **Server Toggle**: Switch between multiple configured servers with one click
- **Automatic Theme Adaptation**: Interface automatically adapts to match your primary server
- **MD5 Checksum Verification**: Only downloads images when they've changed
- **Dockerized**: Easy deployment with Docker and Docker Compose
- **Customizable**: Configure update schedule, app title, and more
- **Installable as PWA**: Access your media library like a native app on any device

## ❤️ Support this project

[![Donate](https://raw.githubusercontent.com/jeremehancock/Glimpse/main/assets/donate-button.png)](https://www.buymeacoffee.com/jeremehancock)

## 🔧 Prerequisites

- Docker and Docker Compose installed on your host system
- A running Plex Media Server and/or Jellyfin Media Server
- Authentication tokens for your media server(s)
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

Edit `docker-compose.yml` to set your media server details. You can configure one or both servers:

#### Single Server Configuration (Plex)

```yaml
environment:
  - PRIMARY_SERVER=plex
  - PLEX_URL=http://your-plex-server:32400
  - PLEX_TOKEN=your-plex-token
  - CRON_SCHEDULE=0 */6 * * * # Update every 6 hours
  - TZ=UTC # Your timezone
  - APP_TITLE=Glimpse # Set app title
  - SORT_BY_DATE_ADDED=false # Sort by date instead of title
```

#### Single Server Configuration (Jellyfin)

```yaml
environment:
  - PRIMARY_SERVER=jellyfin
  - JELLYFIN_URL=http://your-jellyfin-server:8096
  - JELLYFIN_TOKEN=your-jellyfin-api-token
  - CRON_SCHEDULE=0 */6 * * * # Update every 6 hours
  - TZ=UTC # Your timezone
  - APP_TITLE=Glimpse # Set app title
  - SORT_BY_DATE_ADDED=false # Sort by date instead of title
```

#### Dual Server Configuration (Both Plex and Jellyfin)

```yaml
environment:
  - PRIMARY_SERVER=plex # Which server to show by default
  - PLEX_URL=http://your-plex-server:32400
  - PLEX_TOKEN=your-plex-token
  - JELLYFIN_URL=http://your-jellyfin-server:8096
  - JELLYFIN_TOKEN=your-jellyfin-api-token
  - CRON_SCHEDULE=0 */6 * * * # Update every 6 hours
  - TZ=UTC # Your timezone
  - APP_TITLE=Glimpse # Set app title
  - SORT_BY_DATE_ADDED=false # Sort by date instead of title
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

| Variable             | Description                               | Default                       | Required          |
| -------------------- | ----------------------------------------- | ----------------------------- | ----------------- |
| `PRIMARY_SERVER`     | Which server to show by default           | `plex`                        | No                |
| `PLEX_URL`           | URL of your Plex server                   | _None_                        | If using Plex     |
| `PLEX_TOKEN`         | Authentication token for Plex             | _None_                        | If using Plex     |
| `JELLYFIN_URL`       | URL of your Jellyfin server               | _None_                        | If using Jellyfin |
| `JELLYFIN_TOKEN`     | API token for Jellyfin                    | _None_                        | If using Jellyfin |
| `CRON_SCHEDULE`      | When to update data (cron format)         | `0 */6 * * *` (every 6 hours) | No                |
| `TZ`                 | Timezone for scheduled tasks              | `UTC`                         | No                |
| `APP_TITLE`          | Custom title for the application          | `Glimpse`                     | No                |
| `SORT_BY_DATE_ADDED` | Sort items by date added instead of title | `false`                       | No                |

### Server Configuration Notes

- **Single Server**: Configure only one server's credentials. The app will automatically detect and use the available server.
- **Dual Server**: Configure both servers' credentials. The app will show a toggle button to switch between servers.
- **Primary Server**: When both servers are configured, `PRIMARY_SERVER` determines which one is shown by default and affects the app's theme.
- **Automatic Detection**: If `PRIMARY_SERVER` is set incorrectly or credentials are missing, the app will automatically detect and switch to the available server.

### Finding Your Plex Token

You can find your Plex authentication token (X-Plex-Token) by following these steps:

1. Log in to your Plex Web App
2. Browse to any media item
3. Click the 3 dots menu and select "Get Info"
4. In the info dialog, click "View XML"
5. In the URL of the new tab, find the "X-Plex-Token=" parameter

For more detailed instructions, visit the [Plex support article](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).

### Finding Your Jellyfin API Token

To get your Jellyfin API token:

1. Log in to your Jellyfin Web Interface
2. Go to **Administration** → **Dashboard**
3. Navigate to **Advanced** → **API Keys**
4. Click **+** to create a new API key
5. Give it a name (e.g., "Glimpse Media Viewer")
6. Copy the generated API key

Alternatively, you can find your API token in the Jellyfin server logs when you first authenticate, or use the Jellyfin API documentation to generate one programmatically.

## 🏗️ Project Structure

```
Glimpse/
│
├── docker-compose.yml        # Docker Compose configuration
├── Dockerfile                # Docker build configuration
│
├── scripts/
│   ├── plex_data_fetcher.py  # Python script to fetch Plex data
│   └── jellyfin_data_fetcher.py # Python script to fetch Jellyfin data
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
│       ├── favicon-32x32.png           # Favicon (32x32)
│       └── jellyfin/                   # Jellyfin-specific themed icons
│           ├── android-chrome-192x192.png
│           ├── android-chrome-512x512.png
│           └── apple-touch-icon.png
│
├── config/
│   ├── entrypoint.sh         # Container entrypoint script
│   ├── nginx.conf            # Nginx configuration
│   └── supervisord.conf      # Supervisor configuration
│
└── data/                     # Persistent data directory
    ├── plex/                 # Plex server data
    │   ├── movies.json       # Plex movie metadata
    │   ├── tvshows.json      # Plex TV show metadata
    │   ├── checksums.pkl     # MD5 checksums for Plex artwork
    │   ├── posters/          # Plex movie and TV show posters
    │   └── backdrops/        # Plex movie and TV show backgrounds
    └── jellyfin/             # Jellyfin server data
        ├── movies.json       # Jellyfin movie metadata
        ├── tvshows.json      # Jellyfin TV show metadata
        ├── checksums.pkl     # MD5 checksums for Jellyfin artwork
        ├── posters/          # Jellyfin movie and TV show posters
        └── backdrops/        # Jellyfin movie and TV show backgrounds
```

## 🔄 How It Works

1. **Data Fetching**: Python scripts connect to your media server(s) using the provided tokens and fetch metadata for all movies and TV shows.
2. **Multi-Server Support**: When both servers are configured, data is fetched separately and stored in server-specific directories.
3. **Image Processing**: Media posters and backdrops are downloaded, with MD5 checksums to avoid re-downloading unchanged files.
4. **Theming**: The interface automatically adapts its theme based on your primary server (Plex orange/yellow or Jellyfin blue).
5. **Server Switching**: If both servers are configured, users can toggle between them with a single click.
6. **Web Server**: Nginx serves the static web interface and the downloaded data.
7. **Scheduled Updates**: Cron runs the data fetchers on the configured schedule to keep content up-to-date.
8. **Persistence**: All data is stored in volumes mapped to your host, ensuring it persists between container restarts.

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

### Setting the Primary Server

When both servers are configured, set which one appears by default:

```yaml
- PRIMARY_SERVER=jellyfin # Options: plex, jellyfin
```

This affects:

- Which server's content is shown when the app first loads
- The app's color theme (Plex = orange/yellow, Jellyfin = blue)
- The default offline page styling

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

To trigger a data update manually for Plex:

```bash
docker exec glimpse-media-viewer bash -c 'python /app/scripts/plex_data_fetcher.py --url "$PLEX_URL" --token "$PLEX_TOKEN" --output /app/data/plex'
```

To trigger a data update manually for Jellyfin:

```bash
docker exec glimpse-media-viewer bash -c 'python /app/scripts/jellyfin_data_fetcher.py --url "$JELLYFIN_URL" --token "$JELLYFIN_TOKEN" --output /app/data/jellyfin'
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
2. Ensure the media server is accessible from the container
3. Verify your server token is valid
4. Check the container logs for fetch errors

#### Server Toggle Not Appearing

If you configured both servers but don't see the toggle button:

1. Verify both server URLs and tokens are correct
2. Check the container logs for authentication errors
3. Ensure both servers are accessible from the container
4. Try restarting the container after fixing configuration

#### Wrong Theme Colors

If the app shows the wrong theme:

1. Check your `PRIMARY_SERVER` setting
2. Clear your browser cache and reload
3. Un-install and Re-install PWA

## 🛠️ Advanced Usage

### Using Behind a Reverse Proxy

This application works well behind a reverse proxy like Traefik or Nginx Proxy Manager. Just expose the container port and configure your proxy accordingly.

## 🔐 Security Considerations

- Media server tokens provide access to your media servers. Keep them secure.
- All data access is read-only, so there's no risk of modifying your media libraries.
- Consider using a dedicated API token for Glimpse rather than your main user token.

## 📝 License

This project is released under the MIT License. See the `LICENSE` file for details.

## 🤖 AI Assistance Disclosure

This tool was developed with assistance from AI language models.
