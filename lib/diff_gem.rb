require_relative "diff_gem/version"
require_relative "diff_gem/gem_extractor"
require_relative "diff_gem/comparer"
require_relative "diff_gem/metadata_comparer"
require_relative "diff_gem/cli"

module DiffGem
  class Error < StandardError; end
end
