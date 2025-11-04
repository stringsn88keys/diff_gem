require 'fileutils'
require 'rubygems/package'
require 'zlib'
require 'stringio'
require 'open-uri'
require 'net/http'

module DiffGem
  class GemExtractor
    attr_reader :cache_dir

    def initialize(cache_dir)
      @cache_dir = cache_dir
      ensure_cache_dir_exists
    end

    def extract_gem(gem_name, version)
      gem_cache_dir = File.join(cache_dir, gem_name, version)

      # Return existing path if already downloaded and extracted
      if File.exist?(gem_cache_dir) && !Dir.empty?(gem_cache_dir)
        puts "  Using cached: #{gem_name} #{version}"
        return gem_cache_dir
      end

      puts "  Downloading: #{gem_name} #{version}"

      # Ensure directory exists
      FileUtils.mkdir_p(gem_cache_dir)

      # Download gem file
      gem_file_path = download_gem(gem_name, version)

      # Extract gem contents
      extract_gem_archive(gem_file_path, gem_cache_dir)

      # Clean up downloaded gem file
      File.delete(gem_file_path) if File.exist?(gem_file_path)

      gem_cache_dir
    end

    private

    def download_gem(gem_name, version)
      gem_filename = "#{gem_name}-#{version}.gem"
      gem_file_path = File.join(cache_dir, gem_filename)

      # Try to download from rubygems.org
      gem_url = "https://rubygems.org/downloads/#{gem_filename}"

      begin
        uri = URI(gem_url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          request = Net::HTTP::Get.new(uri)
          response = http.request(request)

          if response.code == '200'
            File.open(gem_file_path, 'wb') do |file|
              file.write(response.body)
            end
          else
            raise Error, "Failed to download #{gem_name} #{version}: HTTP #{response.code}"
          end
        end

        gem_file_path
      rescue => e
        raise Error, "Failed to download #{gem_name} #{version}: #{e.message}"
      end
    end

    def extract_gem_archive(gem_file_path, extract_dir)
      begin
        # Modern gems can be either gzipped tar or plain tar
        File.open(gem_file_path, 'rb') do |gem_file|
          # Try to read as gzipped first
          tar_reader = begin
            Gem::Package::TarReader.new(Zlib::GzipReader.new(gem_file))
          rescue Zlib::GzipFile::Error
            # If not gzipped, rewind and read as plain tar
            gem_file.rewind
            Gem::Package::TarReader.new(gem_file)
          end

          tar_reader.each do |entry|
            next unless entry.file?

            # Extract data.tar.gz which contains the actual gem files
            if entry.full_name == 'data.tar.gz'
              extract_data_tar(entry, extract_dir, compressed: true)
              break
            # Some gems might have uncompressed data.tar
            elsif entry.full_name == 'data.tar'
              extract_data_tar(entry, extract_dir, compressed: false)
              break
            end
          end

          tar_reader.close
        end
      rescue => e
        raise Error, "Failed to extract #{gem_file_path}: #{e.message}"
      end
    end

    def extract_data_tar(data_tar_entry, extract_dir, compressed:)
      data = data_tar_entry.read

      tar_reader = if compressed
        Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(data)))
      else
        Gem::Package::TarReader.new(StringIO.new(data))
      end

      tar_reader.each do |entry|
        next if entry.directory?

        file_path = File.join(extract_dir, entry.full_name)

        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(file_path))

        # Write file contents
        File.open(file_path, 'wb') do |file|
          file.write(entry.read)
        end

        # Preserve file permissions
        File.chmod(entry.header.mode, file_path) if entry.header.mode
      end

      tar_reader.close
    end

    def ensure_cache_dir_exists
      FileUtils.mkdir_p(cache_dir)
    end
  end
end
