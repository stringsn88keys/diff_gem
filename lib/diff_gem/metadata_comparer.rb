require 'yaml'
require 'json'
require 'rubygems/package'
require 'zlib'
require 'net/http'

module DiffGem
  class MetadataComparer
    attr_reader :gem_name, :old_version, :new_version

    def initialize(gem_name:, old_version:, new_version:)
      @gem_name = gem_name
      @old_version = old_version
      @new_version = new_version
    end

    def compare
      puts "Fetching metadata for #{gem_name}..."

      old_spec = fetch_gem_spec(gem_name, old_version)
      new_spec = fetch_gem_spec(gem_name, new_version)

      puts "\n" + "=" * 80
      puts "Metadata Comparison: #{gem_name} #{old_version} → #{new_version}"
      puts "=" * 80 + "\n"

      compare_basic_info(old_spec, new_spec)
      compare_dependencies(old_spec, new_spec)
      compare_files(old_spec, new_spec)
      compare_metadata(old_spec, new_spec)
    end

    private

    def fetch_gem_spec(gem_name, version)
      gem_filename = "#{gem_name}-#{version}.gem"
      gem_url = "https://rubygems.org/downloads/#{gem_filename}"

      begin
        uri = URI(gem_url)

        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          request = Net::HTTP::Get.new(uri)
          request['User-Agent'] = 'DiffGem Ruby Gem Comparator'
          gem_data = http.request(request)

          if gem_data.code != '200'
            raise Error, "Failed to download #{gem_name} #{version}: HTTP #{gem_data.code}"
          end

          # Parse the gem file to extract metadata
          io = StringIO.new(gem_data.body)

          tar_reader = begin
            Gem::Package::TarReader.new(Zlib::GzipReader.new(io))
          rescue Zlib::GzipFile::Error
            io.rewind
            Gem::Package::TarReader.new(io)
          end

          metadata = nil
          tar_reader.each do |entry|
            if entry.full_name == 'metadata.gz'
              metadata = Zlib::GzipReader.new(StringIO.new(entry.read)).read
              break
            elsif entry.full_name == 'metadata'
              metadata = entry.read
              break
            end
          end
          tar_reader.close

          raise Error, "No metadata found in gem" unless metadata

          # Use safe_load with permitted classes for security
          permitted_classes = [
            Gem::Specification,
            Gem::Version,
            Gem::Requirement,
            Gem::Dependency,
            Time,
            Symbol,
            Date,
            DateTime
          ]

          YAML.safe_load(metadata, permitted_classes: permitted_classes, aliases: true)
        end

      rescue => e
        raise Error, "Failed to fetch metadata for #{gem_name} #{version}: #{e.message}"
      end
    end

    def compare_basic_info(old_spec, new_spec)
      puts "Basic Information:"
      puts "-" * 80

      compare_field("Name", old_spec.name, new_spec.name)
      compare_field("Version", old_spec.version.to_s, new_spec.version.to_s)
      compare_field("Authors", old_spec.authors.join(', '), new_spec.authors.join(', '))
      compare_field("Email", old_spec.email, new_spec.email)
      compare_field("Homepage", old_spec.homepage, new_spec.homepage)
      compare_field("License", old_spec.license || old_spec.licenses.join(', '),
                              new_spec.license || new_spec.licenses.join(', '))
      compare_field("Summary", old_spec.summary, new_spec.summary)
      compare_field("Description", old_spec.description, new_spec.description)
      compare_field("Ruby Version Required", old_spec.required_ruby_version.to_s,
                                           new_spec.required_ruby_version.to_s)
      compare_field("RubyGems Version Required", old_spec.required_rubygems_version.to_s,
                                                new_spec.required_rubygems_version.to_s)

      puts
    end

    def compare_dependencies(old_spec, new_spec)
      puts "Runtime Dependencies:"
      puts "-" * 80

      old_deps = old_spec.dependencies.select { |d| d.type == :runtime }
      new_deps = new_spec.dependencies.select { |d| d.type == :runtime }

      compare_dependency_list(old_deps, new_deps)

      puts "\nDevelopment Dependencies:"
      puts "-" * 80

      old_dev_deps = old_spec.dependencies.select { |d| d.type == :development }
      new_dev_deps = new_spec.dependencies.select { |d| d.type == :development }

      compare_dependency_list(old_dev_deps, new_dev_deps)

      puts
    end

    def compare_dependency_list(old_deps, new_deps)
      old_dep_hash = old_deps.each_with_object({}) { |d, h| h[d.name] = d }
      new_dep_hash = new_deps.each_with_object({}) { |d, h| h[d.name] = d }

      all_dep_names = (old_dep_hash.keys + new_dep_hash.keys).uniq.sort

      if all_dep_names.empty?
        puts "  (none)"
        return
      end

      all_dep_names.each do |name|
        old_dep = old_dep_hash[name]
        new_dep = new_dep_hash[name]

        if old_dep && !new_dep
          puts "  - #{name} #{old_dep.requirement} (REMOVED)"
        elsif !old_dep && new_dep
          puts "  + #{name} #{new_dep.requirement} (ADDED)"
        elsif old_dep.requirement.to_s != new_dep.requirement.to_s
          puts "  ~ #{name}: #{old_dep.requirement} → #{new_dep.requirement}"
        else
          puts "    #{name} #{new_dep.requirement}"
        end
      end
    end

    def compare_files(old_spec, new_spec)
      puts "Files:"
      puts "-" * 80

      old_files = old_spec.files.sort
      new_files = new_spec.files.sort

      removed = old_files - new_files
      added = new_files - old_files
      unchanged = old_files & new_files

      puts "  Total files: #{old_files.length} → #{new_files.length}"

      if added.any?
        puts "\n  Added (#{added.length}):"
        added.first(10).each { |f| puts "    + #{f}" }
        puts "    ... and #{added.length - 10} more" if added.length > 10
      end

      if removed.any?
        puts "\n  Removed (#{removed.length}):"
        removed.first(10).each { |f| puts "    - #{f}" }
        puts "    ... and #{removed.length - 10} more" if removed.length > 10
      end

      puts "\n  Unchanged: #{unchanged.length} files"
      puts
    end

    def compare_metadata(old_spec, new_spec)
      puts "Additional Metadata:"
      puts "-" * 80

      old_metadata = old_spec.metadata || {}
      new_metadata = new_spec.metadata || {}

      all_keys = (old_metadata.keys + new_metadata.keys).uniq.sort

      if all_keys.empty?
        puts "  (none)"
        puts
        return
      end

      all_keys.each do |key|
        old_value = old_metadata[key]
        new_value = new_metadata[key]

        if old_value && !new_value
          puts "  - #{key}: #{old_value}"
        elsif !old_value && new_value
          puts "  + #{key}: #{new_value}"
        elsif old_value != new_value
          puts "  ~ #{key}:"
          puts "      #{old_value}"
          puts "    → #{new_value}"
        else
          puts "    #{key}: #{new_value}"
        end
      end

      puts
    end

    def compare_field(label, old_value, new_value)
      old_value = old_value.to_s.strip
      new_value = new_value.to_s.strip

      if old_value != new_value && !old_value.empty?
        puts "  ~ #{label}:"
        puts "      #{old_value}"
        puts "    → #{new_value}"
      else
        puts "    #{label}: #{new_value}"
      end
    end
  end
end
