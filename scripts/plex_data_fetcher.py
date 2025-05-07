#!/usr/bin/env python3

import requests
import json
import os
import sys
from pathlib import Path
import argparse
from datetime import datetime
import time
import pwd
import grp
import hashlib
import pickle

class PlexDataFetcher:
    def __init__(self, plex_url, plex_token, output_dir="data"):
        self.plex_url = plex_url.rstrip('/')
        self.plex_token = plex_token
        self.output_dir = Path(output_dir)
        self.checksums_file = self.output_dir / "checksums.pkl"
        self.checksums = self.load_checksums()
        
        # Get www-data UID and GID
        try:
            self.www_data_uid = pwd.getpwnam('www-data').pw_uid
            self.www_data_gid = grp.getgrnam('www-data').gr_gid
        except KeyError:
            print("Warning: www-data user/group not found. File permissions will not be changed.")
            self.www_data_uid = self.www_data_gid = None
        
        # Setup directories after initializing UID/GID
        self.setup_directories()
        
        self.session = requests.Session()
        self.session.headers.update({
            'X-Plex-Token': self.plex_token,
            'Accept': 'application/json'
        })

    def load_checksums(self):
        """Load existing checksums from file"""
        if os.path.exists(self.checksums_file):
            try:
                with open(self.checksums_file, 'rb') as f:
                    return pickle.load(f)
            except Exception as e:
                print(f"Error loading checksums: {e}")
        return {}

    def save_checksums(self):
        """Save checksums to file"""
        try:
            with open(self.checksums_file, 'wb') as f:
                pickle.dump(self.checksums, f)
            self.set_permissions(self.checksums_file)
        except Exception as e:
            print(f"Error saving checksums: {e}")

    def set_permissions(self, path):
        """Set permissions to www-data:www-data"""
        if self.www_data_uid is not None and self.www_data_gid is not None:
            try:
                os.chown(path, self.www_data_uid, self.www_data_gid)
            except PermissionError:
                print(f"Warning: Insufficient permissions to change ownership of {path}. Run as root/sudo.")
            except Exception as e:
                print(f"Error setting permissions for {path}: {e}")

    def setup_directories(self):
        """Create necessary directory structure"""
        directories = [
            self.output_dir,
            self.output_dir / "posters" / "movies",
            self.output_dir / "posters" / "tvshows",
            self.output_dir / "backdrops" / "movies",
            self.output_dir / "backdrops" / "tvshows"
        ]
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            self.set_permissions(directory)

    def fetch_sections(self):
        """Get all library sections"""
        try:
            response = self.session.get(f"{self.plex_url}/library/sections")
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"Error fetching sections: {e}")
            return None

    def fetch_section_content(self, section_key):
        """Fetch all content from a specific section"""
        try:
            # Fetch all items at once
            response = self.session.get(f"{self.plex_url}/library/sections/{section_key}/all")
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"Error fetching section content: {e}")
            return None

    def calculate_remote_md5(self, image_url):
        """Calculate MD5 hash of remote image"""
        try:
            response = self.session.get(f"{self.plex_url}{image_url}", stream=True)
            response.raise_for_status()
            
            md5_hash = hashlib.md5()
            for chunk in response.iter_content(chunk_size=4096):
                md5_hash.update(chunk)
            
            return md5_hash.hexdigest()
        except requests.RequestException as e:
            print(f"Error calculating MD5 for {image_url}: {e}")
            return None

    def download_image(self, image_url, output_path):
        """Download an image to the specified path if it has changed"""
        if not image_url:
            return False
        
        try:
            # Generate a key for the checksums dictionary
            checksum_key = f"{image_url}|{output_path}"
            
            # Calculate new MD5 checksum
            new_md5 = self.calculate_remote_md5(image_url)
            if not new_md5:
                return False
            
            # Check if file exists and compare checksums
            if output_path.exists():
                # Get the old checksum
                old_md5 = self.checksums.get(checksum_key)
                
                # If checksums match, file hasn't changed
                if old_md5 and old_md5 == new_md5:
                    print(f"Image unchanged, skipping: {output_path.name}")
                    return True
                else:
                    print(f"Image changed, downloading: {output_path.name}")
            else:
                print(f"New image, downloading: {output_path.name}")
            
            # Download the image
            response = self.session.get(f"{self.plex_url}{image_url}")
            response.raise_for_status()
            
            with open(output_path, 'wb') as f:
                f.write(response.content)
            
            # Set permissions after creating the file
            self.set_permissions(output_path)
            
            # Update checksum in dictionary
            self.checksums[checksum_key] = new_md5
            
            return True
        except requests.RequestException as e:
            print(f"Error downloading image {image_url}: {e}")
            return False

    def process_media_item(self, item, media_type):
        """Process a single media item and extract relevant metadata"""
        try:
            # Extract common fields
            media_info = {
                'id': str(item.get('ratingKey', '')),
                'title': item.get('title', ''),
                'year': item.get('year', ''),
                'summary': item.get('summary', ''),
                'rating': item.get('rating', ''),
                'studio': item.get('studio', ''),
                'addedAt': item.get('addedAt', ''),
                'updatedAt': item.get('updatedAt', ''),
                'genres': [],
                'actors': []
            }
            
            # Extract genre information
            if 'Genre' in item:
                for genre in item['Genre']:
                    media_info['genres'].append(genre.get('tag', ''))
            
            # Extract actor information - check multiple possible field names
            # First try 'Role' field
            if 'Role' in item:
                for role in item['Role']:
                    actor_info = {
                        'name': role.get('tag', ''),
                        'role': role.get('role', '')
                    }
                    media_info['actors'].append(actor_info)
            # If 'Role' doesn't exist, try 'Actor' field
            elif 'Actor' in item:
                for actor in item['Actor']:
                    actor_info = {
                        'name': actor.get('tag', ''),
                        'role': actor.get('role', '')
                    }
                    media_info['actors'].append(actor_info)
            # Try a third possible field used in some Plex versions
            elif 'Cast' in item:
                for cast in item['Cast']:
                    actor_info = {
                        'name': cast.get('tag', ''),
                        'role': cast.get('role', '')
                    }
                    media_info['actors'].append(actor_info)
            
            if media_type == 'movie':
                media_info.update({
                    'duration': item.get('duration', ''),
                    'contentRating': item.get('contentRating', ''),
                    'originallyAvailableAt': item.get('originallyAvailableAt', ''),
                    'tagline': item.get('tagline', '')
                })
            elif media_type == 'tvshow':
                media_info.update({
                    'leafCount': item.get('leafCount', ''),  # episode count
                    'childCount': item.get('childCount', ''),  # season count
                    'contentRating': item.get('contentRating', ''),
                    'originallyAvailableAt': item.get('originallyAvailableAt', '')
                })
            
            return media_info
        except Exception as e:
            print(f"Error processing media item: {e}")
            return None

    def fetch_and_save_data(self):
        """Main method to fetch all data and save it"""
        print(f"Starting Plex data fetch at {datetime.now()}")
        
        # Get all sections
        sections_data = self.fetch_sections()
        if not sections_data or 'MediaContainer' not in sections_data:
            print("Failed to fetch sections")
            return
        
        sections = sections_data['MediaContainer'].get('Directory', [])
        
        movies_data = []
        tvshows_data = []
        
        for section in sections:
            section_key = section.get('key')
            section_type = section.get('type')
            section_title = section.get('title')
            
            print(f"\nProcessing section: {section_title} (Type: {section_type})")
            
            if section_type not in ['movie', 'show']:
                print(f"Skipping unsupported section type: {section_type}")
                continue
            
            # Fetch content for this section
            content_data = self.fetch_section_content(section_key)
            if not content_data or 'MediaContainer' not in content_data:
                continue
            
            items = content_data['MediaContainer'].get('Metadata', [])
            print(f"Found {len(items)} items in {section_title}")
            
            for item in items:
                media_type = 'movie' if section_type == 'movie' else 'tvshow'
                media_info = self.process_media_item(item, media_type)
                
                if media_info:
                    # Determine output paths
                    poster_dir = self.output_dir / "posters" / f"{media_type}s"
                    poster_path = poster_dir / f"{media_info['id']}.jpg"
                    
                    # Download poster
                    poster_url = item.get('thumb')
                    if poster_url:
                        success = self.download_image(poster_url, poster_path)
                        if success:
                            print(f"Processed poster for: {media_info['title']}")
                        else:
                            print(f"Failed to process poster for: {media_info['title']}")
                    
                    # Download backdrop/art image if available
                    backdrop_url = item.get('art')
                    if backdrop_url:
                        backdrop_dir = self.output_dir / "backdrops" / f"{media_type}s"
                        backdrop_path = backdrop_dir / f"{media_info['id']}.jpg"
                        success = self.download_image(backdrop_url, backdrop_path)
                        if success:
                            print(f"Processed backdrop for: {media_info['title']}")
                        else:
                            print(f"Failed to process backdrop for: {media_info['title']}")
                    
                    # Add to appropriate list
                    if media_type == 'movie':
                        movies_data.append(media_info)
                    else:
                        tvshows_data.append(media_info)
        
        # Save JSON files
        movies_file = self.output_dir / "movies.json"
        tvshows_file = self.output_dir / "tvshows.json"
        
        with open(movies_file, 'w') as f:
            json.dump(movies_data, f, indent=2)
        self.set_permissions(movies_file)
        
        with open(tvshows_file, 'w') as f:
            json.dump(tvshows_data, f, indent=2)
        self.set_permissions(tvshows_file)
        
        # Save checksums
        self.save_checksums()
        
        print(f"\nData fetch completed at {datetime.now()}")
        print(f"Movies: {len(movies_data)}")
        print(f"TV Shows: {len(tvshows_data)}")
        print(f"Data saved to: {self.output_dir}")

def main():
    parser = argparse.ArgumentParser(description='Fetch Plex media data and posters')
    parser.add_argument('--url', required=True, help='Plex server URL (e.g., http://localhost:32400)')
    parser.add_argument('--token', required=True, help='Plex authentication token')
    parser.add_argument('--output', default='data', help='Output directory (default: data)')
    
    args = parser.parse_args()
    
    fetcher = PlexDataFetcher(args.url, args.token, args.output)
    fetcher.fetch_and_save_data()

if __name__ == "__main__":
    main()
