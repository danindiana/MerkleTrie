#!/usr/bin/env bash
#
# Install Git Hooks for MerkleTrie
#

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Installing Git hooks...${NC}"

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Pre-commit hook
cat > .git/hooks/pre-commit << 'HOOK_EOF'
#!/usr/bin/env bash
#
# Git pre-commit hook for MerkleTrie
# Ensures code quality before commits
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${CYAN}[PRE-COMMIT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Find rebar3
if [ -x ./rebar3 ]; then
    REBAR3=./rebar3
elif command -v rebar3 &> /dev/null; then
    REBAR3=rebar3
else
    log_error "rebar3 not found!"
    exit 1
fi

# Check if we're in a merge
if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
    log_warn "Merge in progress, skipping pre-commit checks"
    exit 0
fi

# Get list of staged .erl files
STAGED_ERL_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.erl$' || true)

if [ -z "$STAGED_ERL_FILES" ]; then
    log_info "No Erlang files staged, skipping checks"
    exit 0
fi

log_info "Running pre-commit checks..."
echo ""

# Check 1: Compilation
log_info "Checking compilation..."
if $REBAR3 compile > /tmp/precommit_compile.log 2>&1; then
    log_success "Compilation passed"
else
    log_error "Compilation failed!"
    cat /tmp/precommit_compile.log
    exit 1
fi

# Check 2: EUnit tests (quick)
log_info "Running unit tests..."
if timeout 60 $REBAR3 eunit > /tmp/precommit_eunit.log 2>&1; then
    log_success "Unit tests passed"
else
    log_warn "Unit tests failed (allowing commit, but please fix)"
fi

# Check 3: Check for common issues
log_info "Checking for common issues..."

for file in $STAGED_ERL_FILES; do
    # Check for trailing whitespace and auto-fix
    if grep -n '[[:space:]]$' "$file" > /dev/null 2>&1; then
        sed -i 's/[[:space:]]*$//' "$file"
        git add "$file"
        log_info "Auto-fixed trailing whitespace in $file"
    fi
done

log_success "Code quality checks passed"
echo ""

exit 0
HOOK_EOF

chmod +x .git/hooks/pre-commit

echo -e "${GREEN}✓${NC} Pre-commit hook installed"

# Pre-push hook
cat > .git/hooks/pre-push << 'HOOK_EOF'
#!/usr/bin/env bash
#
# Git pre-push hook for MerkleTrie
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${CYAN}[PRE-PUSH]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

if [ "$SKIP_TESTS" = "1" ]; then
    log_info "Skipping pre-push tests (SKIP_TESTS=1)"
    exit 0
fi

log_info "Running pre-push tests..."

if [ -x ./rebar3 ]; then
    REBAR3=./rebar3
elif command -v rebar3 &> /dev/null; then
    REBAR3=rebar3
else
    exit 0
fi

# Run full test suite
if $REBAR3 do compile, eunit, ct > /dev/null 2>&1; then
    log_success "All tests passed"
else
    log_info "Some tests failed, but allowing push"
fi

exit 0
HOOK_EOF

chmod +x .git/hooks/pre-push

echo -e "${GREEN}✓${NC} Pre-push hook installed"

echo ""
echo -e "${GREEN}Git hooks installed successfully!${NC}"
echo ""
echo "Available hooks:"
echo "  - pre-commit: Runs compilation and basic checks"
echo "  - pre-push: Runs full test suite"
echo ""
echo "To skip hooks temporarily:"
echo "  git commit --no-verify"
echo "  SKIP_TESTS=1 git push"
echo ""
