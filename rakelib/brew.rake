TAP_PATH = "file:///Users/travis/Projects/Personal/knox_train2/tap"
TAP_NAME = "tlrasor/knox"

namespace :brew do
  desc "Install knox via Homebrew tap (first time setup)"
  task :install do
    sh "brew tap #{TAP_NAME} #{TAP_PATH}"
    sh "brew install #{TAP_NAME}/knox_train"
    sh "knox version"
  end

  desc "Reinstall knox via Homebrew (use after any code change)"
  task :reinstall do
    sh "brew uninstall #{TAP_NAME}/knox_train 2>/dev/null || true"
    sh "brew untap #{TAP_NAME} 2>/dev/null || true"
    sh "brew tap #{TAP_NAME} #{TAP_PATH}"
    sh "brew install #{TAP_NAME}/knox_train"
    sh "knox version"
  end

  desc "Fully uninstall knox (removes Homebrew install and tap)"
  task :uninstall do
    sh "knox unschedule --all 2>/dev/null || true"
    sh "brew uninstall #{TAP_NAME}/knox_train 2>/dev/null || true"
    sh "brew untap #{TAP_NAME} 2>/dev/null || true"
    puts "Uninstall complete."
    puts "Optional cleanup:"
    puts "  rm -rf ~/Library/Logs/knox"
  end
end
