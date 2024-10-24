#!/bin/bash

#forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage --rc derive_function_end_line=0
set -e

# exclude FastTokenRouter until https://github.com/hyperlane-xyz/hyperlane-monorepo/issues/2806 is resolved
forge coverage \
    --report lcov \
    --report summary \
    --no-match-coverage "(test|mock|node_modules|script|Fast)" \
    
genhtml lcov.info --branch-coverage --output-dir coverage --rc derive_function_end_line=0
open coverage/index.html