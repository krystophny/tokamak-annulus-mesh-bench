include(FetchContent)

set(DELAUNAY32_REF "ae2d0cf9167deefd0d180e39a30be3cc8f0b0698" CACHE STRING
    "Delaunay32 commit to fetch")
set(DELAUNAY32_PATH "" CACHE PATH "Local Delaunay32 source (empty = fetch)")

set(DELAUNAY32_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(DELAUNAY32_BUILD_EXTRAS OFF CACHE BOOL "" FORCE)
set(DELAUNAY32_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(DELAUNAY32_BUILD_TESTS OFF CACHE BOOL "" FORCE)

if(DELAUNAY32_PATH)
  FetchContent_Declare(delaunay32 SOURCE_DIR "${DELAUNAY32_PATH}")
else()
  FetchContent_Declare(delaunay32
    GIT_REPOSITORY https://github.com/morishuz/delaunay32.git
    GIT_TAG ${DELAUNAY32_REF}
  )
endif()

FetchContent_MakeAvailable(delaunay32)
