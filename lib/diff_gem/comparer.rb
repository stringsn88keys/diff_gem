require 'fileutils'
require 'English'

module DiffGem
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
      status = if windows?
                 run_windows_diff(old_path, new_path)
               else
                 run_unix_diff(old_path, new_path)
               end

      handle_diff_exit(status)
    end

    def default_cache_dir
      ENV['DIFF_GEM_CACHE_DIR'] || File.expand_path('~/.diff_gem_cache')
    end

    def windows?
      (/mswin|mingw|cygwin|bccwin/i).match?(RUBY_PLATFORM)
    end

    def run_unix_diff(old_path, new_path)
      # Use unified diff to closely match traditional diff output on Unix-like systems
      system('diff', '-r', '-u', '-N', old_path.to_s, new_path.to_s)
      $CHILD_STATUS
    end

    def run_windows_diff(old_path, new_path)
      script = windows_compare_script(old_path, new_path)
      system('powershell.exe', '-NoProfile', '-Command', script)
      $CHILD_STATUS
    end

    def handle_diff_exit(status)
      raise Error, 'Failed to execute diff command' if status.nil?
      return if status.exitstatus <= 1

      raise Error, "Failed to generate diff (exit status: #{status.exitstatus})"
    end

    def windows_compare_script(old_path, new_path)
      escaped_old = escape_for_powershell(old_path)
      escaped_new = escape_for_powershell(new_path)

      <<~POWERSHELL
        $ErrorActionPreference = 'Stop'
        $old = '#{escaped_old}'
        $new = '#{escaped_new}'
        $hasDifferences = $false

        function Write-Line {
          param([string]$text)
          [Console]::Out.WriteLine($text)
        }

        function Get-RelativePath {
          param(
            [string]$root,
            [string]$full
          )

          $normalizedRoot = [System.IO.Path]::GetFullPath($root)
          if (-not $normalizedRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $normalizedRoot += [System.IO.Path]::DirectorySeparatorChar
          }

          $normalizedFull = [System.IO.Path]::GetFullPath($full)
          return $normalizedFull.Substring($normalizedRoot.Length).Replace('\\', '/')
        }

        function Get-FileMap {
          param([string]$root)

          $map = @{}
          if (-not (Test-Path -LiteralPath $root)) {
            return $map
          }

          Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {
            $relative = Get-RelativePath $root $_.FullName
            $map[$relative] = $_.FullName
          }

          return $map
        }

        function Read-FileLines {
          param([string]$path)

          try {
            return Get-Content -LiteralPath $path -ErrorAction Stop
          } catch {
            return $null
          }
        }

        function Write-DiffHeader {
          param(
            [Parameter(Mandatory = $true)][string]$relative,
            [string]$oldTarget,
            [string]$newTarget
          )

          if (-not $oldTarget) { $oldTarget = "a/$relative" }
          if (-not $newTarget) { $newTarget = "b/$relative" }

          Write-Line "diff --git a/$relative b/$relative"
          Write-Line "--- $oldTarget"
          Write-Line "+++ $newTarget"
        }

        function Write-LineDiff {
          param(
            [string]$oldPath,
            [string]$newPath,
            [string]$relative
          )

          $oldLines = Read-FileLines $oldPath
          $newLines = Read-FileLines $newPath

          if ($null -eq $oldLines -or $null -eq $newLines) {
            Write-Line "Binary files differ: $relative"
            Write-Line ''
            return $true
          }

          $diff = Compare-Object -ReferenceObject $oldLines -DifferenceObject $newLines -IncludeEqual:$false

          if (-not $diff) {
            return $false
          }

          Write-DiffHeader -relative $relative

          foreach ($entry in $diff) {
            $prefix = if ($entry.SideIndicator -eq '<=') { '-' } else { '+' }
            $line = [string]$entry.InputObject
            Write-Line "$prefix$line"
          }

          Write-Line ''
          return $true
        }

        $oldFiles = Get-FileMap $old
        $newFiles = Get-FileMap $new

        $allPaths = (@($oldFiles.Keys) + @($newFiles.Keys)) | Sort-Object -Unique

        foreach ($path in $allPaths) {
          $oldExists = $oldFiles.ContainsKey($path)
          $newExists = $newFiles.ContainsKey($path)

          if (-not $oldExists -and $newExists) {
            $newPathFull = $newFiles[$path]
            $newLines = Read-FileLines $newPathFull

            if ($null -eq $newLines) {
              Write-Line "Binary file added: $path"
              Write-Line ''
            } else {
              Write-DiffHeader -relative $path -oldTarget '/dev/null' -newTarget "b/$path"

              foreach ($line in $newLines) {
                Write-Line "+$line"
              }

              Write-Line ''
            }

            $hasDifferences = $true
            continue
          }

          if ($oldExists -and -not $newExists) {
            $oldPathFull = $oldFiles[$path]
            $oldLines = Read-FileLines $oldPathFull

            if ($null -eq $oldLines) {
              Write-Line "Binary file removed: $path"
              Write-Line ''
            } else {
              Write-DiffHeader -relative $path -oldTarget "a/$path" -newTarget '/dev/null'

              foreach ($line in $oldLines) {
                Write-Line "-$line"
              }

              Write-Line ''
            }

            $hasDifferences = $true
            continue
          }

          $oldPathFull = $oldFiles[$path]
          $newPathFull = $newFiles[$path]

          if (Write-LineDiff -oldPath $oldPathFull -newPath $newPathFull -relative $path) {
            $hasDifferences = $true
          }
        }

        if ($hasDifferences) {
          exit 1
        } else {
          exit 0
        }
      POWERSHELL
    end

    def escape_for_powershell(path)
      path.to_s.gsub("'", "''")
    end
  end
end
