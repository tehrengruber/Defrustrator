cmake_minimum_required(VERSION 2.8)
set(CMAKE_CXX_STANDARD 11)

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
# todo: check if eigen is installed
add_executable(example_eigen example/eigen.cpp)
target_include_directories(example_eigen PUBLIC /usr/include/eigen3)
set_source_files_properties(example/eigen.cpp PROPERTIES COMPILE_FLAGS -g)
target_link_libraries(example_eigen ldl)

add_executable(example_eigen2 example/eigen2.cpp)
target_include_directories(example_eigen2 PUBLIC /usr/include/eigen3)
set_source_files_properties(example/eigen2.cpp PROPERTIES COMPILE_FLAGS -g)
target_link_libraries(example_eigen2 ldl)