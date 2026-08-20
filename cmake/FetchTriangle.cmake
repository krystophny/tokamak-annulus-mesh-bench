# Shewchuk's Triangle, fetched and built as the reference oracle.
#
# Triangle is NOT redistributed by this repository and is not covered by its
# MIT licence: its own terms forbid redistribution for compensation and
# require a direct arrangement with the author for commercial distribution
# (Debian ships it in non-free). Enabling this backend is an opt-in local
# build for comparison purposes only. See NOTICE.
include(ExternalProject)

set(TRIANGLE_REPO "https://salsa.debian.org/science-team/triangle.git"
    CACHE STRING "Triangle git repository")
set(TRIANGLE_REF "dd24af510c49f78c77ebf1c7a44fdae7604f7ed0" CACHE STRING "Triangle commit to fetch")

ExternalProject_Add(triangle_ext
  PREFIX ${CMAKE_BINARY_DIR}/triangle
  GIT_REPOSITORY ${TRIANGLE_REPO}
  GIT_TAG ${TRIANGLE_REF}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND /bin/bash ${CMAKE_CURRENT_SOURCE_DIR}/cmake/build_triangle.sh <SOURCE_DIR>
  INSTALL_COMMAND ""
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  BUILD_BYPRODUCTS <SOURCE_DIR>/libtriangle.so
)

set(TRIANGLE_DIR ${CMAKE_BINARY_DIR}/triangle/src/triangle_ext)
set(TRIANGLE_INCLUDE_DIR ${TRIANGLE_DIR})
set(TRIANGLE_LIBRARY ${TRIANGLE_DIR}/libtriangle.so)
