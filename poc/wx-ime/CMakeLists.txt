# issue #13 step6 PoC — wxWidgets inline IME.
# Build:
#   cmake -S . -B build -DCMAKE_PREFIX_PATH=$(brew --prefix wxwidgets)
#   cmake --build build
#   ./build/wx-ime
cmake_minimum_required(VERSION 3.16)
project(wx_ime_poc LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(wxWidgets REQUIRED COMPONENTS core base)
include(${wxWidgets_USE_FILE})

add_executable(wx-ime main.cpp ime_hook.mm)
set_source_files_properties(ime_hook.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
target_link_libraries(wx-ime PRIVATE ${wxWidgets_LIBRARIES} "-framework Cocoa")
