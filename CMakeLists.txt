cmake_minimum_required(VERSION 2.8)
set(CMAKE_CXX_STANDARD 11)
add_library(example_shared SHARED example/shared.cpp)

#find_package(LLVM CONFIG REQUIRED PATHS /home/tehrengruber/Downloads/cling_2016-08-09_ubuntu16/lib)
#add_definitions(${LLVM_DEFINITIONS})
#message("${LLVM_AVAILABLE_LIBS}")

include_directories("include")
include_directories("/home/tehrengruber/Development/EnhancedLLDB/cling_compile_test/inst/include")
link_directories(/home/tehrengruber/Development/EnhancedLLDB/cling_compile_test/inst/lib)
add_library(lldbclingbridge SHARED src/bridge.cpp)
target_link_libraries(lldbclingbridge dl cling clingUserInterface)

#SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -L/home/tehrengruber/Downloads/cling_2016-08-09_ubuntu16/lib" )
#add_executable(cling_driver src/cling.cpp)
#target_link_libraries(cling_driver cling clingUserInterface) 

#add_executable(bridge_test src/bridge_test)
#target_link_libraries(bridge_test dl)
