#!/usr/bin/env bash
# Configure and build. All dependencies are fetched by CMake; nothing is vendored.
#
#   scripts/build.sh                  fortfem + Delaunay32 + plots
#   scripts/build.sh --with-triangle  additionally build the Triangle oracle
#                                     (fetched locally, non-free -- see NOTICE)
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build=${BUILD_DIR:-$root/build}
triangle=OFF

for arg in "$@"; do
    case $arg in
        --with-triangle) triangle=ON ;;
        --no-triangle)   triangle=OFF ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

cmake -S "$root" -B "$build" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBENCH_WITH_TRIANGLE=$triangle
cmake --build "$build" --parallel

echo
echo "binaries in $build:"
echo "  annulus_bench <case-dir> <backend> [--out FILE] [--translate]"
echo "  annulus_check <case-dir> <mesh.msh>"
echo "  annulus_plot  <case-dir> <mesh.msh> <out-prefix>"
