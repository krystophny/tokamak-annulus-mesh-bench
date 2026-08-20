# Cases

Each case directory holds

- `boundary.dat` — the triangulator input (see the top-level README)
- `reference/triangle.msh` — Triangle's output for that input, where available

## How the `tcfp_*` cases were produced

In [MEPHIT](https://github.com/itpplasma/MEPHIT), `write_FreeFem_mesh` in
`src/mephit_mesh.F90` builds the two loops and calls
`FEM_triangulate_external`. Dumping `npt_inner`, `npt_outer`, the hole marker
and `bdry_R`/`bdry_Z` at that call site produces `boundary.dat`; `outer.msh`
from the same run is the Triangle reference.

```bash
# in a MEPHIT checkout, with the boundary dump in place
build/scripts/mephit.bash init -c data/mephit_g000001.0001_TCFP_hip.in \
                               -g data/g000001.0001_TCFP_hip -d kilca rundir
build/scripts/mephit.bash run -m rundir
cp rundir/outer_boundary.dat cases/<name>/boundary.dat
cp rundir/outer.msh          cases/<name>/reference/triangle.msh
```

The three variants differ only in `config%max_Delta_rad`:

| case | `max_Delta_rad` |
|---|---|
| `tcfp_coarse` | 3.0 cm |
| `tcfp_medium` | 1.0 cm |
| `tcfp_production` | 0.45 cm (as shipped) |

`config%max_Delta_rad` sets the radial flux-surface spacing, and MEPHIT picks
the poloidal point count from it as
`npt_inner ≈ sqrt(3) * perimeter / (2 * max_Delta_rad)`.

## `synthetic_circle`

Generated analytically, not from a run: 128 points on `R = 170 + 50 cos θ`,
`Z = 50 sin θ`, and 16 points on the doubled circle, hole marker at
`(170, 0)`. It reproduces the `1/8` point ratio and `2×` scale of the real
problem without the `1.7e5` coordinate offset. This is the fixture from
[MEPHIT#40](https://github.com/itpplasma/MEPHIT/pull/40).

## Adding a shaped case

The cases here are all circular, because the equilibrium MEPHIT ships is. A
shaped, diverted case — ASDEX Upgrade shot 33353 is the natural one — differs
in ways none of these exercise:

- elongation and triangularity, so the annulus gap varies strongly with
  poloidal angle while the outer loop stays an axis-aligned ellipse
- non-uniform inner-loop spacing, since the points are equidistant in the
  symmetry flux angle rather than in arclength
- an X-point vertex: MEPHIT snaps the outermost-surface node nearest the X
  point exactly onto it, leaving a kink with two very unequal adjacent edges
- a Z-asymmetric outer ellipse, because that snap pulls `Z_min` down

Adding one needs the equilibrium and profile files for the shot, which are not
publicly redistributable. The dump procedure above is otherwise unchanged.
Check first that the resulting boundary carries no restricted machine data
before committing it here.
