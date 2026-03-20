# index

Index sample code for search

## Synopsis

```bash
cupertino index [--sample-code-dir <dir>] [--database <path>] [--force] [--clear] [--include-docs]
```

## Description

Indexes Apple sample code projects for full-text search. Creates a separate database (`~/.cupertino/samples.db`) optimized for code-level search, distinct from the documentation search database.

By default, Cupertino indexes code and project metadata only. README and markdown/text files are excluded unless you pass `--include-docs`, which reduces prompt-injection exposure when this data is later shown to an AI assistant.

**Important:** Run `cupertino cleanup` before indexing to remove unnecessary files from sample code archives. This reduces index size and improves search quality.

## Workflow

```bash
# 1. Download sample code
cupertino fetch --type code

# 2. Clean up archives (required)
cupertino cleanup

# 3. Index for search
cupertino index
```

## Options

| Option | Description |
|--------|-------------|
| `--sample-code-dir` | Sample code directory (default: `~/.cupertino/sample-code`) |
| `--database` | Database path (default: `~/.cupertino/samples.db`) |
| `--force` | Force reindex all projects (even if already indexed) |
| `--clear` | Clear existing index before indexing |
| `--include-docs` | Also index README and markdown/text files |

## Examples

### Index All Sample Code

```bash
cupertino index
```

### Force Reindex All

```bash
cupertino index --force
```

### Include README and Markdown/Text Files

```bash
cupertino index --include-docs
```

### Clear and Rebuild

```bash
cupertino index --clear
```

### Custom Paths

```bash
cupertino index --sample-code-dir ~/my-samples --database ~/my-db.sqlite
```

## What Gets Indexed

### Project Metadata
- Title and description
- Frameworks used
- Web URL on Apple Developer

README content is only indexed when `--include-docs` is enabled.

### Source Files

| Extension | Language/Type |
|-----------|---------------|
| `.swift` | Swift |
| `.h`, `.m`, `.mm` | Objective-C |
| `.c`, `.cpp`, `.hpp` | C/C++ |
| `.metal` | Metal shaders |
| `.plist`, `.json`, `.strings` | Config/Data |
| `.entitlements`, `.xcconfig` | Xcode config |
| `.storyboard`, `.xib` | Interface Builder |

When `--include-docs` is enabled, `.md`, `.txt`, and `.rtf` files are indexed too.

## Database Schema

Two FTS5-enabled tables:

- **projects** - Project metadata and optional README (full-text searchable when `--include-docs` is used)
- **files** - Individual source files with folder paths

## Output

Shows progress and statistics:
- Projects indexed
- Total projects and files
- Duration
- Database size

## MCP Tools

After indexing, sample code is searchable via MCP tools:

| Tool | Description |
|------|-------------|
| `search_samples` | Search projects and code |
| `list_samples` | List all indexed projects |
| `read_sample` | Read project metadata and optional README |
| `read_sample_file` | Read specific source file |

## Notes

- First run may take several minutes depending on number of projects
- Incremental indexing: only new projects are indexed by default
- Use `--force` to update metadata from catalog changes
- Database uses FTS5 with BM25 ranking for relevance scoring
- Returned sample content should be treated as untrusted external data by AI clients
