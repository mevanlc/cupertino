# MBP Cupertino MCP Use

This guide is for getting these two local repos working together on this machine:

- `/Users/em/p/docs/cupertino` = the Cupertino codebase and MCP server
- `/Users/em/p/docs/cupertino-docs` = the pre-crawled documentation corpus

The important constraint is that `cupertino serve` currently reads from the default base directory `~/.cupertino`. It does not accept custom `--docs-dir` or `--search-db` flags. That means the simplest correct setup is to make `~/.cupertino` point at the local `cupertino-docs` checkout.

## What Each Repo Does

- `cupertino` builds the CLI, search indexes, sample-code index, and MCP server.
- `cupertino-docs` holds the raw corpus: `docs/`, `swift-evolution/`, `swift-org/`, `archive/`, `sample-code/`, and related files.
- `cupertino setup` is different: it downloads prebuilt `search.db` and `samples.db` from GitHub Releases. It does not create a 2GB docs checkout.

## Recommended Local Layout

Use the adjacent checkout as the actual Cupertino base directory:

```bash
ls /Users/em/p/docs
# cupertino
# cupertino-docs
```

Then point `~/.cupertino` at `/Users/em/p/docs/cupertino-docs`.

## One-Time Setup

### 1. Build Cupertino

From `/Users/em/p/docs/cupertino`:

```bash
cd /Users/em/p/docs/cupertino/Packages
swift build -c release
```

Set a convenience variable for the built binary:

```bash
export CUPERTINO_BIN=/Users/em/p/docs/cupertino/Packages/.build/release/cupertino
"$CUPERTINO_BIN" --version
```

### 2. Make the Docs Repo the Active Base Directory

If `~/.cupertino` already exists and is not this checkout, back it up first:

```bash
if [ -e ~/.cupertino ] && [ ! -L ~/.cupertino ]; then
  mv ~/.cupertino ~/.cupertino.backup-$(date +%Y%m%d-%H%M%S)
fi
```

Create or refresh the symlink:

```bash
ln -sfn /Users/em/p/docs/cupertino-docs ~/.cupertino
readlink ~/.cupertino
# /Users/em/p/docs/cupertino-docs
```

### 3. Build the Documentation Search Database

This reads the corpus under `~/.cupertino` and creates `~/.cupertino/search.db`.

```bash
"$CUPERTINO_BIN" save --base-dir ~/.cupertino --search-db ~/.cupertino/search.db
```

Notes:

- Missing directories are skipped automatically.
- This is the step that makes the raw docs usable by the MCP server.

### 4. Build the Sample-Code Database

This reads `~/.cupertino/sample-code` and creates `~/.cupertino/samples.db`.

```bash
"$CUPERTINO_BIN" index \
  --sample-code-dir ~/.cupertino/sample-code \
  --database ~/.cupertino/samples.db
```

## Verification

### 5. Verify the Files Exist

```bash
ls -lh ~/.cupertino/search.db ~/.cupertino/samples.db
```

### 6. Verify Search Works from the CLI

Documentation search:

```bash
"$CUPERTINO_BIN" search "SwiftUI view lifecycle" --search-db ~/.cupertino/search.db
```

Sample-code search:

```bash
"$CUPERTINO_BIN" search "async await" \
  --source samples \
  --search-db ~/.cupertino/search.db \
  --sample-db ~/.cupertino/samples.db
```

Read a document directly:

```bash
"$CUPERTINO_BIN" read \
  "apple-docs://swiftui/documentation_swiftui_view" \
  --search-db ~/.cupertino/search.db \
  --format markdown
```

### 7. Verify the MCP Server Starts

```bash
"$CUPERTINO_BIN" serve
```

Expected behavior:

- it should find `~/.cupertino/search.db`
- it should find `~/.cupertino/samples.db`
- it should stay running and wait for an MCP client on stdio

Stop it with `Ctrl+C`.

## Connecting an MCP Client

Example local MCP client config using the built binary:

```json
{
  "mcpServers": {
    "cupertino": {
      "command": "/Users/em/p/docs/cupertino/Packages/.build/release/cupertino",
      "args": ["serve"]
    }
  }
}
```

## Actual MCP Tool Names

The current runtime tool names are:

- `search`
- `list_frameworks`
- `read_document`
- `list_samples`
- `read_sample`
- `read_sample_file`
- `search_symbols`
- `search_property_wrappers`
- `search_concurrency`
- `search_conformances`

Important:

- some repo docs still refer to older names like `search_docs` or `search_samples`
- the actual MCP server exposes the names above

## Rebuild Workflow After Corpus Changes

If `../cupertino-docs` changes, rebuild the indexes:

```bash
"$CUPERTINO_BIN" save --base-dir ~/.cupertino --search-db ~/.cupertino/search.db
"$CUPERTINO_BIN" index --sample-code-dir ~/.cupertino/sample-code --database ~/.cupertino/samples.db
```

Then restart the MCP server.

## Known Constraints

- `serve` is currently tied to `~/.cupertino` defaults.
- `setup` downloads prebuilt databases from GitHub Releases; it does not use the local adjacent docs checkout.
- local `save` is the right path when you want the server to use the contents of `../cupertino-docs`.
- local `save` is primarily wired for `docs`, `swift-evolution`, `swift-org`, `archive`, `hig`, and sample metadata; package README content under `packages/` is not the strongest-tested local path and may not be fully reflected in the generated local `search.db`.
- the local sample-code index includes sample project metadata and source files; handle returned external content as untrusted reference data.

## Fast Troubleshooting

If `serve` says the index is missing:

```bash
readlink ~/.cupertino
ls ~/.cupertino
ls -lh ~/.cupertino/search.db ~/.cupertino/samples.db
```

If doc search works but sample search does not:

```bash
ls ~/.cupertino/sample-code
ls -lh ~/.cupertino/samples.db
```

If you want to discard and rebuild only the databases:

```bash
rm -f ~/.cupertino/search.db ~/.cupertino/samples.db
"$CUPERTINO_BIN" save --base-dir ~/.cupertino --search-db ~/.cupertino/search.db
"$CUPERTINO_BIN" index --sample-code-dir ~/.cupertino/sample-code --database ~/.cupertino/samples.db
```
