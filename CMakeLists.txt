project(Defrustrator)
cmake_minimum_required(VERSION 2.8)
set(CMAKE_CXX_STANDARD 11)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

#
# General setup
#
include_directories(include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/bin/cling/include)
link_directories(${CMAKE_CURRENT_SOURCE_DIR}/bin/cling/lib)

#
# Plugin bridge Shared library loaded inside LLDB
#
add_library(lldbclingbridge SHARED src/bridge.cpp)
target_link_libraries(lldbclingbridge dl cling clingUserInterface)
target_compile_definitions(lldbclingbridge PUBLIC DEFRUSTRATOR_BASE_PATH=\"${CMAKE_CURRENT_SOURCE_DIR}\")

#
# Examples
#
add_executable(example_scope example/scope.cpp)
target_link_libraries(example_scope dl)

find_package (Eigen3 3.3 REQUIRED NO_MODULE)

if (TARGET Eigen3::Eigen)
  add_executable(example_eigen example/eigen.cpp)
  set_source_files_properties(example/eigen.cpp PROPERTIES COMPILE_FLAGS -g)
  target_link_libraries(example_eigen dl Eigen3::Eigen)

  add_executable(example_eigen2 example/eigen2.cpp)
  set_source_files_properties(example/eigen2.cpp PROPERTIES COMPILE_FLAGS -g)
  target_link_libraries(example_eigen2 dl Eigen3::Eigen)
endif (TARGET Eigen3::Eigen)
