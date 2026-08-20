#!/bin/bash
# Apply the Debian patch series and build Triangle as a shared library.
set -e
cd "$1"
CC=${CC:-gcc}
if [ "$(uname)" == "Darwin" ]; then
    CFLAGS="-I/opt/homebrew/include"
    LDFLAGS="-L/opt/homebrew/lib"
fi
if [ ! -f is_patched ]; then
    while read -r patch; do
        patch -p1 < "debian/patches/$patch"
    done < debian/patches/series
    touch is_patched
fi
if [ ! -f libtriangle.so ]; then
    $CC triangle.c -o triangle.o ${CFLAGS:-} -O2 -DTRILIBRARY -fPIC -DPIC -c
    $CC -shared triangle.o -o libtriangle.so ${LDFLAGS:-} -lm
fi
