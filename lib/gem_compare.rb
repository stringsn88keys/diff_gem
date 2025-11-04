require_relative "gem_compare/version"
require_relative "gem_compare/gem_extractor"
require_relative "gem_compare/comparer"
require_relative "gem_compare/cli"

module GemCompare
  class Error < StandardError; end
end
