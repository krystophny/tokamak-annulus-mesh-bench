// Delaunay32 backend: MIT-licensed constrained Delaunay on quantised 32-bit
// integer coordinates. It has no Steiner-point quality refinement, so it is
// expected to reproduce the topology and area but not the 20 degree bound.
//
// Delaunay32 is fetched at build time, never vendored.

#include <delaunay32/delaunay.hpp>
#include <delaunay32/quantization.hpp>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <utility>
#include <vector>

extern "C" int bench_delaunay32_mesh(const int npt_inner,
                                     const int npt_outer,
                                     const double *bdry_R,
                                     const double *bdry_Z,
                                     const double R_hole,
                                     const double Z_hole,
                                     const char *fname)
{
  if (npt_inner < 3 || npt_outer < 3 || !bdry_R || !bdry_Z || !fname) {
    return 1;
  }
  if (!std::isfinite(R_hole) || !std::isfinite(Z_hole)) {
    return 1;
  }

  const int npoint = npt_inner + npt_outer;
  std::vector<delaunay32::FloatPoint> source(static_cast<std::size_t>(npoint));
  for (int point = 0; point < npoint; ++point) {
    source[static_cast<std::size_t>(point)] = {bdry_R[point], bdry_Z[point]};
  }

  try {
    delaunay32::QuantizationOptions quantization_options;
    quantization_options.collision_policy =
      delaunay32::QuantizationCollisionPolicy::Reject;
    const delaunay32::QuantizationResult quantized =
      delaunay32::quantize(source, quantization_options);

    // The hole marker has no counterpart in the polygon API: the inner loop
    // is declared as a hole ring directly.
    delaunay32::PolygonDomain domain;
    domain.outer_ring.reserve(static_cast<std::size_t>(npt_outer));
    for (int point = 0; point < npt_outer; ++point) {
      domain.outer_ring.push_back(static_cast<std::uint32_t>(npt_inner + point));
    }
    std::vector<std::uint32_t> hole;
    hole.reserve(static_cast<std::size_t>(npt_inner));
    for (int point = 0; point < npt_inner; ++point) {
      hole.push_back(static_cast<std::uint32_t>(point));
    }
    domain.holes.push_back(std::move(hole));

    delaunay32::Triangulator triangulator;
    triangulator.set_points(quantized.points);
    triangulator.set_polygons({std::move(domain)});
    const delaunay32::TriangulationResult result = triangulator.triangulate();

    std::ofstream mesh_file(fname);
    if (!mesh_file) {
      return 2;
    }
    mesh_file.precision(17);
    mesh_file << npoint << ' ' << result.triangles.size() << ' ' << npoint
              << '\n';
    for (int point = 0; point < npoint; ++point) {
      mesh_file << std::scientific << bdry_R[point] << ' ' << bdry_Z[point]
                << " 0\n";
    }
    for (const delaunay32::Triangle &triangle : result.triangles) {
      mesh_file << triangle.i0 + 1U << ' ' << triangle.i1 + 1U << ' '
                << triangle.i2 + 1U << " 1\n";
    }
    for (int point = 0; point < npt_inner; ++point) {
      mesh_file << point + 1 << ' ' << (point + 1) % npt_inner + 1 << " 2\n";
    }
    for (int point = 0; point < npt_outer; ++point) {
      mesh_file << npt_inner + point + 1 << ' '
                << npt_inner + (point + 1) % npt_outer + 1 << " 2\n";
    }
    if (!mesh_file) {
      return 2;
    }
  } catch (const std::exception &error) {
    std::fprintf(stderr, "delaunay32: %s\n", error.what());
    return 3;
  }
  return 0;
}
