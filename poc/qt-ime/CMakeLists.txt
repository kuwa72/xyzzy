# issue #13 step6 PoC — Qt inline IME.
# Build:
#   cmake -S . -B build -DCMAKE_PREFIX_PATH=$(brew --prefix qt)
#   cmake --build build
#   ./build/qt-ime
cmake_minimum_required(VERSION 3.16)
project(qt_ime_poc LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

add_executable(qt-ime main.cpp)
target_link_libraries(qt-ime PRIVATE Qt6::Widgets)
