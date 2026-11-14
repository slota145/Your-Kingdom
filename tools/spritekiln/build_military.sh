#!/bin/bash
# G3 part 5b: generate, render and export the military workshops (base and both construction
# stages) with build_port.sh. Run from anywhere: tools/spritekiln/build_military.sh <id>...
GEN=gen_military.py exec "$(cd "$(dirname "$0")" && pwd)/build_port.sh" "$@"
