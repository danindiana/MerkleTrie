# MerkleTrie Infrastructure Documentation

**Last Updated:** 2025-11-15

This document describes the build, validation, CI/CD pipeline, and deployment infrastructure for MerkleTrie.

---

## Table of Contents

1. [Overview](#overview)
2. [Build System](#build-system)
3. [CI/CD Pipeline](#cicd-pipeline)
4. [Docker Infrastructure](#docker-infrastructure)
5. [Testing Framework](#testing-framework)
6. [Bare Metal Deployment](#bare-metal-deployment)
7. [Development Workflow](#development-workflow)
8. [Troubleshooting](#troubleshooting)

---

## Overview

MerkleTrie uses a modern, comprehensive infrastructure stack:

- **Build Tool:** Rebar3 (latest: 3.23.0)
- **CI/CD:** GitHub Actions
- **Containerization:** Docker & Docker Compose
- **Build Automation:** GNU Make
- **Testing:** EUnit, PropEr, Custom Smoke Tests
- **Static Analysis:** Dialyzer, Xref
- **Code Quality:** Pre-commit hooks

### Key Features

✅ Multi-OTP version support (25.3, 26.2, 27.1)
✅ Automated testing (unit, property-based, smoke, load)
✅ Container-based development
✅ Bare metal deployment scripts
✅ Comprehensive smoke tests
✅ Security scanning
✅ Performance benchmarking

---

## Build System

### Makefile Targets

The project uses a comprehensive Makefile for all build operations.

#### Quick Reference

```bash
make help              # Display all available targets
make                   # Default: build and test everything
make bare-metal        # Complete bare metal setup
```

#### Build Targets

| Target | Description |
|--------|-------------|
| `compile` | Compile the project |
| `clean` | Remove build artifacts |
| `deps` | Fetch dependencies |
| `upgrade-deps` | Upgrade dependencies |

#### Testing Targets

| Target | Description |
|--------|-------------|
| `test` | Run all tests (EUnit + PropEr + CT) |
| `eunit` | Run EUnit tests |
| `proper` | Run property-based tests |
| `ct` | Run Common Test |
| `coverage` | Generate coverage report |
| `smoke-test` | Run smoke tests |
| `load-test` | Run performance tests |

#### Quality Targets

| Target | Description |
|--------|-------------|
| `dialyzer` | Static type analysis |
| `xref` | Cross-reference analysis |
| `check` | Run all static analysis |
| `format` | Format code |

#### Docker Targets

| Target | Description |
|--------|-------------|
| `docker-build` | Build Docker image |
| `docker-dev` | Start dev container |
| `docker-test` | Run tests in container |
| `docker-bench` | Run benchmarks in container |

#### Development Targets

| Target | Description |
|--------|-------------|
| `shell` | Start Erlang REPL |
| `release` | Build production release |
| `deploy` | Prepare deployment package |

### Rebar3 Configuration

The project uses `rebar.config` for dependency and build configuration:

```erlang
{deps, [
    {pink_hash, "1", {git, "https://github.com/BumblebeeBat/pink_crypto", {tag, "master"}}},
    {dump, "1", {git, "https://github.com/BumblebeeBat/dump", {tag, "master"}}}
]}.

{profiles, [
    {test, [{deps, [{proper, "1.2.0"}]}]}
]}.
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

#### Main CI Pipeline (`.github/workflows/ci.yml`)

Triggered on:
- Push to `main`, `master`, or `claude/**` branches
- Pull requests to `main` or `master`
- Manual workflow dispatch

**Jobs:**

1. **Test Matrix** (OTP 25.3, 26.2, 27.1)
   - Compilation
   - EUnit tests
   - Common Test
   - Property-based tests (PropEr)
   - Coverage reporting to Codecov

2. **Dialyzer** (OTP 27.1)
   - Static type analysis
   - PLT file caching

3. **Xref**
   - Cross-reference analysis
   - Undefined function detection

4. **Format Check**
   - Code formatting validation

5. **Smoke Tests**
   - Basic functionality validation
   - Integration testing

6. **Load Tests** (main/master only)
   - Performance benchmarking
   - basho_bench integration
   - Result artifact archival

7. **Release Build** (main/master only)
   - Production release compilation
   - Artifact creation

8. **Security Scanning**
   - Trivy vulnerability scanning
   - SARIF report upload

#### Docker Workflow (`.github/workflows/docker.yml`)

Triggered on:
- Push to `main`/`master`
- Tags matching `v*`
- Pull requests

**Features:**
- Multi-architecture builds (amd64, arm64)
- Image caching
- GitHub Container Registry integration
- Security scanning

### Caching Strategy

The CI pipeline uses aggressive caching to minimize build times:

- **Dependencies:** `_build`, `deps`, `~/.cache/rebar3`
- **PLT files:** Dialyzer type analysis cache
- **Docker layers:** BuildKit cache

---

## Docker Infrastructure

### Dockerfiles

#### Production Dockerfile

**File:** `Dockerfile`

Multi-stage build:
1. **Builder stage:** Erlang 27.1 Alpine, compile application
2. **Runtime stage:** Minimal Erlang runtime, application only

**Features:**
- Non-root user execution
- Health checks
- Volume for persistent data
- Minimal attack surface

**Usage:**

```bash
docker build -t merkletrie:latest .
docker run -d -p 8080:8080 -v merkletrie-data:/opt/trie/data merkletrie:latest
```

#### Development Dockerfile

**File:** `Dockerfile.dev`

Full development environment with:
- All build tools
- rebar3
- vim, curl, htop
- Colored output support

**Usage:**

```bash
docker build -f Dockerfile.dev -t merkletrie:dev .
docker run -it -v $(pwd):/workspace merkletrie:dev
```

### Docker Compose

**File:** `docker-compose.yml`

**Services:**

1. **trie** (production)
   - Production image
   - Port 8080 exposed
   - Persistent volumes
   - Health checks
   - Automatic restart

2. **trie-dev** (development profile)
   - Hot-reload development
   - Source code mounted
   - Interactive shell

3. **trie-test** (test profile)
   - Automated test runner
   - Full test suite

4. **trie-bench** (bench profile)
   - Performance benchmarking
   - Result persistence

**Usage:**

```bash
# Production
docker-compose up -d

# Development
docker-compose --profile dev up -d trie-dev
docker-compose exec trie-dev /bin/bash

# Testing
docker-compose --profile test run --rm trie-test

# Benchmarking
docker-compose --profile bench run --rm trie-bench
```

---

## Testing Framework

### Test Organization

```
test/
├── trie_tests.erl                  # EUnit integration tests
├── smoke_tests.erl                 # Comprehensive smoke tests (NEW)
├── prop_trie_arbitrary_put_and_delete.erl
├── prop_trie_root_hash_independent_from_order_of_operations.erl
├── prop_trie_history_readable_at_any_height.erl
└── trie_test_utils.erl
```

### Smoke Tests

**File:** `test/smoke_tests.erl`

Comprehensive test suite covering:
- Basic operations (PUT, GET, DELETE)
- Root hash computation
- Batch operations
- Historical reads
- Proof verification
- Empty trie handling
- Large key operations
- Sequential operations
- Concurrent operations
- Persistence
- Garbage collection
- Pruning
- Stress testing

**Run:**

```bash
make smoke-test
# or
./scripts/smoke-test.sh
```

### Property-Based Tests

Using PropEr framework to verify:
- Arbitrary PUT/DELETE operations
- Root hash order independence
- History read consistency

**Run:**

```bash
make proper
```

### Load Testing

**Tool:** basho_bench

**Configuration:** `scripts/load_test/trie.config.template`

**Operations tested:**
- GET (50%)
- PUT (30%)
- DELETE (10%)
- ROOT_HASH (10%)

**Run:**

```bash
make load-test
# or
./scripts/load-test.sh
```

**Results:** `tests/current/`

---

## Bare Metal Deployment

### Automated Setup

**Script:** `scripts/bare-metal-setup.sh`

Performs complete environment setup:

1. OS detection (Ubuntu, Debian, Fedora, Arch, macOS)
2. Erlang/OTP installation (version 25+)
3. Rebar3 installation
4. Directory structure creation
5. Dependency fetching
6. Compilation
7. Test execution
8. Smoke test validation
9. Optional systemd service setup

**Usage:**

```bash
chmod +x scripts/bare-metal-setup.sh
./scripts/bare-metal-setup.sh
```

Or via Make:

```bash
make bare-metal
```

### System Requirements

**Minimum:**
- Erlang/OTP 25.3+
- 2 GB RAM
- 1 GB disk space
- Linux, macOS, or BSD

**Recommended:**
- Erlang/OTP 27.1+
- 4+ GB RAM
- 10+ GB disk space
- Multi-core CPU

### Supported Platforms

✅ Ubuntu 20.04+
✅ Debian 11+
✅ Fedora 36+
✅ RHEL/CentOS 8+
✅ Arch Linux
✅ macOS 12+

### Manual Deployment

1. **Install Erlang/OTP:**

   ```bash
   # Ubuntu/Debian
   sudo apt-get install erlang

   # Fedora
   sudo dnf install erlang

   # macOS
   brew install erlang
   ```

2. **Install Rebar3:**

   ```bash
   wget https://s3.amazonaws.com/rebar3/rebar3
   chmod +x rebar3
   sudo mv rebar3 /usr/local/bin/
   ```

3. **Build:**

   ```bash
   make deps compile test
   ```

4. **Run:**

   ```bash
   make shell
   ```

### Production Deployment

1. **Build release:**

   ```bash
   make release
   ```

2. **Deploy:**

   ```bash
   # Copy to production server
   scp -r _build/prod/rel/trie/ user@server:/opt/trie/

   # On server
   cd /opt/trie
   ./bin/trie start
   ./bin/trie ping  # Check status
   ```

3. **Systemd service:**

   ```bash
   # Create service file
   sudo systemctl enable merkletrie
   sudo systemctl start merkletrie
   sudo systemctl status merkletrie
   ```

---

## Development Workflow

### Quick Start

```bash
# Clone repository
git clone <repo-url>
cd MerkleTrie

# Setup (choose one)
make bare-metal              # Bare metal
docker-compose --profile dev up -d  # Docker

# Install git hooks
./scripts/install-hooks.sh

# Development
make shell                   # Interactive REPL
make test                    # Run tests
make check                   # Static analysis
```

### Pre-commit Hooks

**Installation:**

```bash
./scripts/install-hooks.sh
```

**What it checks:**
- Compilation
- Unit tests
- Code quality issues
- Trailing whitespace (auto-fix)
- Tabs vs spaces

**Skip temporarily:**

```bash
git commit --no-verify
```

### Code Quality

```bash
# Run all checks
make check

# Individual checks
make dialyzer
make xref
make format
```

### Testing Workflow

```bash
# Quick test
make eunit

# Full test suite
make test

# With coverage
make coverage

# Smoke test
make smoke-test

# Load test
make load-test
```

### Release Process

1. Update version
2. Run full test suite: `make ci`
3. Build release: `make release`
4. Test release locally
5. Tag: `git tag v1.0.0`
6. Push: `git push origin v1.0.0`
7. CI builds and publishes artifacts

---

## Troubleshooting

### Common Issues

#### Build Failures

**Issue:** `rebar3: command not found`

**Solution:**

```bash
make install  # Downloads rebar3
# or
wget https://s3.amazonaws.com/rebar3/rebar3
chmod +x rebar3
```

#### Test Failures

**Issue:** Tests timeout

**Solution:**

```bash
# Increase timeout
export ERL_AFLAGS="-kernel net_ticktime 120"
make test
```

#### Docker Issues

**Issue:** Permission denied

**Solution:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

#### Dialyzer Issues

**Issue:** PLT build takes forever

**Solution:**

```bash
# Use cached PLT
rebar3 dialyzer  # First run is slow
# Subsequent runs are fast with cache
```

### Performance Tuning

**Increase VM heap size:**

```bash
export ERL_FLAGS="+hmax 1024000000"
make shell
```

**Enable SMP:**

```bash
erl +S 4:4  # 4 schedulers, 4 online
```

### Debug Mode

**Enable verbose output:**

```bash
make VERBOSE=1 compile
rebar3 eunit --verbose
```

**Debug shell:**

```erlang
% In Erlang shell
dbg:tracer().
dbg:p(all, c).
dbg:tpl(trie, []).
```

---

## Performance Benchmarks

### Typical Performance (on modern hardware)

- **PUT operations:** ~10,000-50,000 ops/sec
- **GET operations:** ~20,000-100,000 ops/sec
- **Root hash:** ~1,000-5,000 computations/sec
- **Batch PUT (100 items):** ~500-2,000 batches/sec

### Benchmarking

```bash
# Run full benchmark suite
make benchmark

# Custom benchmark
TEST_DURATION=10 WORKERS=8 make load-test

# Results in: tests/current/
```

---

## Security

### Vulnerability Scanning

**Automated:** GitHub Actions (Trivy)

**Manual:**

```bash
# Docker image scan
docker scan merkletrie:latest

# Dependency audit
rebar3 audit  # (if plugin available)
```

### Security Best Practices

1. ✅ Non-root container execution
2. ✅ Minimal base images (Alpine)
3. ✅ Automated security scanning
4. ✅ Dependency pinning
5. ✅ SARIF reports to GitHub Security

---

## Maintenance

### Updating Dependencies

```bash
make upgrade-deps
make test  # Verify everything works
git commit -am "chore: update dependencies"
```

### Cleaning

```bash
make clean       # Build artifacts
make distclean   # Everything (including rebar3)
```

### Logs

**Locations:**
- Application logs: `logs/`
- Test results: `_build/test/logs/`
- Benchmark results: `tests/current/`

---

## Additional Resources

- [Erlang/OTP Documentation](https://www.erlang.org/docs)
- [Rebar3 Documentation](https://rebar3.org/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)
- [basho_bench Documentation](https://github.com/basho/basho_bench)

---

## Support

For issues and questions:
- GitHub Issues: [Project Issues](https://github.com/your-repo/issues)
- Documentation: `docs/`
- Smoke Tests: `./scripts/smoke-test.sh`

---

**Infrastructure Version:** 2.0
**Maintained by:** Infrastructure Team
**Last Audit:** 2025-11-15
