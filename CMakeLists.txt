cmake_minimum_required(VERSION 3.22)

project(tokamak-annulus-mesh-bench
  VERSION 0.1.0
  DESCRIPTION "Vacuum-annulus meshing benchmark from MEPHIT tokamak cases"
  LANGUAGES C CXX Fortran)

option(BENCH_WITH_DELAUNAY32 "Build the Delaunay32 backend (MIT)" ON)
option(BENCH_WITH_TRIANGLE
  "Build the Shewchuk Triangle oracle -- fetched locally, non-free, see NOTICE"
  OFF)
option(BENCH_WITH_PLOTS "Build the fortplot plotting tool" ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_Fortran_STANDARD 2018)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(FetchFortfem)

add_library(bench_core
  src/bench_case.f90
  src/bench_msh.f90
  src/bench_quality.f90
  src/backend_fortfem.f90
  src/bench_backend.F90)
target_link_libraries(bench_core PUBLIC fortfem::triangle_compat)
target_include_directories(bench_core PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
set_target_properties(bench_core PROPERTIES
  Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/modules)
target_include_directories(bench_core PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/modules)

if(BENCH_WITH_DELAUNAY32)
  include(FetchDelaunay32)
  add_library(bench_delaunay32 src/backend_delaunay32.cpp)
  target_link_libraries(bench_delaunay32 PRIVATE delaunay32)
  target_link_libraries(bench_core PUBLIC bench_delaunay32)
  target_compile_definitions(bench_core PRIVATE BENCH_WITH_DELAUNAY32)
endif()

if(BENCH_WITH_TRIANGLE)
  include(FetchTriangle)
  add_library(bench_triangle src/backend_triangle.c)
  add_dependencies(bench_triangle triangle_ext)
  target_include_directories(bench_triangle PRIVATE ${TRIANGLE_INCLUDE_DIR})
  target_link_libraries(bench_triangle PRIVATE ${TRIANGLE_LIBRARY} m)
  target_link_libraries(bench_core PUBLIC bench_triangle)
  target_compile_definitions(bench_core PRIVATE BENCH_WITH_TRIANGLE)
endif()

add_executable(annulus_bench app/annulus_bench.f90)
target_link_libraries(annulus_bench PRIVATE bench_core)

add_executable(annulus_check app/annulus_check.f90)
target_link_libraries(annulus_check PRIVATE bench_core)

if(BENCH_WITH_PLOTS)
  include(FetchFortplot)
  add_executable(annulus_plot app/annulus_plot.f90)
  target_link_libraries(annulus_plot PRIVATE bench_core fortplot::fortplot)
endif()

enable_testing()
set(BENCH_CASES tcfp_coarse tcfp_medium tcfp_production synthetic_circle)

# The shipped Triangle reference meshes define the contract; checking them
# needs no mesher at all and must always pass.
foreach(case IN LISTS BENCH_CASES)
  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/cases/${case}/reference/triangle.msh)
    add_test(NAME reference_${case}
      COMMAND annulus_check
        ${CMAKE_CURRENT_SOURCE_DIR}/cases/${case}
        ${CMAKE_CURRENT_SOURCE_DIR}/cases/${case}/reference/triangle.msh)
  endif()
endforeach()

# Backend runs are reported, not gated: a backend that cannot hit 20 degrees
# is a result, not a broken build. Use scripts/run.sh for the full table.
foreach(case IN LISTS BENCH_CASES)
  add_test(NAME fortfem_${case}
    COMMAND annulus_bench ${CMAKE_CURRENT_SOURCE_DIR}/cases/${case} fortfem
      --out ${CMAKE_CURRENT_BINARY_DIR}/fortfem_${case}.msh)
endforeach()
