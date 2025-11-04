require 'thor'
require 'fileutils'

module DiffGem
  class CacheCommands < Thor
    desc "clear", "Clear the cache directory"
    def clear
      cache_dir = ENV['DIFF_GEM_CACHE_DIR'] || File.expand_path('~/.diff_gem_cache')

      if File.exist?(cache_dir)
        FileUtils.rm_rf(cache_dir)
        puts "Cache cleared: #{cache_dir}"
      else
        puts "Cache directory does not exist: #{cache_dir}"
      end
    end

    desc "info", "Show cache directory information"
    def info
      cache_dir = ENV['DIFF_GEM_CACHE_DIR'] || File.expand_path('~/.diff_gem_cache')

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
      $ diff_gem rails 7.0.0 7.1.0

      $ diff_gem compare rails 7.0.0 7.1.0

      With metadata comparison:
      $ diff_gem compare --metadata rails 7.0.0 7.1.0
    LONGDESC
    option :cache_dir,
           type: :string,
           desc: "Custom cache directory for downloaded gems"
    option :metadata,
           type: :boolean,
           default: false,
           desc: "Also compare gem metadata before showing source diff"

    def compare(gem_name, old_version, new_version)
      begin
        # Show metadata comparison if requested
        if options[:metadata]
          metadata_comparer = MetadataComparer.new(
            gem_name: gem_name,
            old_version: old_version,
            new_version: new_version
          )
          metadata_comparer.compare
          puts "\n" + "=" * 80
          puts "Source Code Comparison"
          puts "=" * 80 + "\n\n"
        end

        # Show source comparison
        comparer = Comparer.new(
          gem_name: gem_name,
          old_version: old_version,
          new_version: new_version,
          cache_dir: options[:cache_dir]
        )

        comparer.compare

      rescue DiffGem::Error => e
        puts "Error: #{e.message}"
        exit 1
      rescue => e
        puts "Unexpected error: #{e.message}"
        puts e.backtrace
        exit 1
      end
    end

    desc "metadata GEM_NAME OLD_VERSION NEW_VERSION", "Compare metadata of two gem versions"
    long_desc <<-LONGDESC
      Compare the metadata (dependencies, version info, etc.) of two different
      versions of a Ruby gem without comparing source code.

      Example:
      $ diff_gem metadata rails 7.0.0 7.1.0
    LONGDESC

    def metadata(gem_name, old_version, new_version)
      begin
        metadata_comparer = MetadataComparer.new(
          gem_name: gem_name,
          old_version: old_version,
          new_version: new_version
        )
        metadata_comparer.compare

      rescue DiffGem::Error => e
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
      puts DiffGem::VERSION
    end

    desc "cache", "Manage cache directory"
    subcommand "cache", CacheCommands

    # Set compare as the default command
    default_task :compare
  end
end
