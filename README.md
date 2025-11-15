# MerkleTrie

[![CI/CD Pipeline](https://github.com/your-repo/MerkleTrie/workflows/CI/badge.svg)](https://github.com/your-repo/MerkleTrie/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A persistent, deterministic Merkle tree database implementation in Erlang.

## Features

The goal of this project is to provide:

1. **Merkle tree database on disk** - Persistent storage with cryptographic proofs
2. **Deterministic root hash** - Root hash is deterministically derived from contents; order of insertion/deletion doesn't matter
3. **Historical state queries** - Look up the state at any point in history
4. **Append-only immutable datastructure** - No destructive updates, perfect for consensus-critical applications

## Quick Start

### Using Make (Recommended)

```bash
# Automated setup (downloads dependencies, compiles, tests)
make bare-metal

# Start interactive shell
make shell

# Run tests
make test

# View all available commands
make help
```

### Traditional Method

```bash
# First, ensure Erlang/OTP 25+ is installed
# Download and compile
./rebar3 compile

# Run the software
sh start.sh
```

### Using Docker

```bash
# Development environment
docker-compose --profile dev up -d
docker-compose exec trie-dev /bin/bash

# Production deployment
docker-compose up -d

# Run tests in container
docker-compose --profile test run --rm trie-test
```

## Installation

### Prerequisites

- **Erlang/OTP 25.3+** (27.1 recommended)
- **Rebar3** (automatically downloaded by Makefile)
- **Git**

### Automated Setup

For bare metal deployment with full environment setup:

```bash
chmod +x scripts/bare-metal-setup.sh
./scripts/bare-metal-setup.sh
```

This script will:
- Detect your OS and install Erlang/OTP
- Install Rebar3
- Fetch dependencies
- Compile the project
- Run tests and smoke tests
- Optionally set up systemd service

Supported platforms: Ubuntu, Debian, Fedora, RHEL, CentOS, Arch Linux, macOS

### Manual Installation

See [INFRASTRUCTURE.md](INFRASTRUCTURE.md#bare-metal-deployment) for detailed manual installation instructions.

## Usage

For detailed usage examples, see [src/test_trie.erl](src/test_trie.erl).

### Basic Operations

```erlang
% Start the trie
Id = my_trie,
Cfg = cfg:new(Id, 8, 32, 0, 12, hd),
trie_sup:start_link(Cfg),

% PUT a value
Key = <<1,2,3,4,5,6,7,8>>,
Value = <<100,101,102,103>>,
trie:put(Key, Value, 1, 1, Id),

% GET a value with proof
{RootHash, Leaf, Proof} = trie:get(Key, 1, Id),

% Verify the proof
verify:leaf(RootHash, Key, Leaf, Proof),

% DELETE a value
trie:delete(Key, 2, Id),

% Compute root hash
RootHash = trie:root_hash(1, Id).
```

### Batch Operations

```erlang
% Batch PUT
KVList = [{<<1,0,0,0,0,0,0,0>>, <<1:32>>},
          {<<2,0,0,0,0,0,0,0>>, <<2:32>>},
          {<<3,0,0,0,0,0,0,0>>, <<3:32>>}],
trie:put_batch(KVList, 1, Id).
```

## Architecture

### Core Modules

- **trie.erl** - Main trie gen_server
- **store.erl** - Storage and proof generation
- **stem.erl** - Tree node structure (16-ary branching)
- **leaf.erl** - Leaf node structure
- **verify.erl** - Merkle proof verification
- **prune.erl** - Historical data pruning

### Data Structure

MerkleTrie uses a 16-ary tree structure where:
- Each stem node has 16 child pointers
- Paths are determined by key bits
- Leaves contain actual key-value data
- All data is cryptographically hashed

## Testing

### Quick Test

```bash
make test              # All tests
make eunit             # Unit tests only
make proper            # Property-based tests
make smoke-test        # Smoke tests
```

### Comprehensive Testing

```bash
make ci                # Full CI pipeline locally
make coverage          # Generate coverage report
make load-test         # Performance benchmarking
```

### Test Organization

- `test/trie_tests.erl` - EUnit integration tests
- `test/smoke_tests.erl` - Comprehensive smoke tests
- `test/prop_*.erl` - Property-based tests (PropEr)

## Development

### Build Commands

```bash
make compile           # Compile project
make clean             # Clean build artifacts
make deps              # Fetch dependencies
make shell             # Start Erlang REPL
make release           # Build production release
```

### Code Quality

```bash
make check             # Run all static analysis
make dialyzer          # Type checking
make xref              # Cross-reference analysis
make format            # Format code
```

### Git Hooks

Install pre-commit hooks for automatic quality checks:

```bash
./scripts/install-hooks.sh
```

## Infrastructure

This project includes comprehensive build, test, and deployment infrastructure:

- **GitHub Actions CI/CD** - Automated testing on multiple OTP versions
- **Docker/Docker Compose** - Containerized development and deployment
- **Makefile** - Standardized build commands
- **Smoke Tests** - Comprehensive validation suite
- **Load Testing** - basho_bench integration
- **Security Scanning** - Automated vulnerability detection

For complete infrastructure documentation, see [INFRASTRUCTURE.md](INFRASTRUCTURE.md).

## Performance

Typical performance on modern hardware:
- **PUT operations:** ~10,000-50,000 ops/sec
- **GET operations:** ~20,000-100,000 ops/sec
- **Root hash computation:** ~1,000-5,000 ops/sec

Run benchmarks: `make load-test`

## Production Deployment

### Build Release

```bash
make release
```

### Deploy

```bash
# Copy to production server
scp -r _build/prod/rel/trie/ user@server:/opt/trie/

# On server, start the service
cd /opt/trie
./bin/trie start
./bin/trie ping
```

### Docker Deployment

```bash
# Build image
docker build -t merkletrie:latest .

# Run production container
docker run -d \
  -p 8080:8080 \
  -v merkletrie-data:/opt/trie/data \
  --name merkletrie \
  merkletrie:latest
```

## Real-World Usage

MerkleTrie is used in production by:
- [Amoveo](https://github.com/zack-bitcoin/amoveo) - Blockchain implementation

## Documentation

- [INFRASTRUCTURE.md](INFRASTRUCTURE.md) - Complete infrastructure guide
- [docs/todo.md](docs/todo.md) - Known issues and roadmap
- [docs/hashdepth.md](docs/hashdepth.md) - Hash collision analysis
- [src/test_trie.erl](src/test_trie.erl) - Usage examples

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Install git hooks: `./scripts/install-hooks.sh`
5. Run tests: `make test`
6. Submit a pull request

## System Requirements

**Minimum:**
- Erlang/OTP 25.3+
- 2 GB RAM
- 1 GB disk space

**Recommended:**
- Erlang/OTP 27.1+
- 4+ GB RAM
- 10+ GB disk space
- Multi-core CPU

## License

See LICENSE file for details.

## Support

- **Issues:** [GitHub Issues](https://github.com/your-repo/MerkleTrie/issues)
- **Documentation:** See `docs/` directory
- **Examples:** See `src/test_trie.erl`

## Acknowledgments

Built with:
- [Erlang/OTP](https://www.erlang.org/)
- [Rebar3](https://rebar3.org/)
- [PropEr](https://proper-testing.github.io/)
- [basho_bench](https://github.com/basho/basho_bench)
