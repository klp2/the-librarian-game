#!/usr/bin/env python3
"""
Cross-repository release synchronization script.

This script provides a robust Python-based alternative to GitHub Actions
for synchronizing releases between private and public repositories.

Usage:
    python sync-release.py --tag v1.0.0 --token $GITHUB_TOKEN
    python sync-release.py --latest --private-repo owner/private --public-repo owner/public

Features:
    - Downloads all assets from private repository release
    - Creates matching release in public repository
    - Generates checksums for verification
    - Handles rate limiting and retries
    - Comprehensive error handling and logging
"""

import argparse
import hashlib
import json
import logging
import os
import requests
import shutil
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('sync-release.log', mode='a')
    ]
)
logger = logging.getLogger(__name__)

class GitHubAPIError(Exception):
    """Custom exception for GitHub API errors."""
    pass

class ReleaseSyncer:
    """Main class for synchronizing releases between repositories."""
    
    def __init__(self, private_repo: str, public_repo: str, token: str):
        self.private_repo = private_repo
        self.public_repo = public_repo
        self.token = token
        self.session = self._create_session()
        
        logger.info(f"Initialized ReleaseSyncer: {private_repo} -> {public_repo}")
    
    def _create_session(self) -> requests.Session:
        """Create configured requests session with authentication."""
        session = requests.Session()
        session.headers.update({
            'Authorization': f'token {self.token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'ReleaseSyncer/1.0'
        })
        return session
    
    def _make_request(self, method: str, url: str, **kwargs) -> requests.Response:
        """Make HTTP request with retry logic and rate limiting."""
        max_retries = 3
        base_delay = 1
        
        for attempt in range(max_retries):
            try:
                response = self.session.request(method, url, **kwargs)
                
                # Handle rate limiting
                if response.status_code == 429:
                    reset_time = int(response.headers.get('X-RateLimit-Reset', 0))
                    if reset_time:
                        wait_time = max(reset_time - int(time.time()), 60)
                        logger.warning(f"Rate limited. Waiting {wait_time} seconds...")
                        time.sleep(wait_time)
                        continue
                
                response.raise_for_status()
                return response
                
            except requests.exceptions.RequestException as e:
                if attempt == max_retries - 1:
                    raise GitHubAPIError(f"Request failed after {max_retries} attempts: {e}")
                
                delay = base_delay * (2 ** attempt)
                logger.warning(f"Request failed (attempt {attempt + 1}), retrying in {delay}s: {e}")
                time.sleep(delay)
    
    def get_release_info(self, tag: Optional[str] = None) -> Dict:
        """Get release information from private repository."""
        if tag:
            url = f"https://api.github.com/repos/{self.private_repo}/releases/tags/{tag}"
            logger.info(f"Fetching release info for tag: {tag}")
        else:
            url = f"https://api.github.com/repos/{self.private_repo}/releases/latest"
            logger.info("Fetching latest release info")
        
        response = self._make_request('GET', url)
        release_info = response.json()
        
        logger.info(f"Found release: {release_info['name']} ({release_info['tag_name']})")
        logger.info(f"Assets: {len(release_info['assets'])} files")
        
        return release_info
    
    def check_public_release_exists(self, tag: str) -> bool:
        """Check if release already exists in public repository."""
        url = f"https://api.github.com/repos/{self.public_repo}/releases/tags/{tag}"
        
        try:
            response = self._make_request('GET', url)
            logger.info(f"Release {tag} already exists in public repository")
            return True
        except GitHubAPIError:
            logger.info(f"Release {tag} does not exist in public repository")
            return False
    
    def download_release_assets(self, release_info: Dict, download_dir: Path) -> List[Path]:
        """Download all assets from the private repository release."""
        download_dir.mkdir(exist_ok=True)
        downloaded_files = []
        
        if not release_info['assets']:
            logger.info("No assets to download")
            return downloaded_files
        
        for i, asset in enumerate(release_info['assets'], 1):
            asset_url = asset['url']
            asset_name = asset['name']
            asset_size = asset['size']
            
            logger.info(f"Downloading asset {i}/{len(release_info['assets'])}: {asset_name} ({asset_size} bytes)")
            
            # Download with proper headers for GitHub API
            headers = {
                'Authorization': f'token {self.token}',
                'Accept': 'application/octet-stream'
            }
            
            response = requests.get(asset_url, headers=headers, stream=True)
            response.raise_for_status()
            
            file_path = download_dir / asset_name
            
            # Download with progress tracking for large files
            with open(file_path, 'wb') as f:
                downloaded = 0
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # Show progress for large files
                        if asset_size > 1024 * 1024:  # 1MB
                            progress = (downloaded / asset_size) * 100
                            print(f"\r  Progress: {progress:.1f}%", end='', flush=True)
            
            if asset_size > 1024 * 1024:
                print()  # New line after progress
            
            downloaded_files.append(file_path)
            logger.info(f"✅ Downloaded: {asset_name}")
        
        return downloaded_files
    
    def generate_checksums(self, files: List[Path]) -> Dict[str, str]:
        """Generate SHA256 checksums for downloaded files."""
        checksums = {}
        
        for file_path in files:
            if file_path.is_file():
                logger.info(f"Generating checksum for {file_path.name}")
                
                sha256_hash = hashlib.sha256()
                with open(file_path, "rb") as f:
                    for chunk in iter(lambda: f.read(4096), b""):
                        sha256_hash.update(chunk)
                
                checksums[file_path.name] = sha256_hash.hexdigest()
        
        return checksums
    
    def create_checksums_file(self, files: List[Path], output_dir: Path) -> Path:
        """Create checksums.txt file for verification."""
        checksums = self.generate_checksums(files)
        
        checksums_file = output_dir / "checksums.txt"
        with open(checksums_file, 'w') as f:
            for filename, checksum in sorted(checksums.items()):
                f.write(f"{checksum}  {filename}\n")
        
        logger.info(f"Created checksums file with {len(checksums)} entries")
        return checksums_file
    
    def delete_public_release(self, tag: str) -> bool:
        """Delete existing release from public repository."""
        url = f"https://api.github.com/repos/{self.public_repo}/releases/tags/{tag}"
        
        try:
            # First get the release to get its ID
            response = self._make_request('GET', url)
            release_data = response.json()
            release_id = release_data['id']
            
            # Delete the release
            delete_url = f"https://api.github.com/repos/{self.public_repo}/releases/{release_id}"
            self._make_request('DELETE', delete_url)
            
            logger.info(f"Deleted existing release {tag} from public repository")
            return True
            
        except GitHubAPIError as e:
            logger.error(f"Failed to delete existing release: {e}")
            return False
    
    def create_public_release(self, release_info: Dict, asset_files: List[Path], 
                            force: bool = False) -> str:
        """Create release in public repository with assets."""
        tag_name = release_info['tag_name']
        
        # Check if release exists
        if self.check_public_release_exists(tag_name):
            if not force:
                raise GitHubAPIError(f"Release {tag_name} already exists in public repository. Use --force to overwrite.")
            else:
                logger.info("Force flag enabled, deleting existing release...")
                if not self.delete_public_release(tag_name):
                    raise GitHubAPIError("Failed to delete existing release")
        
        # Create the release
        release_data = {
            'tag_name': release_info['tag_name'],
            'name': release_info['name'],
            'body': release_info['body'],
            'prerelease': release_info['prerelease'],
            'draft': release_info['draft']
        }
        
        logger.info(f"Creating release {tag_name} in public repository...")
        
        url = f"https://api.github.com/repos/{self.public_repo}/releases"
        response = self._make_request('POST', url, json=release_data)
        public_release = response.json()
        
        logger.info(f"✅ Created release: {public_release['html_url']}")
        
        # Upload each asset
        if asset_files:
            upload_url = public_release['upload_url'].replace('{?name,label}', '')
            
            for i, asset_file in enumerate(asset_files, 1):
                logger.info(f"Uploading asset {i}/{len(asset_files)}: {asset_file.name}")
                self.upload_asset(upload_url, asset_file)
        
        return public_release['html_url']
    
    def upload_asset(self, upload_url: str, asset_file: Path):
        """Upload a single asset to the public release."""
        file_size = asset_file.stat().st_size
        
        with open(asset_file, 'rb') as f:
            headers = {
                'Authorization': f'token {self.token}',
                'Content-Type': 'application/octet-stream',
                'Content-Length': str(file_size)
            }
            params = {'name': asset_file.name}
            
            # For large files, show upload progress
            if file_size > 1024 * 1024:  # 1MB
                logger.info(f"Uploading large file: {asset_file.name} ({file_size} bytes)")
            
            response = requests.post(upload_url, headers=headers, params=params, data=f)
            response.raise_for_status()
            
        logger.info(f"📤 Uploaded: {asset_file.name}")
    
    def sync_release(self, tag: Optional[str] = None, force: bool = False) -> str:
        """Main synchronization method."""
        logger.info(f"🔄 Starting release sync: {self.private_repo} -> {self.public_repo}")
        
        try:
            # Get release info
            release_info = self.get_release_info(tag)
            sync_tag = release_info['tag_name']
            
            # Download assets
            download_dir = Path("temp_assets")
            try:
                asset_files = self.download_release_assets(release_info, download_dir)
                
                # Create checksums file if we have assets
                if asset_files:
                    checksums_file = self.create_checksums_file(asset_files, download_dir)
                    asset_files.append(checksums_file)
                
                # Create public release
                public_url = self.create_public_release(release_info, asset_files, force)
                
                logger.info(f"✅ Successfully synced release: {public_url}")
                return public_url
                
            finally:
                # Cleanup
                if download_dir.exists():
                    shutil.rmtree(download_dir)
                    logger.info("🧹 Cleaned up temporary files")
                    
        except Exception as e:
            logger.error(f"❌ Sync failed: {e}")
            raise

def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Sync release between GitHub repositories',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Sync specific tag
    python sync-release.py --tag v1.0.0 --token $GITHUB_TOKEN
    
    # Sync latest release
    python sync-release.py --latest --private-repo owner/repo --public-repo owner/public
    
    # Force overwrite existing release
    python sync-release.py --tag v1.0.0 --force --token $GITHUB_TOKEN
        """
    )
    
    # Required arguments
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--tag', help='Specific release tag to sync')
    group.add_argument('--latest', action='store_true', help='Sync latest release')
    
    # Repository configuration
    parser.add_argument('--private-repo', default='klp2/the-librarian', 
                       help='Private repository (default: klp2/the-librarian)')
    parser.add_argument('--public-repo', default='klp2/the-librarian-game', 
                       help='Public repository (default: klp2/the-librarian-game)')
    
    # Authentication
    parser.add_argument('--token', help='GitHub token (or set GITHUB_TOKEN env var)')
    
    # Options
    parser.add_argument('--force', action='store_true', 
                       help='Force sync even if release exists in public repo')
    parser.add_argument('--dry-run', action='store_true', 
                       help='Show what would be done without making changes')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    
    return parser.parse_args()

def main():
    """Main entry point."""
    args = parse_arguments()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Get GitHub token
    token = args.token or os.environ.get('GITHUB_TOKEN')
    if not token:
        logger.error("❌ Error: GitHub token required (--token or GITHUB_TOKEN env var)")
        sys.exit(1)
    
    # Validate repository format
    for repo in [args.private_repo, args.public_repo]:
        if '/' not in repo:
            logger.error(f"❌ Error: Invalid repository format '{repo}'. Use 'owner/repo' format.")
            sys.exit(1)
    
    if args.dry_run:
        logger.info("🔍 DRY RUN MODE - No changes will be made")
    
    try:
        syncer = ReleaseSyncer(args.private_repo, args.public_repo, token)
        
        if args.dry_run:
            # In dry run mode, just get release info
            tag = args.tag if not args.latest else None
            release_info = syncer.get_release_info(tag)
            
            logger.info("🔍 Dry run - would sync:")
            logger.info(f"   Tag: {release_info['tag_name']}")
            logger.info(f"   Name: {release_info['name']}")
            logger.info(f"   Assets: {len(release_info['assets'])}")
            logger.info(f"   Prerelease: {release_info['prerelease']}")
            
            if syncer.check_public_release_exists(release_info['tag_name']):
                if args.force:
                    logger.info("   Action: Would overwrite existing release (--force enabled)")
                else:
                    logger.info("   Action: Would fail - release exists (use --force to overwrite)")
            else:
                logger.info("   Action: Would create new release")
        else:
            # Perform actual sync
            tag = args.tag if not args.latest else None
            public_url = syncer.sync_release(tag, args.force)
            
            print(f"\n🎉 Success! Release synced to: {public_url}")
            
    except KeyboardInterrupt:
        logger.info("⏹️ Sync cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()