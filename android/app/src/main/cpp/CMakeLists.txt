cmake_minimum_required(VERSION 3.22.1)
project(nexai_hardening LANGUAGES CXX)
add_library(nexai_hardening SHARED
    nexai_anti_debug.cpp
)
set_target_properties(nexai_hardening PROPERTIES CXX_STANDARD 17)
target_compile_options(nexai_hardening PRIVATE -Wall -Wextra -fvisibility=hidden)
find_library(log-lib log)
target_link_libraries(nexai_hardening PRIVATE ${log-lib})