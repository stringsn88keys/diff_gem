require 'fileutils'

module GemCompare
  class Comparer
    attr_reader :gem_name, :old_version, :new_version, :cache_dir

    def initialize(gem_name:, old_version:, new_version:, cache_dir: nil)
      @gem_name = gem_name
      @old_version = old_version
      @new_version = new_version
      @cache_dir = cache_dir || default_cache_dir
    end

    def compare
      puts "Comparing #{gem_name}: #{old_version} -> #{new_version}\n\n"

      extractor = GemExtractor.new(cache_dir)

      # Extract both versions
      old_path = extractor.extract_gem(gem_name, old_version)
      new_path = extractor.extract_gem(gem_name, new_version)

      puts "\nGenerating diff...\n\n"

      # Generate and display diff
      generate_diff(old_path, new_path)
    end

    private

    def generate_diff(old_path, new_path)
      # Use system diff command to generate comprehensive diff
      # The diff command will:
      # - Compare directories recursively (-r)
      # - Use unified format (-u) for better readability
      # - Show files that exist in only one directory (-N)
      system("diff -r -u -N '#{old_path}' '#{new_path}'")

      # diff returns non-zero exit status when there are differences,
      # which is expected behavior
      if $?.exitstatus > 1
        raise Error, "Failed to generate diff (exit status: #{$?.exitstatus})"
      end
    end

    def default_cache_dir
      ENV['GEM_COMPARE_CACHE_DIR'] || File.expand_path('~/.gem_compare_cache')
    end
  end
end
