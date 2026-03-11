# ═══════════════════════════════════════════════════════════════════════════
# KnoxTrain Configuration Example
# ═══════════════════════════════════════════════════════════════════════════
#
# This file demonstrates all available KnoxTrain configuration options.
# Use this as a template for your own knox_train.rb config.
#
# Usage:
#   knox validate -c ./example-config.rb
#   knox backup --all -c ./example-config.rb
#   knox status -c ./example-config.rb
#   knox schedule --all --time 02:00 -c ./example-config.rb
#

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
# Global settings apply to all profiles and backends.
#
global do
  # Priority level for backup processes
  # Options: :normal, :low, :idle
  # - :normal — regular priority (default)
  # - :low    — reduced priority (uses `nice` on Unix systems)
  # - :idle   — lowest priority (runs only when system is idle)
  priority :normal

  # Enable/disable native macOS notifications
  # - true:  send notifications on backup completion (default)
  # - false: disable all notifications
  # Notifications include:
  #   - Backup success/failure summaries
  #   - Status check completion
  #   - Schedule installation/removal
  notifications true
end

# ─────────────────────────────────────────────────────────────────────────────
# PROFILE: Documents (personal files)
# ─────────────────────────────────────────────────────────────────────────────
# A profile defines what to backup and where to back it up.
# You can have multiple profiles—each is backed up independently.
#
profile :documents do
  # List of directories to backup
  # Can use:
  #   - Absolute paths: "/Users/yourname/Documents"
  #   - Home expansion: "~/Documents"
  #   - Multiple sources: backup different dirs to same backends
  sources [
    "~/Documents",
    "~/Desktop",
  ]

  # Optional: Exclude files matching patterns in these files
  # Each file contains restic ignore patterns (one per line)
  # Patterns use .gitignore syntax (glob patterns)
  exclude_files [
    "#{File.expand_path('~')}/.config/restic/excludes.txt"
  ]

  # Optional: Restic tags for organizational purposes
  # Tags are stored with snapshots and help organize backups
  # Multiple profiles can share tags (e.g., :documents)
  tags [:documents, :personal]

  # Optional: SSH host for Wake-on-LAN and automated shutdown
  # Used by run_before/run_after hooks to manage NAS devices
  # Example: "nas.local" or "192.168.1.100"
  host "nas.local"

  # ───────────────────────────────────────────────────────────────────────────
  # BACKEND: S3 (cloud storage)
  # ───────────────────────────────────────────────────────────────────────────
  # Backends define where to store backups. A profile can have multiple backends.
  # Restic supports: s3, sftp, b2, rest, azure, gs, swift, rclone, etc.
  #
  backend :s3 do
    # S3 repository URL
    # Format: s3:https://s3.example.com/bucket-name
    # or (Backblaze B2): s3:s3.us-east-005.backblazeb2.com/bucket-name
    repo "s3:s3.us-east-005.backblazeb2.com/your-bucket/documents"

    # Repository encryption password
    # Stored as a Proc and executed at runtime (deferred execution)
    # Options:
    #   - keychain("service-name")      — fetch from macOS Keychain
    #   - env_secret("ENV_VAR_NAME")    — fallback for non-macOS systems
    password { keychain("restic-documents") }

    # Optional: Retention policy (pruning rules)
    # Keeps N snapshots per time period:
    #   - daily:   keep last N daily snapshots
    #   - weekly:  keep last N weekly snapshots
    #   - monthly: keep last N monthly snapshots
    #   - yearly:  keep last N yearly snapshots
    # Use `--prune` flag to apply: `knox backup --all --prune`
    retention daily: 30, weekly: 52, monthly: 24, yearly: 5

    # Optional: Hooks executed before backup
    # Multiple hooks execute in order
    # Use for: pre-backup checks, service shutdown, device wake, etc.
    run_before do
      # No-op for cloud storage (no WoL needed for S3)
    end

    # Optional: Hooks executed after backup
    # Executes even if backup fails (ensure semantics)
    # Use for: cleanup, error recovery, logging, device shutdown, etc.
    run_after do
      # No-op for cloud storage
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # BACKEND: SFTP (NAS storage)
  # ───────────────────────────────────────────────────────────────────────────
  # SFTP backend to backup to a network-attached storage device.
  #
  backend :sftp do
    # SFTP repository URL
    # Format: sftp://user@host/path or sftp://host/path
    repo "sftp://nas.local/backups/documents"

    # Password for SFTP authentication
    password { keychain("restic-sftp") }

    # Retention policy for SFTP backend
    retention daily: 30, weekly: 52, monthly: 24, yearly: 5

    # Hook: Wake NAS before backup
    # SshServer provides:
    #   - wake()     — send Wake-on-LAN magic packet
    #   - online?()  — check if host is reachable
    #   - shutdown() — gracefully power down via SSH
    run_before do
      server = SshServer.new("nas.local", mac: "00:11:22:33:44:55")
      server.wake unless server.online?
    end

    # Hook: Shutdown NAS after backup
    # Always runs (even on error) to ensure device powers down
    run_after do
      server = SshServer.new("nas.local", mac: "00:11:22:33:44:55")
      server.shutdown if server.online?
    end
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# PROFILE: Repositories (code + projects)
# ─────────────────────────────────────────────────────────────────────────────
# Example of a second profile with different sources and backends.
#
profile :repos do
  # Multiple sources can be backed up to same backends
  sources [
    "~/Repos",        # Main project directory
    "~/code",         # Alternative path
  ]

  # Exclude common build artifacts and dependencies
  exclude_files [
    "#{File.expand_path('~')}/.config/restic/excludes-projects.txt"
  ]

  tags [:repos, :work]

  # ───────────────────────────────────────────────────────────────────────────
  # BACKEND: S3 (cloud storage)
  # ───────────────────────────────────────────────────────────────────────────
  backend :s3 do
    repo "s3:s3.us-east-005.backblazeb2.com/your-bucket/repos"
    password { keychain("restic-repos") }
    retention daily: 30, weekly: 52, monthly: 24, yearly: 5
  end

  # ───────────────────────────────────────────────────────────────────────────
  # BACKEND: SFTP (NAS storage)
  # ───────────────────────────────────────────────────────────────────────────
  backend :sftp do
    repo "sftp://nas.local/backups/repos"
    password { keychain("restic-sftp-repos") }
    retention daily: 30, weekly: 52, monthly: 24, yearly: 5

    run_before do
      server = SshServer.new("nas.local", mac: "00:11:22:33:44:55")
      server.wake unless server.online?
    end

    run_after do
      server = SshServer.new("nas.local", mac: "00:11:22:33:44:55")
      server.shutdown if server.online?
    end
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# PROFILE: Photos (with conditional source)
# ─────────────────────────────────────────────────────────────────────────────
# Example of a profile with conditional sources.
# Uses skip! to gracefully skip profile if source not available.
#
profile :photos do
  # Sources can be Proc blocks with conditional logic
  # Use skip! to skip this profile if a required path doesn't exist
  sources [
    proc do
      path = "/Volumes/alpha/photos"
      unless File.directory?(path)
        skip! "External photo drive not mounted"
      end
      path
    end
  ]

  tags [:photos, :media]

  backend :s3 do
    repo "s3:s3.us-east-005.backblazeb2.com/your-bucket/photos"
    password { keychain("restic-photos") }

    # Longer retention for photos (longer history)
    retention daily: 30, weekly: 52, monthly: 36, yearly: 10
  end

  backend :sftp do
    repo "sftp://nas.local/backups/photos"
    password { keychain("restic-sftp-photos") }
    retention daily: 30, weekly: 52, monthly: 36, yearly: 10

    run_before do
      server = SshServer.new("nas.local", mac: "00:11:22:33:44:55")
      server.wake unless server.online?
    end

    run_after do
      server = SshServer.new("nas.local", mac: "00:11:22:33:44:55")
      server.shutdown if server.online?
    end
  end
end

# ═════════════════════════════════════════════════════════════════════════════
# SECRETS MANAGEMENT
# ═════════════════════════════════════════════════════════════════════════════
#
# Passwords are stored securely using different methods:
#
# macOS (recommended):
#   password { keychain("service-name") }
#   - Encrypts with system Keychain
#   - Interactive first-time: prompts user to save in Keychain
#   - Subsequent runs: retrieves automatically
#   - Add to Keychain manually:
#     security add-generic-password -s "restic-documents" -a "" -w "<password>"
#
# Non-macOS fallback:
#   password { env_secret("RESTIC_PASSWORD") }
#   - Reads from environment variable
#   - Set: export RESTIC_PASSWORD="your-password"
#
# AWS/S3 credentials:
#   env_credential("AWS_ACCESS_KEY_ID") { keychain("b2-key-id") }
#   env_credential("AWS_SECRET_ACCESS_KEY") { keychain("b2-secret-key") }
#   - Sets ENV variables before spawning restic
#   - KnoxTrain sets them automatically from credential blocks
#
# ═════════════════════════════════════════════════════════════════════════════
# USAGE EXAMPLES
# ═════════════════════════════════════════════════════════════════════════════
#
# # Validate configuration (no I/O, no restic required)
# $ knox validate -c ./example-config.rb
#
# # Show resolved config for a profile
# $ knox show documents -c ./example-config.rb
#
# # Backup all profiles/backends
# $ knox backup --all -c ./example-config.rb
#
# # Backup specific profile only
# $ knox backup -p documents -c ./example-config.rb
#
# # Backup specific backend only
# $ knox backup -b sftp -c ./example-config.rb
#
# # Backup with retention policy (pruning)
# $ knox backup --all --prune -c ./example-config.rb
#
# # Check snapshot status across all backends
# $ knox status -c ./example-config.rb
#
# # Detailed status for specific backend
# $ knox status -b s3 -v -c ./example-config.rb
#
# # Schedule daily backup at 02:00 (macOS launchd)
# $ knox schedule --all --time 02:00 -c ./example-config.rb
#
# # Remove scheduled backup
# $ knox unschedule --all -c ./example-config.rb
#
# # Development testing (without installation)
# $ ruby -I lib exe/knox backup --all -c ./example-config.rb
#
# ═════════════════════════════════════════════════════════════════════════════
