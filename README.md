# tokamak-annulus-mesh-bench

A standalone benchmark for the one meshing problem
[MEPHIT](https://github.com/itpplasma/MEPHIT) hands to an external
triangulator: the **vacuum annulus** between the outermost meshed flux surface
and a scaled bounding ellipse. Real boundaries from real runs, no MEPHIT build
required.

MEPHIT currently solves this with Shewchuk's Triangle, whose licence is
incompatible with MEPHIT's MIT terms
([itpplasma/MEPHIT#25](https://github.com/itpplasma/MEPHIT/issues/25)). This
repository exists so that a candidate replacement can be judged on the actual
inputs instead of a hand-made circle.

## The problem

Two closed polygonal loops and one hole marker:

- **inner loop** — the outermost meshed flux surface, vertex for vertex
- **outer loop** — an axis-aligned ellipse at twice the plasma's half-extents,
  with `1/8` as many points
- **hole marker** — the centre of the inner loop

The mesher must produce a constrained Delaunay mesh of the annulus with a
20° minimum angle, and it must **not** split any boundary segment — MEPHIT
merges this mesh with the core mesh in FreeFem++, and that merge fails if the
shared border changes.

The `1/8` point ratio against the `2×` scale fixes the boundary edge-length
jump at **16:1** in every case. That jump, not the geometry, is what makes the
problem hard.

## Cases

| case | inner pts | outer pts | inner edge | outer edge | origin offset |
|---|---|---|---|---|---|
| `tcfp_coarse` | 126 | 16 | 3.34 cm | 52.3 cm | 1.7e5 cm |
| `tcfp_medium` | 366 | 46 | 1.15 cm | 18.3 cm | 1.7e5 cm |
| `tcfp_production` | 814 | 102 | 0.52 cm | 8.25 cm | 1.7e5 cm |
| `synthetic_circle` | 128 | 16 | 2.45 cm | 39.0 cm | 1.7e2 cm |

The three `tcfp_*` cases are dumped from MEPHIT runs of the shipped
`g000001.0001_TCFP_hip` equilibrium (`data/mephit_g000001.0001_TCFP_hip.in`),
varying only `config%max_Delta_rad` — 3.0, 1.0 and 0.45 cm. `tcfp_production`
is the setting the case actually ships with; `tcfp_medium` matches the
resolution the AUG shot 33353 namelist produces.

**Watch the offset.** This is the KiLCA cylindrical-limit case
(`kilca_scale_factor = 1000`), so the geometry sits at `R ≈ 1.7e5 cm` with
0.5 cm edges — a `3e5` dynamic range between coordinate magnitude and feature
size. That is a real, shipped MEPHIT configuration and a genuine robustness
test for exact predicates and for any mesher quantising coordinates.
`synthetic_circle` is the same problem without the offset, so the two can be
compared to isolate its effect. `--translate` re-centres a case on its hole
marker before meshing and shifts the result back, which measures the same
thing from the other side.

`synthetic_circle` is the fixture used in the original Delaunay32 experiment
([MEPHIT#40](https://github.com/itpplasma/MEPHIT/pull/40)); note that it lands
close to `tcfp_coarse`, i.e. it corresponds to a deliberately coarse run, not
to production settings.

Not covered: shaped, diverted equilibria. ASDEX Upgrade cases need equilibrium
and profile files that are not publicly redistributable, and their inner loop
has an X-point vertex and strongly non-uniform spacing. See
[cases/README.md](cases/README.md) for how to add one.

## File formats

Everything is the FreeFem++ `.msh` dialect MEPHIT already reads and writes, so
a mesher can be compared by diffing files.

`cases/<name>/boundary.dat` — the triangulator input:

```
npt_inner npt_outer
R_hole Z_hole
R Z                    x (npt_inner + npt_outer)
```

`cases/<name>/reference/triangle.msh` — Triangle's answer, and any mesh a
backend writes:

```
npoints ntriangles nsegments
R Z 0                  x npoints
n1 n2 n3 1             x ntriangles
n1 n2 2                x nsegments
```

Vertex indices are one-based; the trailing integers are FreeFem labels.

## Backends

| backend | licence | fetched from | notes |
|---|---|---|---|
| `fortfem` | MIT | `lazy-fortran/fortfem` | `triangle_compat`, a Fortran port of Triangle's `pqY` pipeline. Default. |
| `delaunay32` | MIT | `morishuz/delaunay32` | Constrained Delaunay on quantised 32-bit integers. No Steiner refinement, so no angle bound. |
| `triangle` | **non-free** | `salsa.debian.org/science-team/triangle` | The oracle. Opt-in, see [NOTICE](NOTICE). |

No dependency is vendored. CMake fetches all of them.

## Build and run

```bash
scripts/build.sh                    # fortfem + Delaunay32 + plots
scripts/build.sh --with-triangle    # also build the Triangle oracle
scripts/run.sh                      # every backend on every case, one table
scripts/plots.sh                    # wireframes and angle histograms -> plots/
ctest --test-dir build              # reference meshes + fortfem runs
```

Single runs:

```bash
build/annulus_bench cases/tcfp_production fortfem --out /tmp/out.msh
build/annulus_bench cases/tcfp_production delaunay32 --translate
build/annulus_check cases/tcfp_production cases/tcfp_production/reference/triangle.msh
build/annulus_plot  cases/tcfp_coarse /tmp/out.msh plots/try
```

`plots/` and `results/` are gitignored.

## Results as of the pinned dependencies

| case | backend | triangles | Triangle ref | min angle | area rel. err | verdict |
|---|---|---|---|---|---|---|
| `synthetic_circle` | fortfem | 372 | 372 | 20.155° | 3.2e-16 | pass |
| `synthetic_circle` | delaunay32 | 144 | 372 | 2.577° | 1.6e-16 | fail (angle) |
| `tcfp_coarse` | fortfem | 366 | 366 | 20.122° | 3.6e-16 | pass |
| `tcfp_coarse` | delaunay32 | 142 | 366 | 2.560° | 1.8e-16 | fail (angle) |
| `tcfp_medium` | fortfem | 1048 | 1048 | 20.152° | 5.2e-16 | pass |
| `tcfp_medium` | delaunay32 | 412 | 1048 | 0.970° | 8.6e-16 | fail (angle) |
| `tcfp_production` | fortfem | 2470 | 2470 | 20.060° | 6.9e-16 | pass |
| `tcfp_production` | delaunay32 | 916 | 2470 | 0.441° | 3.4e-16 | fail (angle) |

fortfem's `triangle_compat` reproduces Triangle's triangle count and minimum
angle on every case. Delaunay32 gets the topology and the area right —
including at the `1.7e5` offset, which its quantisation handles — but has no
Steiner-point refinement, so its worst angle degrades with resolution:
2.6° at 126 boundary points, 0.44° at 814. Judging it on the 128-point fixture
alone overstates it by roughly a factor of six.

## What is checked

`annulus_check` and `annulus_bench` apply the same contract:

- input boundary points come back **first and bit-unchanged** (the `Y` flag)
- `nsegments == npt_inner + npt_outer`, and every input segment appears both as
  a boundary segment and as a triangle edge
- every triangle is counter-clockwise
- no triangle centroid lies inside the inner loop or outside the outer loop
- total area matches the analytic polygon annulus area to `1e-8` relative
- minimum angle ≥ 20°

All geometry is evaluated relative to the hole marker; at `R ≈ 1.7e5` an
absolute-coordinate area sum loses about ten digits to cancellation.

Failing the angle bound is a **result**, not a build error — `ctest` gates only
the reference meshes, and `scripts/run.sh` reports the rest as a table.

## Provenance

Boundaries were dumped from MEPHIT by writing `bdry_R`/`bdry_Z` at the
`FEM_triangulate_external` call in `write_FreeFem_mesh`
(`src/mephit_mesh.F90`), then running `mephit.bash run -m`. The shipped
equilibrium is synthetic; no experimental machine data is included.

## Licence

MIT, except the fetched Triangle build — see [NOTICE](NOTICE).
