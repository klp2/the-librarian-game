# Release Automation Guide: Cross-Repository Synchronization

## Overview

This guide provides robust automation solutions for synchronizing releases from a private repository (`klp2/the-librarian`) to a public repository (`klp2/the-librarian-game`) with reliable artifact distribution.

## Problem Statement

- **Private repo**: Successfully creates releases with artifacts
- **Public repo**: Needs to mirror releases for public distribution
- **Current issue**: Manual process fails with permission issues
- **Goal**: Automated, reliable cross-repo synchronization

## Solution Architecture

### Primary Solution: GitHub Actions Cross-Repo Sync

This is the recommended approach using GitHub Actions with proper authentication and error handling.

#### Required Setup

1. **GitHub Personal Access Token (PAT)**
   - Create a fine-grained PAT with the following permissions:
     - Repository access: Both private and public repos
     - Permissions: `contents:write`, `metadata:read`, `actions:read`
   - Store as repository secret: `CROSS_REPO_TOKEN`

2. **Repository Secrets Configuration**
   ```
   CROSS_REPO_TOKEN: Your fine-grained PAT
   PUBLIC_REPO_OWNER: klp2
   PUBLIC_REPO_NAME: the-librarian-game
   ```

#### Workflow Implementation

**File: `.github/workflows/sync-release.yml` (Private Repo)**

```yaml
name: Sync Release to Public Repository

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      tag_name:
        description: 'Tag name to sync (leave empty for latest)'
        required: false
        type: string

permissions:
  contents: read

jobs:
  sync-release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout private repo
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get release information
        id: release_info
        run: |
          if [ -n "${{ github.event.inputs.tag_name }}" ]; then
            TAG_NAME="${{ github.event.inputs.tag_name }}"
          else
            TAG_NAME="${{ github.event.release.tag_name }}"
          fi
          
          echo "tag_name=${TAG_NAME}" >> $GITHUB_OUTPUT
          
          # Get release details from GitHub API
          RELEASE_DATA=$(gh api repos/${{ github.repository }}/releases/tags/${TAG_NAME})
          echo "release_name=$(echo "${RELEASE_DATA}" | jq -r '.name')" >> $GITHUB_OUTPUT
          echo "release_body=$(echo "${RELEASE_DATA}" | jq -r '.body')" >> $GITHUB_OUTPUT
          echo "prerelease=$(echo "${RELEASE_DATA}" | jq -r '.prerelease')" >> $GITHUB_OUTPUT
          echo "draft=$(echo "${RELEASE_DATA}" | jq -r '.draft')" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Download release assets
        run: |
          mkdir -p release-assets
          gh release download ${{ steps.release_info.outputs.tag_name }} \
            --dir release-assets \
            --repo ${{ github.repository }}
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Prepare public repository content
        run: |
          # Create public-safe content
          mkdir -p public-content
          
          # Copy release artifacts
          cp -r release-assets/* public-content/
          
          # Create sanitized release notes
          echo "${{ steps.release_info.outputs.release_body }}" > public-content/RELEASE_NOTES.md
          
          # Generate checksums for verification
          cd public-content
          find . -type f -name "*.tar.gz" -o -name "*.zip" | xargs sha256sum > checksums.txt

      - name: Checkout public repository
        uses: actions/checkout@v4
        with:
          repository: ${{ secrets.PUBLIC_REPO_OWNER }}/${{ secrets.PUBLIC_REPO_NAME }}
          token: ${{ secrets.CROSS_REPO_TOKEN }}
          path: public-repo
          fetch-depth: 0

      - name: Update public repository
        run: |
          cd public-repo
          
          # Update release artifacts
          rm -rf release-artifacts/*
          cp -r ../public-content/* release-artifacts/
          
          # Update version in README if needed
          if [ -f README.md ]; then
            sed -i "s/\*\*Current Version\*\*:.*/\*\*Current Version\*\*: ${{ steps.release_info.outputs.tag_name }}/" README.md
          fi
          
          # Update CHANGELOG if it exists
          if [ -f CHANGELOG.md ]; then
            # Add release entry to CHANGELOG
            echo "## ${{ steps.release_info.outputs.tag_name }} - $(date +%Y-%m-%d)" > temp_changelog
            echo "" >> temp_changelog
            echo "${{ steps.release_info.outputs.release_body }}" >> temp_changelog
            echo "" >> temp_changelog
            cat CHANGELOG.md >> temp_changelog
            mv temp_changelog CHANGELOG.md
          fi

      - name: Commit and push changes
        run: |
          cd public-repo
          git config user.name "Release Automation"
          git config user.email "noreply@github.com"
          
          git add .
          git commit -m "sync: release ${{ steps.release_info.outputs.tag_name }} from private repository"
          git push origin main

      - name: Create public release
        run: |
          cd public-repo
          
          # Create release with all assets
          gh release create ${{ steps.release_info.outputs.tag_name }} \
            --title "${{ steps.release_info.outputs.release_name }}" \
            --notes "${{ steps.release_info.outputs.release_body }}" \
            $([ "${{ steps.release_info.outputs.prerelease }}" = "true" ] && echo "--prerelease") \
            $([ "${{ steps.release_info.outputs.draft }}" = "true" ] && echo "--draft") \
            release-artifacts/*
        env:
          GH_TOKEN: ${{ secrets.CROSS_REPO_TOKEN }}

      - name: Verify sync success
        run: |
          echo "✅ Release ${{ steps.release_info.outputs.tag_name }} successfully synced to public repository"
          echo "📦 Assets uploaded: $(ls -1 public-repo/release-artifacts/ | wc -l) files"
          echo "🔍 Checksums verified: $(wc -l < public-repo/release-artifacts/checksums.txt) files"
```

### Alternative Solution 1: API-Based Sync Script

For environments where GitHub Actions aren't preferred or available.

**File: `scripts/sync-release.py`**

```python
#!/usr/bin/env python3
"""
Cross-repository release synchronization script.
Usage: python sync-release.py --tag v1.0.0 --token $GITHUB_TOKEN
"""

import argparse
import json
import os
import requests
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

class ReleaseSyncer:
    def __init__(self, private_repo: str, public_repo: str, token: str):
        self.private_repo = private_repo
        self.public_repo = public_repo
        self.token = token
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        })
    
    def get_release_info(self, tag: str) -> Dict:
        """Get release information from private repository."""
        url = f"https://api.github.com/repos/{self.private_repo}/releases/tags/{tag}"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()
    
    def download_release_assets(self, release_info: Dict, download_dir: Path) -> List[Path]:
        """Download all assets from the private repository release."""
        download_dir.mkdir(exist_ok=True)
        downloaded_files = []
        
        for asset in release_info['assets']:
            asset_url = asset['url']
            asset_name = asset['name']
            
            # Download with proper headers for GitHub API
            headers = {
                'Authorization': f'token {self.token}',
                'Accept': 'application/octet-stream'
            }
            
            response = requests.get(asset_url, headers=headers)
            response.raise_for_status()
            
            file_path = download_dir / asset_name
            with open(file_path, 'wb') as f:
                f.write(response.content)
            
            downloaded_files.append(file_path)
            print(f"✅ Downloaded: {asset_name}")
        
        return downloaded_files
    
    def create_public_release(self, release_info: Dict, asset_files: List[Path]) -> str:
        """Create release in public repository with assets."""
        # Create the release
        release_data = {
            'tag_name': release_info['tag_name'],
            'name': release_info['name'],
            'body': release_info['body'],
            'prerelease': release_info['prerelease'],
            'draft': release_info['draft']
        }
        
        url = f"https://api.github.com/repos/{self.public_repo}/releases"
        response = self.session.post(url, json=release_data)
        response.raise_for_status()
        
        public_release = response.json()
        upload_url = public_release['upload_url'].replace('{?name,label}', '')
        
        # Upload each asset
        for asset_file in asset_files:
            self.upload_asset(upload_url, asset_file)
        
        return public_release['html_url']
    
    def upload_asset(self, upload_url: str, asset_file: Path):
        """Upload a single asset to the public release."""
        with open(asset_file, 'rb') as f:
            headers = {
                'Authorization': f'token {self.token}',
                'Content-Type': 'application/octet-stream'
            }
            params = {'name': asset_file.name}
            
            response = requests.post(upload_url, headers=headers, params=params, data=f)
            response.raise_for_status()
            print(f"📤 Uploaded: {asset_file.name}")
    
    def sync_release(self, tag: str) -> str:
        """Main synchronization method."""
        print(f"🔄 Syncing release {tag} from {self.private_repo} to {self.public_repo}")
        
        # Get release info
        release_info = self.get_release_info(tag)
        print(f"📋 Found release: {release_info['name']}")
        
        # Download assets
        download_dir = Path("temp_assets")
        try:
            asset_files = self.download_release_assets(release_info, download_dir)
            
            # Create public release
            public_url = self.create_public_release(release_info, asset_files)
            
            print(f"✅ Successfully synced release: {public_url}")
            return public_url
            
        finally:
            # Cleanup
            if download_dir.exists():
                shutil.rmtree(download_dir)

def main():
    parser = argparse.ArgumentParser(description='Sync release between repositories')
    parser.add_argument('--tag', required=True, help='Release tag to sync')
    parser.add_argument('--private-repo', default='klp2/the-librarian', help='Private repository')
    parser.add_argument('--public-repo', default='klp2/the-librarian-game', help='Public repository')
    parser.add_argument('--token', help='GitHub token (or set GITHUB_TOKEN env var)')
    
    args = parser.parse_args()
    
    token = args.token or os.environ.get('GITHUB_TOKEN')
    if not token:
        print("❌ Error: GitHub token required (--token or GITHUB_TOKEN env var)")
        sys.exit(1)
    
    try:
        syncer = ReleaseSyncer(args.private_repo, args.public_repo, token)
        syncer.sync_release(args.tag)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### Alternative Solution 2: Single Repository Architecture

Reorganize to use a single repository with public/private content separation.

#### Repository Structure
```
the-librarian/
├── .github/workflows/          # Public workflows
├── public/                     # Public content
│   ├── README.md
│   ├── docs/
│   └── release-artifacts/
├── private/                    # Private source code
│   ├── src/
│   ├── internal/
│   └── .env.example
├── .gitignore                 # Ignore private/ for public releases
└── scripts/
    └── prepare-public-release.sh
```

#### Public Release Workflow
```yaml
name: Public Release

on:
  push:
    tags: ['v*']

jobs:
  public-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Prepare public content
        run: |
          # Copy only public content
          mkdir -p release-content
          cp -r public/* release-content/
          
          # Build and add artifacts
          cd private
          make build-all-platforms
          cp dist/* ../release-content/release-artifacts/
      
      - name: Create public release
        uses: softprops/action-gh-release@v1
        with:
          files: release-content/release-artifacts/*
          body_path: release-content/RELEASE_NOTES.md
```

## Backup Strategies

### Manual Backup Procedure (Emergency)

When automation fails, use this reliable manual process:

1. **Download from Private Repo**
   ```bash
   # Download specific release
   gh release download v1.0.0 --repo klp2/the-librarian --dir temp-release
   
   # Or download latest
   gh release download --repo klp2/the-librarian --dir temp-release
   ```

2. **Upload to Public Repo**
   ```bash
   # Create release with assets
   gh release create v1.0.0 \
     --repo klp2/the-librarian-game \
     --title "Version 1.0.0" \
     --notes-file RELEASE_NOTES.md \
     temp-release/*
   ```

3. **Verify Upload**
   ```bash
   # List public releases
   gh release list --repo klp2/the-librarian-game
   
   # View specific release
   gh release view v1.0.0 --repo klp2/the-librarian-game
   ```

### GitHub Package Registry Alternative

For additional distribution resilience:

```yaml
name: Publish to GitHub Packages

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Docker image
        run: |
          docker build -t ghcr.io/klp2/the-librarian:${{ github.event.release.tag_name }} .
          docker build -t ghcr.io/klp2/the-librarian:latest .
      
      - name: Push to registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker push ghcr.io/klp2/the-librarian:${{ github.event.release.tag_name }}
          docker push ghcr.io/klp2/the-librarian:latest
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Permission Errors
**Problem**: `Resource not accessible by integration`
**Solution**: 
- Verify PAT has correct permissions (`contents:write`, `metadata:read`)
- Ensure PAT is stored as repository secret, not environment variable
- Check repository settings allow Actions to access other repositories

#### 2. Asset Upload Failures
**Problem**: Assets fail to upload to public release
**Solution**:
```bash
# Check asset sizes (GitHub limit: 2GB per file, 10GB per release)
ls -lh release-artifacts/

# Verify file permissions
chmod 644 release-artifacts/*

# Test upload manually
gh release upload v1.0.0 release-artifacts/* --repo klp2/the-librarian-game
```

#### 3. API Rate Limiting
**Problem**: GitHub API rate limit exceeded
**Solution**:
- Use authenticated requests (PAT provides 5000 req/hour vs 60 unauthenticated)
- Add retry logic with exponential backoff
- Cache release information when possible

#### 4. Workflow Debugging
**Problem**: Workflow fails silently
**Solution**:
```yaml
- name: Debug environment
  run: |
    echo "GitHub context:"
    echo "${{ toJson(github) }}"
    echo "Environment variables:"
    env | sort
    echo "Available tools:"
    which gh || echo "gh CLI not available"
    gh --version || echo "gh CLI version check failed"
```

### Rollback Procedures

#### Emergency Rollback
1. **Delete problematic release**
   ```bash
   gh release delete v1.0.0 --repo klp2/the-librarian-game --yes
   ```

2. **Restore previous version**
   ```bash
   gh release create v1.0.0 \
     --repo klp2/the-librarian-game \
     --title "Version 1.0.0 (Restored)" \
     --notes "Restored from backup" \
     backup-assets/*
   ```

3. **Update repository state**
   ```bash
   git revert HEAD --no-edit
   git push origin main
   ```

## Monitoring and Validation

### Success Validation Checklist
- [ ] Release created in public repository
- [ ] All assets uploaded successfully
- [ ] Checksums match between repositories
- [ ] Release notes properly formatted
- [ ] Version numbers consistent across repos
- [ ] Public repository updated (README, CHANGELOG)

### Automated Monitoring
```yaml
name: Validate Release Sync

on:
  schedule:
    - cron: '0 */6 * * *'  # Check every 6 hours
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Compare release counts
        run: |
          PRIVATE_COUNT=$(gh api repos/klp2/the-librarian/releases | jq length)
          PUBLIC_COUNT=$(gh api repos/klp2/the-librarian-game/releases | jq length)
          
          if [ $PRIVATE_COUNT -ne $PUBLIC_COUNT ]; then
            echo "⚠️ Release count mismatch: Private=$PRIVATE_COUNT, Public=$PUBLIC_COUNT"
            exit 1
          fi
          
          echo "✅ Release counts match: $PRIVATE_COUNT releases"
```

## Implementation Checklist

### Phase 1: Setup (30 minutes)
- [ ] Create fine-grained PAT with required permissions
- [ ] Add repository secrets (CROSS_REPO_TOKEN, etc.)
- [ ] Test token permissions manually with `gh` CLI

### Phase 2: Primary Implementation (60 minutes)
- [ ] Add sync workflow to private repository
- [ ] Test with draft release
- [ ] Verify asset synchronization
- [ ] Validate public release creation

### Phase 3: Backup Implementation (30 minutes)
- [ ] Document manual procedures
- [ ] Test emergency rollback process
- [ ] Set up monitoring workflow

### Phase 4: Validation (30 minutes)
- [ ] Full end-to-end test with real release
- [ ] Verify all assets and metadata sync correctly
- [ ] Document any edge cases discovered

## Security Considerations

- **PAT Scope**: Use fine-grained PATs with minimal required permissions
- **Secret Storage**: Store tokens as repository secrets, never in code
- **Asset Validation**: Verify checksums to ensure integrity
- **Access Logging**: Monitor who has access to sync workflows
- **Rotation Policy**: Rotate PATs regularly (every 90 days recommended)

This comprehensive guide provides multiple robust solutions for reliable cross-repository release synchronization with proper error handling, monitoring, and fallback procedures.