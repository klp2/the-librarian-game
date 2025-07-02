# Release Automation Troubleshooting Guide

## Quick Diagnosis

### Sync Workflow Failures

**Check Status**:
```bash
gh run list --repo klp2/the-librarian --workflow=sync-release.yml --limit=5
```

**View Logs**:
```bash
gh run view <RUN_ID> --repo klp2/the-librarian --log
```

### Common Issues and Solutions

#### 1. Permission Errors

**Error**: `Resource not accessible by integration`

**Cause**: Insufficient token permissions or incorrect secret configuration

**Solution**:
```bash
# Verify token permissions
gh auth status

# Check repository secrets
gh secret list --repo klp2/the-librarian

# Recreate token with correct permissions
./scripts/setup-automation.sh --private-repo klp2/the-librarian --public-repo klp2/the-librarian-game
```

**Required Token Permissions**:
- `contents:write` - Create/update releases and repository content
- `metadata:read` - Read repository metadata
- `actions:read` - Read workflow information

#### 2. Asset Upload Failures

**Error**: `Failed to upload asset` or `Request entity too large`

**Diagnostic Steps**:
```bash
# Check asset sizes
ls -lh release-artifacts/

# Verify GitHub limits (2GB per file, 10GB per release)
find release-artifacts/ -type f -exec stat -f%z {} + | sort -nr
```

**Solutions**:
- **Large Files**: Split archives or use Git LFS
- **Too Many Assets**: Batch uploads or use release artifact storage
- **Network Issues**: Retry with manual script

**Manual Asset Upload**:
```bash
# Emergency upload for specific assets
gh release upload v1.0.0 release-artifacts/large-file.tar.gz --repo klp2/the-librarian-game
```

#### 3. API Rate Limiting

**Error**: `API rate limit exceeded` or `403 Forbidden`

**Diagnostic**:
```bash
# Check rate limit status
gh api rate_limit

# Check authenticated vs unauthenticated limits
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit
```

**Solutions**:
- **Use Authenticated Token**: Increases limit from 60/hour to 5000/hour
- **Wait for Reset**: Rate limits reset every hour
- **Implement Backoff**: The workflows include automatic retry logic

#### 4. Release Already Exists

**Error**: `Release already exists` without force flag

**Check Existing Release**:
```bash
gh release view v1.0.0 --repo klp2/the-librarian-game
```

**Solutions**:
```bash
# Force overwrite existing release
./scripts/emergency-sync.sh v1.0.0
# When prompted, select 'y' to overwrite

# Or delete and recreate
gh release delete v1.0.0 --repo klp2/the-librarian-game --yes
gh workflow run sync-release.yml --repo klp2/the-librarian -f tag_name=v1.0.0
```

#### 5. Workflow Not Triggering

**Check Workflow Status**:
```bash
# List all workflows
gh workflow list --repo klp2/the-librarian

# Check specific workflow
gh workflow view sync-release.yml --repo klp2/the-librarian
```

**Common Causes**:
- Workflow file not in correct location (`.github/workflows/`)
- YAML syntax errors
- Workflow disabled in repository settings
- Branch protection rules preventing pushes

**Solutions**:
```bash
# Manually trigger workflow
gh workflow run sync-release.yml --repo klp2/the-librarian -f tag_name=v1.0.0

# Validate YAML syntax
yamllint .github/workflows/sync-release.yml

# Check workflow is enabled
gh api repos/klp2/the-librarian/actions/workflows --jq '.workflows[] | select(.name=="Sync Release to Public Repository")'
```

#### 6. Asset Checksum Mismatches

**Error**: Checksums don't match between repositories

**Verification**:
```bash
# Compare checksums
curl -sL https://github.com/klp2/the-librarian/releases/download/v1.0.0/checksums.txt > private-checksums.txt
curl -sL https://github.com/klp2/the-librarian-game/releases/download/v1.0.0/checksums.txt > public-checksums.txt
diff private-checksums.txt public-checksums.txt
```

**Solutions**:
- **Re-sync Release**: Force a complete re-sync
- **Regenerate Checksums**: The sync script automatically creates checksums
- **Manual Verification**: Download and verify assets manually

#### 7. Network and Connectivity Issues

**Symptoms**: Timeouts, connection errors, partial uploads

**Diagnostic**:
```bash
# Test GitHub API connectivity
curl -I https://api.github.com

# Test specific repository access
gh api repos/klp2/the-librarian
gh api repos/klp2/the-librarian-game
```

**Solutions**:
- **Retry Mechanism**: Workflows include automatic retries
- **Manual Sync**: Use emergency script during stable network
- **Chunked Uploads**: For large files, consider splitting

### Debug Mode

Enable verbose logging in scripts:

```bash
# Verbose emergency sync
DRY_RUN=true ./scripts/emergency-sync.sh v1.0.0

# Verbose Python script
python scripts/sync-release.py --tag v1.0.0 --verbose --dry-run
```

### Workflow Debug Information

Add to workflow for debugging:

```yaml
- name: Debug Environment
  run: |
    echo "GitHub Context:"
    echo "${{ toJson(github) }}"
    echo "Secrets (masked):"
    echo "CROSS_REPO_TOKEN: ${{ secrets.CROSS_REPO_TOKEN && 'SET' || 'NOT SET' }}"
    echo "Environment:"
    env | sort
```

## Emergency Procedures

### Complete Sync Failure

When automation completely fails, use manual procedures:

1. **Immediate Backup**:
   ```bash
   # Download all assets from private repo
   gh release download --repo klp2/the-librarian --dir backup-$(date +%Y%m%d)
   ```

2. **Manual Release Creation**:
   ```bash
   # Create release with all assets
   gh release create v1.0.0 \
     --repo klp2/the-librarian-game \
     --title "Version 1.0.0" \
     --notes-file RELEASE_NOTES.md \
     backup-*/
   ```

3. **Verify and Document**:
   ```bash
   # Verify release
   gh release view v1.0.0 --repo klp2/the-librarian-game
   
   # Document the manual process
   echo "Manual sync completed for v1.0.0 on $(date)" >> manual-sync-log.txt
   ```

### Token Compromise or Rotation

If the CROSS_REPO_TOKEN is compromised:

1. **Immediate Revocation**:
   - Go to GitHub Settings > Personal Access Tokens
   - Revoke the compromised token

2. **Create New Token**:
   ```bash
   ./scripts/setup-automation.sh --private-repo klp2/the-librarian --public-repo klp2/the-librarian-game
   ```

3. **Verify New Configuration**:
   ```bash
   # Test with new token
   gh workflow run sync-release.yml --repo klp2/the-librarian -f tag_name=latest
   ```

### Repository Access Issues

If repository access is revoked or changed:

1. **Verify Current Access**:
   ```bash
   gh auth status
   gh api user/repos --jq '.[].full_name' | grep -E "(the-librarian|librarian-game)"
   ```

2. **Request Access Restoration**:
   - Contact repository owner
   - Verify team membership
   - Check organization settings

3. **Alternative Access**:
   - Use organization-level tokens if available
   - Coordinate with team members who have access

## Monitoring and Alerts

### Automated Monitoring

The validation workflow runs every 6 hours and will:
- Create issues for sync problems
- Close issues when problems are resolved
- Send notifications based on configuration

### Manual Health Checks

```bash
# Quick health check
./scripts/emergency-sync.sh --dry-run

# Comprehensive validation
gh workflow run validate-sync.yml --repo klp2/the-librarian-game
```

### Setting Up Alerts

Create custom alerts for critical failures:

```bash
# Create issue for persistent failures
if [ $FAILURE_COUNT -gt 3 ]; then
  gh issue create \
    --repo klp2/the-librarian-game \
    --title "🚨 Critical: Release Sync Failing" \
    --label "critical,automation" \
    --body "Multiple sync failures detected. Manual intervention required."
fi
```

## Performance Optimization

### Large Repository Handling

For repositories with many releases or large assets:

- **Incremental Sync**: Only sync new releases
- **Parallel Processing**: Use concurrent downloads/uploads
- **Selective Assets**: Sync only essential assets

### Network Optimization

```bash
# Use compression for large transfers
gh release download --archive=tar.gz

# Parallel asset uploads
parallel -j4 gh release upload v1.0.0 {} --repo klp2/the-librarian-game ::: release-artifacts/*
```

## Support and Escalation

### Self-Service Resources

1. **Release Automation Guide**: Complete setup and usage documentation
2. **GitHub Actions Logs**: Detailed execution information
3. **Script Dry-Run Mode**: Test without making changes

### When to Escalate

Escalate to team lead or DevOps when:
- Multiple sync failures across different releases
- Token or permission issues that can't be self-resolved
- GitHub API or service-level issues
- Security concerns with token or repository access

### Escalation Information

When escalating, include:
- Specific error messages and workflow run IDs
- Repository names and affected releases
- Timeline of when issues started
- Steps already attempted
- Screenshots of error messages if helpful

## Prevention

### Best Practices

1. **Regular Validation**: Use the validation workflow
2. **Token Rotation**: Rotate tokens every 90 days
3. **Permission Audits**: Review repository access monthly
4. **Backup Procedures**: Test manual sync quarterly
5. **Documentation**: Keep troubleshooting steps updated

### Monitoring Checklist

- [ ] Sync workflows running successfully
- [ ] Validation workflow catching issues
- [ ] Token permissions adequate and current
- [ ] Repository access maintained
- [ ] Asset integrity verified
- [ ] Documentation up to date