# Diff Gem

Compare the source code and metadata between two versions of a Ruby gem.

## Installation

```bash
gem install diff_gem
```

Or install locally:

```bash
gem build diff_gem.gemspec
gem install diff_gem-0.1.0.gem
```

## Usage

### Compare Source Code

Compare two versions of a gem:

```bash
diff_gem GEM_NAME OLD_VERSION NEW_VERSION
```

Example:

```bash
diff_gem rails 7.0.0 7.0.1
```

Or use the explicit command:

```bash
diff_gem compare rails 7.0.0 7.0.1
```

### Compare Metadata

Compare gem metadata (dependencies, version info, file counts, etc.) without comparing source:

```bash
diff_gem metadata rails 7.0.0 7.0.1
```

### Compare Both

Compare metadata and source code together:

```bash
diff_gem compare --metadata rails 7.0.0 7.0.1
```

### Cache Management

View cache information:

```bash
diff_gem cache info
```

Clear the cache:

```bash
diff_gem cache clear
```

### Custom Cache Directory

You can specify a custom cache directory:

```bash
diff_gem --cache-dir /tmp/gem_cache rails 7.0.0 7.0.1
```

Or set the environment variable:

```bash
export DIFF_GEM_CACHE_DIR=/tmp/gem_cache
diff_gem rails 7.0.0 7.0.1
```

## How It Works

**Source Comparison:**
1. Downloads both gem versions from rubygems.org
2. Extracts the gem source code to a cache directory
3. Runs `diff -r -u -N` to compare the source trees
4. Displays the unified diff output

**Metadata Comparison:**
1. Downloads gem metadata from rubygems.org
2. Extracts and parses the gemspec information
3. Compares dependencies, file counts, version requirements, and other metadata
4. Displays a structured comparison showing added, removed, and changed fields

Downloaded gems are cached in `~/.diff_gem_cache` by default, so subsequent comparisons are faster.

## Similar Tools

If `diff_gem` doesn't meet your needs, you might want to check out these alternatives:

- **[gemdiff](https://github.com/teeparham/gemdiff)** - Compare gem versions with GitHub integration, showing commits between releases and opening diffs in the browser
- **[gem-compare](https://github.com/sj26/gem-compare)** - Another tool for comparing gem versions with a focus on simplicity

`diff_gem` focuses on providing both detailed source code diffs and comprehensive metadata comparisons in a command-line interface.

## License

MIT
