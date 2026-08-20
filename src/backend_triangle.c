/* Shewchuk Triangle oracle.
 *
 * This is the reference the benchmark measures against: the exact call
 * MEPHIT makes today, flags and all. Triangle itself is fetched at build
 * time and never vendored here -- its licence forbids redistribution for
 * compensation, which is the reason this benchmark exists.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define REAL double
#define VOID void
#include "triangle.h"

int bench_triangle_mesh(const int npt_inner,
                        const int npt_outer,
                        const double *bdry_R,
                        const double *bdry_Z,
                        const double R_hole,
                        const double Z_hole,
                        const char *fname)
{
  int k;
  FILE *fid;
  struct triangulateio in, out, vorout;

  memset(&in, 0, sizeof(struct triangulateio));
  memset(&out, 0, sizeof(struct triangulateio));
  memset(&vorout, 0, sizeof(struct triangulateio));

  in.numberofpoints = npt_inner + npt_outer;
  in.numberofsegments = npt_inner + npt_outer;
  in.numberofholes = 1;
  in.pointlist = (REAL *) calloc(2 * (size_t) in.numberofpoints, sizeof(REAL));
  in.pointmarkerlist = (int *) calloc((size_t) in.numberofpoints, sizeof(int));
  in.segmentlist = (int *) calloc(2 * (size_t) in.numberofsegments, sizeof(int));
  in.holelist = (REAL *) calloc(2 * (size_t) in.numberofholes, sizeof(REAL));
  if (!in.pointlist || !in.pointmarkerlist || !in.segmentlist || !in.holelist) {
    return 1;
  }
  for (k = 0; k < in.numberofpoints; ++k) {
    in.pointlist[2 * k] = bdry_R[k];
    in.pointlist[2 * k + 1] = bdry_Z[k];
  }
  for (k = 0; k < npt_inner; ++k) {
    in.segmentlist[2 * k] = k;
    in.segmentlist[2 * k + 1] = (k + 1) % npt_inner;
  }
  for (k = 0; k < npt_outer; ++k) {
    in.segmentlist[2 * (npt_inner + k)] = npt_inner + k;
    in.segmentlist[2 * (npt_inner + k) + 1] = npt_inner + (k + 1) % npt_outer;
  }
  in.holelist[0] = R_hole;
  in.holelist[1] = Z_hole;

  /* B omit boundary markers, e edge list, j clean point list, n neighbours,
     p triangulate the given PSLG, q 20 degree quality bound, Y do not split
     boundary segments, z zero-based indices. */
  triangulate("BejnpqYz", &in, &out, &vorout);

  fid = fopen(fname, "w");
  if (!fid) {
    return 2;
  }
  fprintf(fid, "%i %i %i\n", out.numberofpoints, out.numberoftriangles,
          out.numberofsegments);
  for (k = 0; k < out.numberofpoints; ++k) {
    fprintf(fid, "%.16e %.16e 0\n", out.pointlist[2 * k],
            out.pointlist[2 * k + 1]);
  }
  for (k = 0; k < out.numberoftriangles; ++k) {
    fprintf(fid, "%i %i %i 1\n", out.trianglelist[3 * k] + 1,
            out.trianglelist[3 * k + 1] + 1, out.trianglelist[3 * k + 2] + 1);
  }
  for (k = 0; k < out.numberofsegments; ++k) {
    fprintf(fid, "%i %i 2\n", out.segmentlist[2 * k] + 1,
            out.segmentlist[2 * k + 1] + 1);
  }
  fclose(fid);

  free(in.pointlist);
  free(in.pointmarkerlist);
  free(in.segmentlist);
  free(in.holelist); /* aliased by out.holelist */
  trifree(out.pointlist);
  trifree(out.trianglelist);
  trifree(out.neighborlist);
  trifree(out.segmentlist);
  trifree(out.edgelist);
  return 0;
}
