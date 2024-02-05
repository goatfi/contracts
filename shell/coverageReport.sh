#!/bin/bash

forge coverage --report lcov
lcov --remove lcov.info  -o lcov.info 'test/*' 'script/*' > /dev/null
genhtml lcov.info --branch-coverage --output-dir coverage > /dev/null
open coverage/index.html