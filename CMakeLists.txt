cmake_minimum_required(VERSION 3.10)
project(wivrn-fbt VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenXR SDK
find_package(OpenXR REQUIRED)

# Include directories
include_directories(${OPENXR_INCLUDE_DIRS})

# Create main service executable
add_executable(wivrn-fbt-service wivrn_fbt_core.cpp)
target_link_libraries(wivrn-fbt-service ${OPENXR_LIBRARIES})

# Install targets
install(TARGETS wivrn-fbt-service DESTINATION /usr/local/bin)

# Install configuration files
install(FILES wivrn_fbt_config.json DESTINATION /etc/wivrn-fbt)
install(FILES wivrn-fbt.service DESTINATION /etc/systemd/system)

# Install Python dependencies
install(FILES requirements.txt DESTINATION /opt/wivrn-fbt)
install(FILES webcam_tracker.py DESTINATION /opt/wivrn-fbt PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

message(STATUS "WiVRn FBT Service CMake configured")
