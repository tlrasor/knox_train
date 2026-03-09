# The noble train of data, also known as KnoxTrain

![Henry Knox](https://en.wikipedia.org/wiki/Noble_train_of_artillery#/media/File:HenryKnox.jpg)

Learn more about [Henry Knox](https://en.wikipedia.org/wiki/Henry_Knox), leader of [the noble train](https://en.wikipedia.org/wiki/Noble_train_of_artillery).

> "Historian Victor Brooks has called Knox's exploit 'one of the most stupendous feats of logistics' of the entire American Revolutionary War"

## Overview

KnoxTrain is a Ruby CLI tool for managing backups across multiple restic backends (SFTP, S3). It provides:

- **Multi-backend orchestration**: Define profiles with multiple backends and run backups across all of them
- **Secret management**: macOS Keychain integration for secure credential storage
- **SSH infrastructure**: Wake-on-LAN + automated shutdown for NAS devices
- **Status reporting**: Real-time snapshot and deduplication statistics
- **Scheduled backups**: Native launchd integration for automatic daily backups
- **Native notifications**: macOS notifications on backup completion (success/failure)

## Installation

### System-wide (Homebrew)

```bash
brew tap truevillain/knox file:///Users/travis/Projects/Personal/knox_train2/tap
brew install truevillain/knox/knox_train
```

### Updating

```bash
rake brew:reinstall      # redeploy current code at same version
rake release:patch       # bump patch version, commit, and redeploy
rake release:minor       # bump minor version, commit, and redeploy
rake release:set[2.1.0]  # set explicit version, commit, and redeploy
```

### Uninstalling

```bash
rake brew:uninstall
# Optional: rm -rf ~/Library/Logs/knox
```

## Usage

### Configuration

Create a `knox_train.rb` config file:

```ruby
global do
  priority :normal
  notifications true
end

profile :documents do
  sources ["~/Documents", "~/Desktop"]
  exclude_files ["excludes.txt"]
  tags [:documents]

  backend :s3 do
    repo "s3:s3.us-east-005.backblazeb2.com/your-bucket/documents"
    password { keychain("restic-documents") }
    retention daily: 30, weekly: 52, monthly: 24, yearly: 5
  end

  backend :sftp do
    repo "sftp://nas.local/backups/documents"
    password { keychain("restic-sftp") }
    retention daily: 30, weekly: 52, monthly: 24, yearly: 5

    run_before { SshServer.new("nas.local").wake }
    run_after { SshServer.new("nas.local").shutdown }
  end
end
```

### Commands

```bash
# Show version
knox version

# Validate config (no I/O)
knox validate -c ./knox_train.rb

# Show resolved profile config
knox show documents -c ./knox_train.rb

# Run backup for all profiles/backends
knox backup --all -c ./knox_train.rb

# Backup specific profile and backend
knox backup -p documents -b s3 -c ./knox_train.rb

# Backup with pruning (apply retention policy)
knox backup --all --prune -c ./knox_train.rb

# Show snapshot status across all backends
knox status -c ./knox_train.rb

# Show detailed status for specific backend
knox status -b s3 -v -c ./knox_train.rb

# Show backup logs
knox logs

# Follow logs in real-time (like tail -f)
knox logs --follow

# Show last 100 lines of logs
knox logs --lines 100

# Schedule daily backup at 02:00 (macOS launchd)
knox schedule --all --time 02:00 -c ./knox_train.rb

# Remove scheduled backup
knox unschedule --all -c ./knox_train.rb
```

### Global Configuration

```ruby
global do
  # Task priority (normal, low, idle)
  priority :low

  # Enable/disable native notifications on backup/schedule (default: true)
  notifications false
end
```

### Profile Configuration

```ruby
profile :name do
  # List of directories to backup
  sources ["/path/to/dir", "~/expanded/path"]

  # Optional: exclude files matching patterns in these files
  exclude_files ["excludes.txt", "ignore.txt"]

  # Optional: restic tags for organizational purposes
  tags [:documents, :personal]

  # SSH host for wake-on-LAN and poweroff (optional)
  host "nas.local"

  backend :s3 { ... }
  backend :sftp { ... }
end
```

### Backend Configuration

```ruby
backend :s3 do
  # Restic repository URL
  repo "s3:s3.us-east-005.backblazeb2.com/bucket-name"

  # Password block (called at runtime)
  password { keychain("service-name") }

  # Optional: retention policy (daily/weekly/monthly/yearly)
  retention daily: 30, weekly: 52, monthly: 24

  # Optional: hooks before/after backup
  run_before { puts "Starting backup..." }
  run_after { puts "Backup complete" }
end
```

### Secrets

```ruby
# Fetch from macOS Keychain
password { keychain("restic-password") }

# Fetch from environment variable (non-macOS fallback)
password { env_secret("RESTIC_PASSWORD") }

# Set ENV var from credential block
env_credential("AWS_ACCESS_KEY_ID") { keychain("b2-key-id") }
```

## Development

### Setup

```bash
bundle install
```

### Running Tests

```bash
bundle exec rake test
```

### Development Workflow

Run commands against local source without installing:

```bash
ruby -I lib exe/knox <command>
```

**Important**: Never use `gem install knox_train` for development. It puts an rbenv shim
on the PATH that will conflict with the Homebrew-installed binary. Always use either:
- `ruby -I lib exe/knox` for development testing
- `rake brew:install` / `rake brew:reinstall` for system-wide installation

### Releasing

```bash
rake release:patch       # bump patch version, commit, and redeploy
rake release:minor       # bump minor version, commit, and redeploy
rake release:set[2.1.0]  # set explicit version, commit, and redeploy
```

## Architecture

### Core Phases

- **Phase 1**: Gem scaffolding and versioning
- **Phase 2**: DSL configuration + profile/backend structs
- **Phase 3**: Secrets (Keychain + ENV) infrastructure
- **Phase 4**: Restic runner with SSH/NAS orchestration
- **Phase 5**: Status reporting (snapshots + dedup stats)
- **Phase 6**: Scheduled backups via launchd
- **Phase 7**: Config validation and migration
- **Phase 8**: Native notifications (macOS)

### File Structure

```
lib/
  knox_train/
    cli.rb                 # Thor CLI commands
    dsl.rb                 # Configuration DSL
    profile.rb             # Profile/Backend structs
    config_loader.rb       # Config file loading
    notifications.rb       # macOS notification integration
    ssh_server.rb          # SSH + Wake-on-LAN
    restic/
      runner.rb            # Restic command execution
      status.rb            # Snapshot status reporting
    scheduler/
      launchd.rb           # macOS launchd integration
    secrets/
      keychain.rb          # macOS Keychain integration
      env.rb               # Environment variable fallback
test/
  *_test.rb                # Unit tests
```

## Contributing

Bug reports and pull requests are welcome.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
