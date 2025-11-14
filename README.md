# Merkle Trie

A persistent, append-only Merkle Trie implementation in Erlang for efficient versioned state management with cryptographic proof capabilities.

This is a **sparse Merkle trie** database that can prove both the existence and non-existence of data. It implements an **order-16 radix tree** where every node has 16 children (one per hexadecimal nibble). The tree can be configured to use either RAM or hard drive for storage.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Data Structures](#data-structures)
- [Operations](#operations)
- [Installation](#installation)
- [Usage](#usage)
- [Advanced Features](#advanced-features)

## Overview

The MerkleTrie project provides:

1. **Persistent storage** - Merkle tree database stored on hard drive
2. **Deterministic hashing** - Root hash is deterministically derived from contents (insertion/deletion order doesn't matter)
3. **Historical lookups** - Query state at any point in history
4. **Immutability** - Append-only immutable data structure
5. **Proof system** - Cryptographic proofs for data existence/non-existence
6. **Efficient batch operations** - Optimized bulk insertions and updates

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
    Trie->>Leaf: new(Key, Value, Meta, CFG)
    Leaf-->>Trie: Leaf
    Trie->>Store: store(Leaf, Root, CFG)

    Store->>Store: get_branch(Path, Root)
    Store->>Stem: get(RootPointer, CFG)
    Stem->>Dump: get(Pointer, ID)
    Dump->>Disk: read
    Disk-->>Dump: binary data
    Dump-->>Stem: stem data
    Stem-->>Store: Stem

    Store->>Leaf: put(Leaf, CFG)
    Leaf->>Dump: put(serialized_leaf, ID)
    Dump->>Disk: write
    Disk-->>Dump: location
    Dump-->>Leaf: LeafPointer
    Leaf-->>Store: LeafPointer

    Store->>Store: update branch with new leaf
    Store->>Stem: put(UpdatedStem, CFG)
    Stem->>Dump: put(serialized_stem, ID)
    Dump->>Disk: write
    Disk-->>Dump: location
    Dump-->>Stem: StemPointer
    Stem-->>Store: StemPointer

    Store->>Stem: hash(UpdatedStem, CFG)
    Stem-->>Store: RootHash
    Store-->>Trie: {RootHash, NewRoot, Proof}
    Trie-->>Client: NewRoot
```

### Get Operation Flow

```mermaid
sequenceDiagram
    participant Client
    participant Trie as trie.erl
    participant Get as get.erl
    participant Stem as stem.erl
    participant Leaf as leaf.erl
    participant Disk

    Client->>Trie: get(Key, Root, ID)
    Trie->>Leaf: path_maker(Key, CFG)
    Leaf-->>Trie: Path [nibbles]
    Trie->>Get: get(Path, RootPointer, CFG)

    loop For each nibble in path
        Get->>Stem: get(Pointer, CFG)
        Stem->>Disk: read stem
        Disk-->>Stem: stem data
        Stem-->>Get: Stem
        Get->>Get: Follow nibble to next pointer
        Get->>Get: Accumulate proof
    end

    Get->>Leaf: get(LeafPointer, CFG)
    Leaf->>Disk: read leaf
    Disk-->>Leaf: leaf data
    Leaf-->>Get: Leaf

    Get->>Get: Verify key matches
    Get->>Stem: hash(RootStem, CFG)
    Stem-->>Get: RootHash

    Get-->>Trie: {RootHash, Leaf, Proof}
    Trie-->>Client: {RootHash, Leaf, Proof}
```

### Delete Operation Flow

```mermaid
flowchart TD
    START[Delete Request] --> GET_BRANCH[Get branch to key]
    GET_BRANCH --> CHECK_EXISTS{Key exists?}
    CHECK_EXISTS -->|No| RETURN_ROOT[Return unchanged root]
    CHECK_EXISTS -->|Yes| REMOVE_LEAF[Remove leaf from stem]
    REMOVE_LEAF --> UPDATE_STEM[Update stem node]
    UPDATE_STEM --> CHECK_EMPTY{Stem has other children?}
    CHECK_EMPTY -->|Yes| STORE_STEM[Store updated stem]
    CHECK_EMPTY -->|No| COLLAPSE[Collapse empty stem]
    COLLAPSE --> STORE_STEM
    STORE_STEM --> PROPAGATE[Propagate changes up tree]
    PROPAGATE --> COMPUTE_HASH[Compute new root hash]
    COMPUTE_HASH --> RETURN_NEW[Return new root pointer]
    RETURN_ROOT --> END[End]
    RETURN_NEW --> END

    style START fill:#ff9,stroke:#333,stroke-width:2px
    style END fill:#9f9,stroke:#333,stroke-width:2px
    style CHECK_EXISTS fill:#f9f,stroke:#333,stroke-width:2px
    style CHECK_EMPTY fill:#f9f,stroke:#333,stroke-width:2px
```

### Batch Operation Flow

```mermaid
flowchart TD
    START[Batch Insert Request] --> SORT[Sort leaves by path]
    SORT --> INIT[Initialize branch data]

    INIT --> LOOP_START{More leaves?}
    LOOP_START -->|Yes| GET_NEXT[Get next leaf]
    GET_NEXT --> GET_BRANCH[Get branch for leaf path]
    GET_BRANCH --> COMPARE{Adjacent paths share prefix?}
    COMPARE -->|Yes| MERGE[Merge branches]
    COMPARE -->|No| NEW_BRANCH[Create new branch]
    MERGE --> STORE_LEAF[Store leaf]
    NEW_BRANCH --> STORE_LEAF
    STORE_LEAF --> LOOP_START

    LOOP_START -->|No| PROCESS[Process all branches bottom-up]
    PROCESS --> UPDATE_LEVEL{More levels?}
    UPDATE_LEVEL -->|Yes| UPDATE_STEMS[Update stems at this level]
    UPDATE_STEMS --> COMPUTE_HASHES[Compute hashes]
    COMPUTE_HASHES --> STORE_STEMS[Store updated stems]
    STORE_STEMS --> UPDATE_LEVEL

    UPDATE_LEVEL -->|No| FINAL_ROOT[Compute final root hash]
    FINAL_ROOT --> END[Return new root]

    style START fill:#ff9,stroke:#333,stroke-width:2px
    style END fill:#9f9,stroke:#333,stroke-width:2px
    style MERGE fill:#9ff,stroke:#333,stroke-width:2px
```

### Proof Verification Flow

```mermaid
sequenceDiagram
    participant Client
    participant Verify as verify.erl
    participant Leaf as leaf.erl
    participant Stem as stem.erl

    Client->>Verify: proof(RootHash, Leaf, Proof, CFG)

    Verify->>Leaf: hash(Leaf, CFG)
    Leaf-->>Verify: LeafHash
    Verify->>Verify: CurrentHash = LeafHash

    loop For each proof element (bottom to top)
        Verify->>Verify: Extract hashes tuple
        Verify->>Verify: Insert CurrentHash at path position
        Verify->>Stem: compute hash from tuple
        Stem-->>Verify: NewHash
        Verify->>Verify: CurrentHash = NewHash
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

First you need Erlang installed.

### Running

To start the software:

```bash
sh start.sh
```

## Usage

For detailed usage examples, see [test_trie.erl](src/test_trie.erl).

### Basic Operations

```erlang
% Start the trie
ID = trie01,
CFG = trie:cfg(ID),

% Initialize root
Root0 = 1,

% Put a value
Key = 5,
Value = <<2,3>>,
Meta = 0,
Root1 = trie:put(Key, Value, Meta, Root0, ID),

% Get a value
{RootHash, Leaf, Proof} = trie:get(Key, Root1, ID),
Value = leaf:value(Leaf),

% Verify proof
true = verify:proof(RootHash, Leaf, Proof, CFG),

% Delete a value
Root2 = trie:delete(Key, Root1, ID),

% Batch insert
Leaves = [leaf:new(1, <<1,1>>, 0, CFG),
          leaf:new(2, <<2,2>>, 0, CFG),
          leaf:new(3, <<3,3>>, 0, CFG)],
Root3 = trie:put_batch(Leaves, Root0, ID),

% Get all leaves
AllLeaves = trie:get_all(Root3, ID).
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
        PRUNE_DESC[Removes historical states<br/>that are no longer needed<br/>prune Old, New]
    end

    subgraph "Garbage Collection"
        GC[garbage.erl]
        GC_DESC[Removes future states<br/>that were not accepted<br/>garbage New, Old]
    end

    OLD -.->|prune removes| PRUNE
    NEW -.->|garbage removes| GC

    style OLD fill:#faa,stroke:#333
    style CURRENT fill:#9f9,stroke:#333
    style NEW fill:#aaf,stroke:#333
    style PRUNE fill:#faa,stroke:#333
    style GC fill:#aaf,stroke:#333
```

### State Restoration

When you garbage collect leaves from the trie, you can later restore them using proofs:

```mermaid
sequenceDiagram
    participant Client
    participant Trie
    participant Store

    Note over Client,Store: Initial state with full trie
    Client->>Trie: get(Key, FullRoot, ID)
    Trie-->>Client: {Hash, Leaf, Proof}

    Note over Client,Store: Garbage collect leaves
    Client->>Trie: garbage_leaves([{Path, Root}], CFG)

    Note over Client,Store: Create empty trie with same root hash
    Client->>Trie: new_trie(ID, EmptyRootStem)
    Trie-->>Client: EmptyRoot

    Note over Client,Store: Try to get - returns unknown
    Client->>Trie: get(Key, EmptyRoot, ID)
    Trie-->>Client: {Hash, unknown, _}

    Note over Client,Store: Restore using saved proof
    Client->>Trie: restore(Leaf, Hash, Proof, EmptyRoot, ID)
    Trie->>Store: restore(Leaf, Hash, Proof, EmptyRoot, CFG)
    Store->>Store: Verify proof
    Store->>Store: Reconstruct branch
    Store->>Store: Store leaf and stems
    Store-->>Trie: NewRoot
    Trie-->>Client: NewRoot

    Note over Client,Store: Now can get again
    Client->>Trie: get(Key, NewRoot, ID)
    Trie-->>Client: {Hash, Leaf, _}
```

### Sparse Merkle Trie - Proof of Non-Existence

```mermaid
graph TD
    ROOT[Root Stem]

    subgraph "Existing Data Path"
        S1[Stem 0x4]
        L1[Leaf: Key=0x42, Value=Data]
    end

    subgraph "Non-Existent Data Path"
        S2[Stem 0x5]
        EMPTY[Empty Slot 0xA<br/>Hash: 0x000...000]
    end

    ROOT -->|nibble 0x4| S1
    ROOT -->|nibble 0x5| S2
    S1 -->|nibble 0x2| L1
    S2 -->|nibble 0xA| EMPTY

    PROOF[Proof of Non-Existence<br/>Shows path to empty slot<br/>with deterministic empty hash]

    EMPTY -.-> PROOF

    style ROOT fill:#ff9,stroke:#333,stroke-width:4px
    style S1 fill:#9f9,stroke:#333,stroke-width:2px
    style S2 fill:#9f9,stroke:#333,stroke-width:2px
    style L1 fill:#9ff,stroke:#333,stroke-width:2px
    style EMPTY fill:#fcc,stroke:#333,stroke-width:2px,stroke-dasharray: 5 5
    style PROOF fill:#fcf,stroke:#333,stroke-width:2px
```

### Proof System Benefits

```mermaid
graph TD
    A[Merkle Trie Proofs] --> B[Compact]
    A --> C[Verifiable]
    A --> D[Efficient]

    B --> B1[Log size: O log n]
    B --> B2[Only path from root to leaf]

    C --> C1[Cryptographically secure]
    C --> C2[Can verify without full trie]
    C --> C3[Tamper-evident]

    D --> D1[Fast verification]
    D --> D2[Minimal data transfer]
    D --> D3[Enables light clients]

    style A fill:#ff9,stroke:#333,stroke-width:4px
    style B fill:#9f9,stroke:#333
    style C fill:#9ff,stroke:#333
    style D fill:#f9f,stroke:#333
```

## Real-World Usage

This MerkleTrie is used in production by:
- [Amoveo](https://github.com/zack-bitcoin/amoveo) - A blockchain project

## Key Properties

1. **Deterministic**: Same data always produces same root hash regardless of insertion order
2. **Persistent**: All historical states remain accessible
3. **Provable**: Can generate and verify cryptographic proofs
4. **Efficient**: Logarithmic complexity for operations
5. **Append-only**: Immutable structure enables safe concurrent reads

## Technical Details

### Radix Tree Structure
- **Order-16 radix tree**: Each stem node has exactly 16 children (one per nibble value 0x0 through 0xF)
- **Nibble-based navigation**: Keys are decomposed into 4-bit nibbles for tree traversal
- **Configurable storage**: Can use RAM or hard drive storage backends

### Sparse Merkle Trie
This implementation is a **sparse Merkle trie**, which means:
- **Proof of non-existence**: Can cryptographically prove that data does NOT exist in the trie
- **Empty nodes optimized**: Empty branches are represented efficiently without storing actual nodes
- **Complete key space**: Conceptually covers the entire key space, even for keys never inserted
- **Deterministic empty hash**: Empty positions have a consistent, predetermined hash value

### Path Encoding
- Keys are converted to paths of nibbles (4-bit values)
- Each nibble determines which of 16 children to follow in a stem node
- Path length determined by configuration (typically 5-10 nibbles for 20-40 bit keys)

### Hash Computation
- **Leaf hash**: `hash(key || value)`
- **Stem hash**: `hash(concatenation of 16 child hashes)`
- **Empty hash**: Predefined zero value for empty positions
- **Root hash**: Uniquely identifies entire trie state

### Storage Format
- Stems and leaves stored separately on disk
- Pointers reference disk locations (append-only structure)
- Configurable sizes for keys, values, hashes, and metadata
- Each stem stores: 16 types, 16 pointers, 16 hashes
