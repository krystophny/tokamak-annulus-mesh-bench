#!/usr/bin/env bash
# Run every built backend over every case and print one table.
#
#   scripts/run.sh                 all cases
#   scripts/run.sh tcfp_coarse     one case
#   TRANSLATE=1 scripts/run.sh     shift each case to its hole marker first
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build=${BUILD_DIR:-$root/build}
out=${OUT_DIR:-$root/results}
mkdir -p "$out"

if [ ! -x "$build/annulus_bench" ]; then
    echo "not built yet -- run scripts/build.sh" >&2
    exit 2
fi

cases=("$@")
if [ ${#cases[@]} -eq 0 ]; then
    mapfile -t cases < <(cd "$root/cases" && ls -d */ | tr -d /)
fi

backends=(fortfem)
"$build/annulus_bench" --help 2>/dev/null | grep -q delaunay32 && backends+=(delaunay32)
"$build/annulus_bench" --help 2>/dev/null | grep -q ' triangle' && backends+=(triangle)

flags=()
[ "${TRANSLATE:-0}" = "1" ] && flags+=(--translate)

printf '%-20s %-12s %8s %8s %10s %10s %8s\n' case backend tris ref minangle areaerr result
printf '%s\n' "-------------------------------------------------------------------------------------"
for case in "${cases[@]}"; do
    for backend in "${backends[@]}"; do
        log=$out/${case}_${backend}.log
        "$build/annulus_bench" "$root/cases/$case" "$backend" \
            --out "$out/${case}_${backend}.msh" "${flags[@]}" >"$log" 2>&1
        status=$?
        tris=$(awk '/^  points/ {print $4; exit}' "$log")
        ref='-'
        [ -f "$root/cases/$case/reference/triangle.msh" ] && \
            ref=$(awk 'NR==1 {print $2; exit}' "$root/cases/$case/reference/triangle.msh")
        ang=$(awk '/minimum angle/ {print $3; exit}' "$log")
        err=$(awk '/area rel. error/ {print $4; exit}' "$log")
        verdict=$(awk '/^RESULT/ {print $2; exit}' "$log")
        [ -z "$verdict" ] && verdict="ERROR($status)"
        printf '%-20s %-12s %8s %8s %10s %10s %8s\n' \
            "$case" "$backend" "${tris:--}" "$ref" "${ang:--}" "${err:--}" "$verdict"
    done
done
echo
echo "meshes and logs in $out"
