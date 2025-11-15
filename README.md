# MerkleTrie

[![CI/CD Pipeline](https://github.com/your-repo/MerkleTrie/workflows/CI/badge.svg)](https://github.com/your-repo/MerkleTrie/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A persistent, append-only **Merkle Trie** implementation in Erlang for efficient versioned state management with cryptographic proof capabilities.

This is a **sparse Merkle trie** database that can prove both the existence and non-existence of data. It implements an **order-16 radix tree** where every node has 16 children (one per hexadecimal nibble). The tree can be configured to use either RAM or hard drive for storage.

## Table of Contents
- [Features](#features)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Data Structures](#data-structures)
- [Operations](#operations)
- [Installation](#installation)
- [Usage](#usage)
- [Testing](#testing)
- [Development](#development)
- [Infrastructure](#infrastructure)
- [Advanced Features](#advanced-features)
- [Performance](#performance)
- [Production Deployment](#production-deployment)

## Features

The goal of this project is to provide:

1. **Merkle tree database on disk** - Persistent storage with cryptographic proofs
2. **Deterministic root hash** - Root hash is deterministically derived from contents; order of insertion/deletion doesn't matter
3. **Historical state queries** - Look up the state at any point in history
4. **Append-only immutable datastructure** - No destructive updates, perfect for consensus-critical applications
5. **Proof system** - Cryptographic proofs for data existence/non-existence
6. **Efficient batch operations** - Optimized bulk insertions and updates

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

### Traditional Method

```bash
# First, ensure Erlang/OTP 25+ is installed
# Download and compile
./rebar3 compile

# Run the software
sh start.sh
```

## Architecture

### System Components

```mermaid
graph TB
    subgraph "Client Interface"
        API[Trie API]
    end

    subgraph "Core Modules"
        TRIE[trie.erl<br/>Gen Server]
        STORE[store.erl<br/>Storage Logic]
        GET[get.erl<br/>Retrieval Logic]
        DELETE[delete.erl<br/>Deletion Logic]
        VERIFY[verify.erl<br/>Proof Verification]
    end

    subgraph "Data Structures"
        STEM[stem.erl<br/>Internal Nodes]
        LEAF[leaf.erl<br/>Leaf Nodes]
    end

    subgraph "Storage Layer"
        DUMP[dump module<br/>Disk I/O]
        DISK[(Hard Drive)]
    end

    subgraph "Management"
        PRUNE[prune.erl<br/>Historical Pruning]
        GARBAGE[garbage.erl<br/>Future GC]
        CFG[cfg.erl<br/>Configuration]
        IDS[ids.erl<br/>ID Management]
    end

    API --> TRIE
    TRIE --> STORE
    TRIE --> GET
    TRIE --> DELETE
    TRIE --> PRUNE
    TRIE --> GARBAGE
    STORE --> STEM
    STORE --> LEAF
    GET --> STEM
    GET --> LEAF
    DELETE --> STEM
    DELETE --> LEAF
    VERIFY --> STEM
    VERIFY --> LEAF
    STEM --> DUMP
    LEAF --> DUMP
    DUMP --> DISK
    TRIE --> CFG
    TRIE --> IDS

    style TRIE fill:#f9f,stroke:#333,stroke-width:4px
    style DISK fill:#aaf,stroke:#333,stroke-width:2px
```

### Module Responsibilities

```mermaid
graph LR
    subgraph "Layer 1: API"
        A1[trie.erl]
    end

    subgraph "Layer 2: Operations"
        B1[store.erl]
        B2[get.erl]
        B3[delete.erl]
        B4[verify.erl]
    end

    subgraph "Layer 3: Data Structures"
        C1[stem.erl]
        C2[leaf.erl]
    end

    subgraph "Layer 4: Persistence"
        D1[dump module]
    end

    subgraph "Layer 5: Maintenance"
        E1[prune.erl]
        E2[garbage.erl]
    end

    A1 --> B1
    A1 --> B2
    A1 --> B3
    A1 --> B4
    B1 --> C1
    B1 --> C2
    B2 --> C1
    B2 --> C2
    B3 --> C1
    B3 --> C2
    B4 --> C1
    B4 --> C2
    C1 --> D1
    C2 --> D1
    A1 --> E1
    A1 --> E2
```

### Core Modules

- **trie.erl** - Main trie gen_server
- **store.erl** - Storage and proof generation
- **stem.erl** - Tree node structure (16-ary branching)
- **leaf.erl** - Leaf node structure
- **verify.erl** - Merkle proof verification
- **prune.erl** - Historical data pruning

## Data Structures

### Merkle Trie Structure

```mermaid
graph TD
    ROOT[Root Stem<br/>Hash: H_root]

    S1[Stem Node<br/>Nibble 0x4<br/>Hash: H1]
    S2[Stem Node<br/>Nibble 0x5<br/>Hash: H2]
    EMPTY1[Empty<br/>Nibble 0x0-0x3]
    EMPTY2[Empty<br/>Nibble 0x6-0xF]

    S1A[Stem Node<br/>Nibble 0x2<br/>Hash: H1A]
    S1B[Empty<br/>Other nibbles]

    S2A[Stem Node<br/>Nibble 0xA<br/>Hash: H2A]
    S2B[Empty<br/>Other nibbles]

    LEAF1[Leaf<br/>Key: 0x42...<br/>Value: Data1<br/>Hash: H_L1]
    LEAF2[Leaf<br/>Key: 0x5A...<br/>Value: Data2<br/>Hash: H_L2]

    ROOT --> EMPTY1
    ROOT --> S1
    ROOT --> S2
    ROOT --> EMPTY2

    S1 --> S1B
    S1 --> S1A
    S2 --> S2A
    S2 --> S2B

    S1A --> LEAF1
    S2A --> LEAF2

    style ROOT fill:#ff9,stroke:#333,stroke-width:4px
    style S1 fill:#9f9,stroke:#333,stroke-width:2px
    style S2 fill:#9f9,stroke:#333,stroke-width:2px
    style S1A fill:#9f9,stroke:#333,stroke-width:2px
    style S2A fill:#9f9,stroke:#333,stroke-width:2px
    style LEAF1 fill:#9ff,stroke:#333,stroke-width:2px
    style LEAF2 fill:#9ff,stroke:#333,stroke-width:2px
    style EMPTY1 fill:#ddd,stroke:#333,stroke-width:1px
    style EMPTY2 fill:#ddd,stroke:#333,stroke-width:1px
    style S1B fill:#ddd,stroke:#333,stroke-width:1px
    style S2B fill:#ddd,stroke:#333,stroke-width:1px
```

MerkleTrie uses a 16-ary tree structure where:
- Each stem node has 16 child pointers (one per hex nibble)
- Paths are determined by key bits
- Leaves contain actual key-value data
- All data is cryptographically hashed

### Stem Node Structure

```mermaid
classDiagram
    class Stem {
        +types[16] : type()
        +pointers[16] : pointer()
        +hashes[16] : hash()
        +new(nibble, type, pointer, hash, cfg) stem()
        +add(stem, nibble, type, pointer, hash) stem()
        +get(stem_pointer, cfg) stem()
        +put(stem, cfg) stem_pointer()
        +hash(stem, cfg) hash()
    }

    class Type {
        <<enumeration>>
        EMPTY : 0
        STEM : 1
        LEAF : 2
    }

    class Pointer {
        +empty_p : 0
        +stem_p : non_neg_integer
        +leaf_p : non_neg_integer
    }

    Stem --> Type : contains 16
    Stem --> Pointer : contains 16

    note for Stem "Each stem has 16 slots (one per nibble)\nEach slot has: type, pointer, hash"
```

### Leaf Node Structure

```mermaid
classDiagram
    class Leaf {
        +key : non_neg_integer()
        +value : binary()
        +meta : non_neg_integer()
        +new(key, value, meta, cfg) leaf()
        +get(leaf_pointer, cfg) leaf()
        +put(leaf, cfg) leaf_pointer()
        +hash(leaf, cfg) hash()
        +path(leaf, cfg) path()
        +serialize(leaf, cfg) binary()
        +deserialize(binary, cfg) leaf()
    }

    note for Leaf "Leaf stores actual key-value data\nmeta is unhashed auxiliary data\nkey determines path through trie"
```

## Operations

### Put Operation Flow

```mermaid
sequenceDiagram
    participant Client
    participant Trie as trie.erl
    participant Store as store.erl
    participant Stem as stem.erl
    participant Leaf as leaf.erl
    participant Dump as dump module
    participant Disk

    Client->>Trie: put(Key, Value, Meta, Root, ID)
    Trie->>Store: store(Leaf, Root, Cfg)

    loop Traverse path
        Store->>Stem: get(StemPointer, Cfg)
        Stem->>Dump: restore stem
        Dump->>Disk: read stem data
        Disk-->>Dump: stem data
        Dump-->>Stem: stem record
        Stem-->>Store: stem()
    end

    Store->>Leaf: new(Key, Value, Meta, Cfg)
    Leaf-->>Store: leaf()

    Store->>Leaf: put(Leaf, Cfg)
    Leaf->>Dump: save leaf
    Dump->>Disk: write leaf
    Disk-->>Dump: ok
    Dump-->>Leaf: LeafPointer
    Leaf-->>Store: LeafPointer

    loop Update path back to root
        Store->>Stem: add(Stem, Nibble, leaf, LeafPointer, LeafHash)
        Stem-->>Store: NewStem
        Store->>Stem: put(NewStem, Cfg)
        Stem->>Dump: save stem
        Dump->>Disk: write stem
        Disk-->>Dump: ok
        Dump-->>Stem: StemPointer
        Stem-->>Store: StemPointer
    end

    Store-->>Trie: NewRootPointer
    Trie-->>Client: NewRoot
```

### Get Operation with Proof Generation

```mermaid
sequenceDiagram
    participant Client
    participant Trie as trie.erl
    participant Get as get.erl
    participant Stem as stem.erl
    participant Leaf as leaf.erl
    participant Disk

    Client->>Trie: get(Key, Root, ID)
    Trie->>Get: get(Key, Root, Cfg)

    loop Traverse path
        Get->>Stem: get(StemPointer, Cfg)
        Stem->>Disk: read stem
        Disk-->>Stem: stem data
        Stem-->>Get: stem()

        Note over Get,Stem: Store sibling hashes for proof
        Get->>Get: collect_proof_hashes(Stem, Path)
    end

    Get->>Leaf: get(LeafPointer, Cfg)
    Leaf->>Disk: read leaf
    Disk-->>Leaf: leaf data
    Leaf-->>Get: leaf()

    Get->>Get: compute_root_hash(Leaf, Proof)
    Get-->>Trie: {RootHash, Leaf, Proof}
    Trie-->>Client: {RootHash, Leaf, Proof}
```

### Proof Verification

```mermaid
sequenceDiagram
    participant Client
    participant Verify as verify.erl

    Client->>Verify: proof(RootHash, Leaf, Proof, Cfg)

    Verify->>Verify: hash(Leaf) = LeafHash

    loop For each proof element
        Verify->>Verify: Combine LeafHash with sibling hash
        Verify->>Verify: hash(combined) = ParentHash
        Note over Verify: Move up one level
    end

    Verify->>Verify: Compare CurrentHash with RootHash

    alt Hashes match
        Verify-->>Client: true
    else Hashes don't match
        Verify-->>Client: false
    end
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

### Historical Queries

```mermaid
graph LR
    R0[Root0<br/>Empty] -->|put K1| R1[Root1<br/>K1:V1]
    R1 -->|put K2| R2[Root2<br/>K1:V1, K2:V2]
    R2 -->|put K3| R3[Root3<br/>K1:V1, K2:V2, K3:V3]
    R3 -->|delete K2| R4[Root4<br/>K1:V1, K3:V3]

    style R0 fill:#ddd
    style R1 fill:#ff9
    style R2 fill:#9f9
    style R3 fill:#9ff
    style R4 fill:#f9f

    NOTE[All historical states<br/>remain accessible]

    R0 -.-> NOTE
    R1 -.-> NOTE
    R2 -.-> NOTE
    R3 -.-> NOTE
```

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
- `test/smoke_tests.erl` - Comprehensive smoke tests (15 scenarios)
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

- **GitHub Actions CI/CD** - Automated testing on multiple OTP versions (25.3, 26.2, 27.1)
- **Docker/Docker Compose** - Containerized development and deployment
- **Makefile** - Standardized build commands (40+ targets)
- **Smoke Tests** - Comprehensive validation suite
- **Load Testing** - basho_bench integration
- **Security Scanning** - Automated vulnerability detection (Trivy)

For complete infrastructure documentation, see [INFRASTRUCTURE.md](INFRASTRUCTURE.md).

For technology stack and library references (as of 2025-11-15), see [BIBLIOGRAPHY.md](BIBLIOGRAPHY.md).

## Advanced Features

### Garbage Collection and Pruning

```mermaid
graph TB
    subgraph "Timeline"
        OLD[Old Root] -->|changes| CURRENT[Current Root]
        CURRENT -->|changes| NEW[New Root]
    end

    subgraph "Pruning Old Data"
        PRUNE[prune.erl]
        PRUNE -->|removes| OLD_DATA[Historical Data]
    end

    subgraph "Garbage Collecting Future Data"
        GARBAGE[garbage.erl]
        GARBAGE -->|removes| NEW_DATA[Future Batches]
    end

    OLD -.->|prune old history| PRUNE
    NEW -.->|undo recent batches| GARBAGE

    style OLD fill:#ddd
    style CURRENT fill:#9f9
    style NEW fill:#ff9
```

- **Prune (`prune.erl`)** - Remove old historical data to save space
- **Garbage Collection (`garbage.erl`)** - Undo recent batches (rollback functionality)
- Both operations maintain trie integrity and deterministic hashing

### Configuration Options

```erlang
% cfg:new(ID, KeyLength, ValueSize, MetaSize, HashSize, Mode)
Cfg = cfg:new(my_trie, 8, 32, 0, 12, hd).
```

- **KeyLength** - Path depth in bytes (determines maximum keys)
- **ValueSize** - Leaf value size in bytes
- **MetaSize** - Unhashed metadata size
- **HashSize** - Hash function output size (12-32 bytes)
- **Mode** - Storage mode: `hd` (hard drive) or `ram` (in-memory)

## Performance

Typical performance on modern hardware:
- **PUT operations:** ~10,000-50,000 ops/sec
- **GET operations:** ~20,000-100,000 ops/sec
- **Root hash computation:** ~1,000-5,000 ops/sec
- **Batch operations:** ~500-2,000 batches/sec (100 items each)

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
- [BIBLIOGRAPHY.md](BIBLIOGRAPHY.md) - Technology stack (2025-11-15)
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
