// The Librarian - Download Page JavaScript

class ReleaseManager {
    constructor() {
        this.apiUrl = 'https://api.github.com/repos/klp2/the-librarian-game/releases/latest';
        this.loadingEl = document.getElementById('loading');
        this.errorEl = document.getElementById('error');
        this.downloadsEl = document.getElementById('downloads');
        this.releaseInfoEl = document.getElementById('release-info');
        this.platformDownloadsEl = document.getElementById('platform-downloads');
        this.additionalFilesEl = document.getElementById('additional-files');
    }

    async init() {
        try {
            await this.fetchLatestRelease();
        } catch (error) {
            console.error('Error initializing release manager:', error);
            this.showError();
        }
    }

    async fetchLatestRelease() {
        try {
            const response = await fetch(this.apiUrl);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const release = await response.json();
            this.displayRelease(release);
        } catch (error) {
            console.error('Error fetching release:', error);
            throw error;
        }
    }

    displayRelease(release) {
        this.hideLoading();
        this.showReleaseInfo(release);
        this.showPlatformDownloads(release);
        this.showAdditionalFiles(release);
        this.showDownloads();
    }

    showReleaseInfo(release) {
        const releaseDate = new Date(release.published_at).toLocaleDateString();
        const isPrerelease = release.prerelease ? ' (Pre-release)' : '';
        
        this.releaseInfoEl.innerHTML = `
            <h3>Version ${release.tag_name}${isPrerelease}</h3>
            <p><strong>Released:</strong> ${releaseDate}</p>
            <p><strong>Downloads:</strong> ${this.getTotalDownloads(release)} total</p>
        `;
    }

    showPlatformDownloads(release) {
        const platforms = this.groupAssetsByPlatform(release.assets);
        
        let html = '';
        Object.entries(platforms).forEach(([platformKey, platform]) => {
            if (platform.assets.length > 0) {
                html += this.createPlatformCard(platform);
            }
        });
        
        this.platformDownloadsEl.innerHTML = html;
    }

    groupAssetsByPlatform(assets) {
        const platforms = {
            windows: { 
                name: 'Windows', 
                icon: '🪟', 
                assets: [],
                detect: (name) => name.includes('Windows') && !name.includes('checksums')
            },
            darwin: { 
                name: 'macOS', 
                icon: '🍎', 
                assets: [],
                detect: (name) => name.includes('Darwin') && !name.includes('checksums')
            },
            linux: { 
                name: 'Linux', 
                icon: '🐧', 
                assets: [],
                detect: (name) => name.includes('Linux') && !name.includes('checksums')
            }
        };

        assets.forEach(asset => {
            Object.values(platforms).forEach(platform => {
                if (platform.detect(asset.name)) {
                    platform.assets.push(asset);
                }
            });
        });

        return platforms;
    }

    createPlatformCard(platform) {
        let downloadsHtml = '';
        
        platform.assets.forEach(asset => {
            const arch = this.getArchitecture(asset.name);
            const size = this.formatFileSize(asset.size);
            
            downloadsHtml += `
                <a href="${asset.browser_download_url}" class="download-link" onclick="trackDownload('${platform.name}', '${arch}')">
                    Download for ${platform.name} (${arch})
                    <small>${size}</small>
                </a>
            `;
        });

        return `
            <div class="platform-card">
                <div class="platform-header">
                    <span class="platform-icon">${platform.icon}</span>
                    <span class="platform-name">${platform.name}</span>
                </div>
                ${downloadsHtml}
            </div>
        `;
    }

    getArchitecture(filename) {
        if (filename.includes('arm64')) return 'ARM64';
        if (filename.includes('x86_64')) return 'x86_64';
        if (filename.includes('i386')) return 'i386';
        return 'Universal';
    }

    showAdditionalFiles(release) {
        const checksums = release.assets.find(asset => 
            asset.name.toLowerCase().includes('checksum') || 
            asset.name.toLowerCase().includes('sum')
        );
        
        let html = '';
        
        if (checksums) {
            html += `
                <p class="checksums">
                    <a href="${checksums.browser_download_url}" class="checksums-link">
                        📋 Download checksums.txt for verification
                    </a>
                </p>
            `;
        }
        
        html += `
            <p>
                <a href="https://github.com/klp2/the-librarian-game/releases/tag/${release.tag_name}" class="checksums-link">
                    📜 View full release notes on GitHub
                </a>
            </p>
        `;
        
        this.additionalFilesEl.innerHTML = html;
    }

    formatFileSize(bytes) {
        const mb = bytes / (1024 * 1024);
        return mb >= 1 ? `${mb.toFixed(1)} MB` : `${(bytes / 1024).toFixed(0)} KB`;
    }

    getTotalDownloads(release) {
        return release.assets.reduce((total, asset) => total + asset.download_count, 0);
    }

    hideLoading() {
        this.loadingEl.classList.add('hidden');
    }

    showDownloads() {
        this.downloadsEl.classList.remove('hidden');
    }

    showError() {
        this.loadingEl.classList.add('hidden');
        this.errorEl.classList.remove('hidden');
    }
}

// Download tracking (optional analytics)
function trackDownload(platform, architecture) {
    // This could be extended to send analytics to your preferred service
    console.log(`Download started: ${platform} (${architecture})`);
    
    // Example: Google Analytics 4 event tracking
    if (typeof gtag !== 'undefined') {
        gtag('event', 'download', {
            'event_category': 'engagement',
            'event_label': `${platform}_${architecture}`,
            'value': 1
        });
    }
}

// Auto-detect user platform and highlight recommended download
function detectUserPlatform() {
    const userAgent = navigator.userAgent.toLowerCase();
    const platform = navigator.platform.toLowerCase();
    
    if (userAgent.includes('windows') || platform.includes('win')) {
        return 'windows';
    } else if (userAgent.includes('mac') || platform.includes('mac')) {
        return 'darwin';
    } else if (userAgent.includes('linux') || platform.includes('linux')) {
        return 'linux';
    }
    
    return null;
}

// Smooth scrolling for anchor links
function setupSmoothScrolling() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', async () => {
    setupSmoothScrolling();
    
    const releaseManager = new ReleaseManager();
    await releaseManager.init();
    
    // Highlight user's platform if detected
    const userPlatform = detectUserPlatform();
    if (userPlatform) {
        // Add visual indication for user's platform
        setTimeout(() => {
            const platformCards = document.querySelectorAll('.platform-card');
            platformCards.forEach(card => {
                const platformName = card.querySelector('.platform-name').textContent.toLowerCase();
                if ((userPlatform === 'darwin' && platformName.includes('macos')) ||
                    (userPlatform === 'windows' && platformName.includes('windows')) ||
                    (userPlatform === 'linux' && platformName.includes('linux'))) {
                    card.style.border = '2px solid #e74c3c';
                    card.style.boxShadow = '0 4px 20px rgba(231, 76, 60, 0.2)';
                }
            });
        }, 500);
    }
});

// Service Worker for offline support (optional)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}