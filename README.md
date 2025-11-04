# GemCompare

Compare the source code between two versions of a Ruby gem.

## Installation

```bash
gem install gem_compare
```

Or install locally:

```bash
gem build gem_compare.gemspec
gem install gem_compare-0.1.0.gem
```

## Usage

Compare two versions of a gem:

```bash
gemcompare GEM_NAME OLD_VERSION NEW_VERSION
```

Example:

```bash
gemcompare rails 7.0.0 7.0.1
```

Or use the explicit command:

```bash
gemcompare compare rails 7.0.0 7.0.1
```

### Cache Management

View cache information:

```bash
gemcompare cache info
```

Clear the cache:

```bash
gemcompare cache clear
```

### Custom Cache Directory

You can specify a custom cache directory:

```bash
gemcompare --cache-dir /tmp/gem_cache rails 7.0.0 7.0.1
```

Or set the environment variable:

```bash
export GEM_COMPARE_CACHE_DIR=/tmp/gem_cache
gemcompare rails 7.0.0 7.0.1
```

## How It Works

1. Downloads both gem versions from rubygems.org
2. Extracts the gem source code to a cache directory
3. Runs `diff -r -u -N` to compare the source trees
4. Displays the unified diff output

Downloaded gems are cached in `~/.gem_compare_cache` by default, so subsequent comparisons are faster.

## License

MIT
