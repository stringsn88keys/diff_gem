require 'thor'
require 'fileutils'

module GemCompare
  class CacheCommands < Thor
    desc "clear", "Clear the cache directory"
    def clear
      cache_dir = ENV['GEM_COMPARE_CACHE_DIR'] || File.expand_path('~/.gem_compare_cache')

      if File.exist?(cache_dir)
        FileUtils.rm_rf(cache_dir)
        puts "Cache cleared: #{cache_dir}"
      else
        puts "Cache directory does not exist: #{cache_dir}"
      end
    end

    desc "info", "Show cache directory information"
    def info
      cache_dir = ENV['GEM_COMPARE_CACHE_DIR'] || File.expand_path('~/.gem_compare_cache')

      puts "Cache directory: #{cache_dir}"

      if File.exist?(cache_dir)
        gem_dirs = Dir.glob(File.join(cache_dir, '*', '*')).select { |f| File.directory?(f) }

        size = `du -sh "#{cache_dir}" 2>/dev/null`.split.first rescue "unknown"

        puts "Status: exists"
        puts "Size: #{size}"
        puts "Cached gem versions: #{gem_dirs.length}"

        if gem_dirs.any?
          puts "\nCached gems:"
          gem_dirs.each do |dir|
            parts = dir.split('/')
            version = parts[-1]
            name = parts[-2]
            puts "  #{name} #{version}"
          end
        end
      else
        puts "Status: does not exist"
      end
    end
  end

  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "compare GEM_NAME OLD_VERSION NEW_VERSION", "Compare two versions of a Ruby gem"
    long_desc <<-LONGDESC
      Compare the source trees of two different versions of a Ruby gem.

      Downloads both gem versions, extracts their source code, and displays
      the differences in unified diff format.

      Example:
      $ gemcompare rails 7.0.0 7.1.0

      $ gemcompare compare rails 7.0.0 7.1.0
    LONGDESC
    option :cache_dir,
           type: :string,
           desc: "Custom cache directory for downloaded gems"

    def compare(gem_name, old_version, new_version)
      begin
        comparer = Comparer.new(
          gem_name: gem_name,
          old_version: old_version,
          new_version: new_version,
          cache_dir: options[:cache_dir]
        )

        comparer.compare

      rescue GemCompare::Error => e
        puts "Error: #{e.message}"
        exit 1
      rescue => e
        puts "Unexpected error: #{e.message}"
        puts e.backtrace
        exit 1
      end
    end

    desc "version", "Show version"
    def version
      puts GemCompare::VERSION
    end

    desc "cache", "Manage cache directory"
    subcommand "cache", CacheCommands

    # Set compare as the default command
    default_task :compare
  end
end
