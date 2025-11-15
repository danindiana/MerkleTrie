#!/usr/bin/env bash
#
# Load Test Script for MerkleTrie
# Uses basho_bench for performance testing
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Configuration
BASHO_BENCH_DIR="basho_bench"
BASHO_BENCH_REPO="https://github.com/basho/basho_bench.git"
TEST_CONFIG="scripts/load_test/trie.config.template"
TEST_DURATION=${TEST_DURATION:-5}  # minutes
CONCURRENT_WORKERS=${WORKERS:-4}
OPERATIONS=${OPERATIONS:-10000}

echo ""
echo "=========================================="
echo "  MerkleTrie Load Test"
echo "=========================================="
echo ""

# Check if basho_bench exists
if [ ! -d "$BASHO_BENCH_DIR" ]; then
    log_info "basho_bench not found, cloning repository..."
    git clone "$BASHO_BENCH_REPO" "$BASHO_BENCH_DIR"
    cd "$BASHO_BENCH_DIR"
    make all
    cd ..
    log_success "basho_bench installed"
else
    log_info "basho_bench found"
fi

# Compile the trie project
log_info "Compiling MerkleTrie..."
if [ -x ./rebar3 ]; then
    REBAR3=./rebar3
elif command -v rebar3 &> /dev/null; then
    REBAR3=rebar3
else
    log_error "rebar3 not found!"
    exit 1
fi

$REBAR3 compile

# Create test configuration
log_info "Creating load test configuration..."
mkdir -p tests/current

if [ -f "$TEST_CONFIG" ]; then
    # Use existing template
    cp "$TEST_CONFIG" tests/current/trie.config
else
    # Create default configuration
    cat > tests/current/trie.config << EOF
{mode, max}.
{duration, $TEST_DURATION}.
{concurrent, $CONCURRENT_WORKERS}.
{report_interval, 10}.

{driver, basho_bench_driver_trie}.

{key_generator, {int_to_bin, {uniform_int, 1000000}}}.
{value_generator, {fixed_bin, 1024}}.

{operations, [
    {get, 50},
    {put, 30},
    {delete, 10},
    {root_hash, 10}
]}.

{code_paths, [
    "_build/default/lib/trie/ebin",
    "_build/default/lib/pink_hash/ebin",
    "_build/default/lib/dump/ebin"
]}.
EOF
fi

log_info "Test configuration:"
log_info "  Duration: $TEST_DURATION minutes"
log_info "  Workers: $CONCURRENT_WORKERS"
log_info "  Operations: Mixed (GET 50%, PUT 30%, DELETE 10%, ROOT_HASH 10%)"

# Copy driver if it exists
if [ -f "scripts/load_test/basho_bench_driver_trie.erl" ]; then
    cp scripts/load_test/basho_bench_driver_trie.erl "$BASHO_BENCH_DIR/src/"
    log_info "Custom driver copied"
fi

# Clean previous test data
log_info "Cleaning previous test data..."
rm -rf data/load_test_*.db
rm -rf tests/current/20*  # Remove old test runs

# Run the load test
log_info "Starting load test..."
log_warn "This will take approximately $TEST_DURATION minutes..."
echo ""

cd "$BASHO_BENCH_DIR"

# Build with the driver
make all

# Run the test
./basho_bench ../tests/current/trie.config

cd ..

# Copy results
if [ -d "$BASHO_BENCH_DIR/tests/current" ]; then
    cp -r "$BASHO_BENCH_DIR/tests/current/"* tests/current/
    log_success "Test results copied to tests/current/"
fi

# Generate summary
echo ""
echo "=========================================="
echo "  Load Test Summary"
echo "=========================================="
echo ""

if [ -f "tests/current/summary.csv" ]; then
    log_info "Results summary:"
    cat tests/current/summary.csv | column -t -s,

    # Parse key metrics
    if command -v awk &> /dev/null; then
        echo ""
        log_info "Key Metrics:"

        # Extract throughput
        THROUGHPUT=$(grep "total" tests/current/summary.csv | awk -F, '{print $NF}' | head -n1)
        if [ ! -z "$THROUGHPUT" ]; then
            echo "  Total throughput: $THROUGHPUT ops/sec"
        fi

        # Extract latency stats
        if [ -f "tests/current/summary.csv" ]; then
            grep -E "(put|get|delete|root_hash)" tests/current/summary.csv | while IFS=, read op count mean median p95 p99 p999 max errors; do
                if [ ! -z "$op" ] && [ "$op" != "Operation" ]; then
                    echo "  $op: mean=${mean}μs, p95=${p95}μs, p99=${p99}μs"
                fi
            done
        fi
    fi
else
    log_warn "Summary file not found"
fi

# Check for errors
if [ -f "tests/current/errors.csv" ]; then
    ERROR_COUNT=$(wc -l < tests/current/errors.csv)
    if [ "$ERROR_COUNT" -gt 1 ]; then  # More than just header
        log_warn "Errors occurred during testing:"
        head -n 10 tests/current/errors.csv
    fi
fi

# Generate graphs if R is available
if command -v Rscript &> /dev/null && [ -d "$BASHO_BENCH_DIR" ]; then
    log_info "Generating performance graphs..."
    cd "$BASHO_BENCH_DIR"
    make results || log_warn "Could not generate graphs"
    cd ..
else
    log_warn "R not available, skipping graph generation"
    log_info "Install R to generate performance graphs"
fi

echo ""
log_success "Load test completed!"
echo ""
log_info "View detailed results in: tests/current/"
echo ""

exit 0
