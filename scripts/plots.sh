#!/usr/bin/env bash
# Plot every mesh produced by scripts/run.sh, plus the shipped Triangle
# references. Output lands in plots/, which is gitignored.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build=${BUILD_DIR:-$root/build}
results=${OUT_DIR:-$root/results}
plots=${PLOT_DIR:-$root/plots}
mkdir -p "$plots"

if [ ! -x "$build/annulus_plot" ]; then
    echo "annulus_plot not built (BENCH_WITH_PLOTS=OFF?)" >&2
    exit 2
fi

for case_dir in "$root"/cases/*/; do
    case=$(basename "$case_dir")
    ref=$case_dir/reference/triangle.msh
    [ -f "$ref" ] && "$build/annulus_plot" "$case_dir" "$ref" "$plots/${case}_reference"
    for mesh in "$results/${case}_"*.msh; do
        [ -f "$mesh" ] || continue
        name=$(basename "$mesh" .msh)
        "$build/annulus_plot" "$case_dir" "$mesh" "$plots/$name"
    done
done

echo "plots in $plots"
