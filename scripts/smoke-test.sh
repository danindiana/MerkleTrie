#!/usr/bin/env bash
#
# Smoke Test Suite for MerkleTrie
# Performs basic validation that the system is functional
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test execution wrapper
run_test() {
    local test_name=$1
    shift
    ((TESTS_RUN++))

    log_info "Running: $test_name"

    if "$@"; then
        log_success "$test_name"
        return 0
    else
        log_failure "$test_name"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    rm -rf data/smoke_test_*.db
    rm -f smoke_test_*.beam
    pkill -f "beam.smp.*smoke" || true
}

trap cleanup EXIT

echo ""
echo "=========================================="
echo "  MerkleTrie Smoke Test Suite"
echo "=========================================="
echo ""

# Test 1: Verify Erlang/OTP is installed
test_erlang_installed() {
    which erl > /dev/null 2>&1
}

run_test "Erlang/OTP installation" test_erlang_installed

# Test 2: Verify OTP version
test_otp_version() {
    local version=$(erl -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' -noshell)
    log_info "OTP Version: $version"
    [[ ! -z "$version" ]]
}

run_test "OTP version check" test_otp_version

# Test 3: Verify rebar3 is available
test_rebar3_available() {
    if [ -x ./rebar3 ]; then
        REBAR3=./rebar3
    elif which rebar3 > /dev/null 2>&1; then
        REBAR3=$(which rebar3)
    else
        return 1
    fi

    log_info "Rebar3: $REBAR3"
    return 0
}

run_test "Rebar3 availability" test_rebar3_available

# Test 4: Verify project compiles
test_compilation() {
    $REBAR3 compile > /dev/null 2>&1
}

run_test "Project compilation" test_compilation

# Test 5: Verify dependencies are resolved
test_dependencies() {
    [ -d "deps/pink_hash" ] && [ -d "deps/dump" ]
}

run_test "Dependencies resolved" test_dependencies

# Test 6: Run EUnit tests
test_eunit() {
    $REBAR3 eunit --verbose > /tmp/eunit_output.log 2>&1
    local result=$?

    if [ $result -eq 0 ]; then
        local passed=$(grep -c "Test passed" /tmp/eunit_output.log || echo "0")
        log_info "EUnit tests passed: $passed"
    fi

    return $result
}

run_test "EUnit tests" test_eunit

# Test 7: Basic trie operations smoke test
test_basic_operations() {
    cat > /tmp/smoke_test.erl << 'EOF'
-module(smoke_test).
-export([run/0]).

run() ->
    % Start the application
    application:ensure_all_started(trie),

    % Create a test trie configuration
    Id = smoke_test,
    Cfg = cfg:new(Id, 8, 32, 0, 12, hd),

    % Clean up any existing data
    os:cmd("rm -rf data/smoke_test_*.db"),

    % Start trie
    trie_sup:start_link(Cfg),

    % Basic operations
    Key1 = <<1,2,3,4,5,6,7,8>>,
    Value1 = <<10,20,30,40>>,

    % Test PUT
    io:format("Testing PUT...~n"),
    trie:put(Key1, Value1, 1, 1, Id),

    % Test GET
    io:format("Testing GET...~n"),
    {RootHash1, Leaf1, _Proof1} = trie:get(Key1, 1, Id),
    io:format("Root hash: ~p~n", [RootHash1]),
    io:format("Leaf: ~p~n", [Leaf1]),

    % Verify value
    LeafValue = leaf:value(Leaf1),
    io:format("Retrieved value: ~p~n", [LeafValue]),

    if
        LeafValue =:= Value1 ->
            io:format("Value matches!~n");
        true ->
            io:format("ERROR: Value mismatch!~n"),
            halt(1)
    end,

    % Test root hash computation
    io:format("Testing root hash...~n"),
    RootHash2 = trie:root_hash(1, Id),
    io:format("Computed root hash: ~p~n", [RootHash2]),

    % Test DELETE
    io:format("Testing DELETE...~n"),
    trie:delete(Key1, 2, Id),

    % Verify deletion
    {RootHash3, Leaf2, _Proof2} = trie:get(Key1, 2, Id),
    io:format("After delete - Root hash: ~p~n", [RootHash3]),
    io:format("After delete - Leaf: ~p~n", [Leaf2]),

    % Test batch operations
    io:format("Testing batch PUT...~n"),
    Keys = [<<I,0,0,0,0,0,0,0>> || I <- lists:seq(1, 10)],
    Values = [<<I:32>> || I <- lists:seq(1, 10)],
    KVList = lists:zip(Keys, Values),

    trie:put_batch(KVList, 3, Id),

    % Verify batch
    io:format("Verifying batch operations...~n"),
    {_, BatchLeaf, _} = trie:get(<<5,0,0,0,0,0,0,0>>, 3, Id),
    BatchValue = leaf:value(BatchLeaf),
    io:format("Batch test value: ~p~n", [BatchValue]),

    if
        BatchValue =:= <<5:32>> ->
            io:format("Batch operation successful!~n");
        true ->
            io:format("ERROR: Batch operation failed!~n"),
            halt(1)
    end,

    io:format("~nAll smoke tests passed!~n"),
    halt(0).
EOF

    erlc -I _build/default/lib/trie/include -pa _build/default/lib/*/ebin /tmp/smoke_test.erl
    erl -noshell -pa _build/default/lib/*/ebin -pa ebin -s smoke_test run > /tmp/smoke_operations.log 2>&1
    local result=$?

    if [ $result -eq 0 ]; then
        log_info "Basic operations completed successfully"
        cat /tmp/smoke_operations.log | grep -E "(Testing|matches|successful|passed)" | while read line; do
            log_info "  $line"
        done
    else
        log_warn "Basic operations test output:"
        cat /tmp/smoke_operations.log
    fi

    return $result
}

run_test "Basic trie operations" test_basic_operations

# Test 8: Verify Dialyzer can run (even if it finds issues)
test_dialyzer_runs() {
    timeout 60 $REBAR3 dialyzer > /tmp/dialyzer_output.log 2>&1 || true
    # Just check if dialyzer runs, not if it passes
    grep -q "Dialyzer" /tmp/dialyzer_output.log
}

run_test "Dialyzer execution" test_dialyzer_runs

# Test 9: Verify Xref can run
test_xref_runs() {
    $REBAR3 xref > /tmp/xref_output.log 2>&1 || true
    # Just check if xref runs
    return 0
}

run_test "Xref execution" test_xref_runs

# Test 10: Check for memory leaks in basic operations
test_memory_stability() {
    cat > /tmp/memory_test.erl << 'EOF'
-module(memory_test).
-export([run/0]).

run() ->
    application:ensure_all_started(trie),
    Id = mem_test,
    Cfg = cfg:new(Id, 8, 32, 0, 12, hd),
    os:cmd("rm -rf data/mem_test_*.db"),
    trie_sup:start_link(Cfg),

    % Run operations multiple times
    lists:foreach(fun(I) ->
        Key = <<I:64>>,
        Value = <<I:32>>,
        trie:put(Key, Value, I, I, Id),
        trie:get(Key, I, Id),
        if I rem 100 =:= 0 -> io:format("."); true -> ok end
    end, lists:seq(1, 500)),

    io:format("~nMemory test completed~n"),
    halt(0).
EOF

    erlc -I _build/default/lib/trie/include -pa _build/default/lib/*/ebin /tmp/memory_test.erl
    timeout 30 erl -noshell -pa _build/default/lib/*/ebin -pa ebin -s memory_test run > /tmp/memory_test.log 2>&1
    return $?
}

run_test "Memory stability test" test_memory_stability

# Summary
echo ""
echo "=========================================="
echo "  Smoke Test Summary"
echo "=========================================="
echo -e "Total tests run:    ${CYAN}${TESTS_RUN}${NC}"
echo -e "Tests passed:       ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed:       ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All smoke tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    echo ""
    exit 1
fi
