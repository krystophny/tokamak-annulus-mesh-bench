include(FetchContent)

set(FORTPLOT_REF "18e6b4442a6f9e083b8965ccf1a8847a6e32b3d9" CACHE STRING
    "fortplot commit to fetch")
set(FORTPLOT_PATH "" CACHE PATH "Local fortplot source (empty = fetch)")

set(FORTPLOT_BUILD_FORTARRAY_ADAPTER OFF CACHE BOOL "" FORCE)

if(FORTPLOT_PATH)
  FetchContent_Declare(fortplot SOURCE_DIR "${FORTPLOT_PATH}")
else()
  FetchContent_Declare(fortplot
    GIT_REPOSITORY https://github.com/lazy-fortran/fortplot.git
    GIT_TAG ${FORTPLOT_REF}
  )
endif()

FetchContent_MakeAvailable(fortplot)
