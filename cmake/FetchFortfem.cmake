include(FetchContent)

set(FORTFEM_REF "605dc7f056aa9b15cf8e0673eaa13b13ce12a273" CACHE STRING
    "fortfem commit to fetch")
set(FORTFEM_PATH "" CACHE PATH "Local fortfem source (empty = fetch)")

# Only the dependency-free triangle_compat mesher is needed here; the rest of
# fortfem would drag in fortsparse and BLAS for no benefit.
set(FORTFEM_TRIANGLE_COMPAT_ONLY ON CACHE BOOL "" FORCE)

if(FORTFEM_PATH)
  FetchContent_Declare(fortfem SOURCE_DIR "${FORTFEM_PATH}")
else()
  FetchContent_Declare(fortfem
    GIT_REPOSITORY https://github.com/lazy-fortran/fortfem.git
    GIT_TAG ${FORTFEM_REF}
  )
endif()

FetchContent_MakeAvailable(fortfem)
