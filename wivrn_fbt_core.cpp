#include <openxr/openxr.h>
#include <openxr/openxr_platform.h>
#include <iostream>
#include <vector>
#include <thread>
#include <queue>
#include <mutex>
#include <chrono>
#include <cmath>
#include <cstring>

#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

struct TrackingData {
    uint32_t id;
    float position[3];      // x, y, z
    float rotation[4];      // quaternion x, y, z, w
    float velocity[3];
    uint64_t timestamp;
};

struct DeviceTracker {
    uint32_t device_id;
    std::string device_name;
    TrackingData last_data;
    bool is_connected;
    std::chrono::steady_clock::time_point last_update;
};

class WiVRnFBTService {
private:
    XrInstance instance;
    XrSession session;
    XrSpace reference_space;
    std::vector<DeviceTracker> trackers;
    std::queue<TrackingData> data_queue;
    std::mutex data_mutex;
    int socket_fd;
    bool running;

public:
    WiVRnFBTService() : running(false), socket_fd(-1) {}

    bool initializeOpenXR() {
        XrApplicationInfo app_info{};
        strcpy(app_info.applicationName, "WiVRn-FBT");
        app_info.applicationVersion = 1;
        strcpy(app_info.engineName, "WiVRn");
        app_info.engineVersion = 1;
        app_info.apiVersion = XR_CURRENT_API_VERSION;

        XrInstanceCreateInfo create_info{};
        create_info.type = XR_TYPE_INSTANCE_CREATE_INFO;
        create_info.applicationInfo = app_info;
        create_info.enabledExtensionCount = 0;
        create_info.enabledApiLayerCount = 0;

        if (xrCreateInstance(&create_info, &instance) != XR_SUCCESS) {
            std::cerr << "Failed to create OpenXR instance" << std::endl;
            return false;
        }

        XrSystemGetInfo system_info{};
        system_info.type = XR_TYPE_SYSTEM_GET_INFO;
        system_info.formFactor = XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;

        XrSystemId system_id;
        if (xrGetSystem(instance, &system_info, &system_id) != XR_SUCCESS) {
            std::cerr << "Failed to get OpenXR system" << std::endl;
            return false;
        }

        XrSessionCreateInfo session_info{};
        session_info.type = XR_TYPE_SESSION_CREATE_INFO;
        session_info.systemId = system_id;

        if (xrCreateSession(instance, &session_info, &session) != XR_SUCCESS) {
            std::cerr << "Failed to create OpenXR session" << std::endl;
            return false;
        }

        XrReferenceSpaceCreateInfo space_info{};
        space_info.type = XR_TYPE_REFERENCE_SPACE_CREATE_INFO;
        space_info.referenceSpaceType = XR_REFERENCE_SPACE_TYPE_STAGE;
        space_info.poseInReferenceSpace.orientation.w = 1.0f;

        if (xrCreateReferenceSpace(session, &space_info, &reference_space) != XR_SUCCESS) {
            std::cerr << "Failed to create reference space" << std::endl;
            return false;
        }

        std::cout << "OpenXR initialization successful" << std::endl;
        return true;
    }

    bool setupTrackers() {
        // Initialize head tracker (always present)
        trackers.push_back({0, "Head", {}, true, std::chrono::steady_clock::now()});
        
        // Initialize body trackers
        trackers.push_back({1, "Chest", {}, true, std::chrono::steady_clock::now()});
        trackers.push_back({2, "Waist", {}, true, std::chrono::steady_clock::now()});
        trackers.push_back({3, "LeftFoot", {}, true, std::chrono::steady_clock::now()});
        trackers.push_back({4, "RightFoot", {}, true, std::chrono::steady_clock::now()});
        trackers.push_back({5, "LeftElbow", {}, true, std::chrono::steady_clock::now()});
        trackers.push_back({6, "RightElbow", {}, true, std::chrono::steady_clock::now()});

        std::cout << "Initialized " << trackers.size() << " trackers" << std::endl;
        return true;
    }

    bool setupNetworkSocket(int port = 9876) {
        socket_fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (socket_fd < 0) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }

        struct sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        addr.sin_port = htons(port);

        if (bind(socket_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            std::cerr << "Failed to bind socket to port " << port << std::endl;
            return false;
        }

        std::cout << "Listening on port " << port << " for tracking data" << std::endl;
        return true;
    }

    void receiveTrackingData() {
        char buffer[512];
        struct sockaddr_in src_addr{};
        socklen_t src_len = sizeof(src_addr);

        while (running) {
            ssize_t n = recvfrom(socket_fd, buffer, sizeof(buffer), 0, 
                                (struct sockaddr*)&src_addr, &src_len);
            
            if (n >= (int)sizeof(TrackingData)) {
                std::lock_guard<std::mutex> lock(data_mutex);
                TrackingData* data = (TrackingData*)buffer;
                data_queue.push(*data);
                
                // Update tracker
                for (auto& tracker : trackers) {
                    if (tracker.device_id == data->id) {
                        tracker.last_data = *data;
                        tracker.last_update = std::chrono::steady_clock::now();
                        break;
                    }
                }
            }
        }
    }

    void processPoses() {
        while (running) {
            XrFrameWaitInfo wait_info{};
            wait_info.type = XR_TYPE_FRAME_WAIT_INFO;

            XrFrameState frame_state{};
            frame_state.type = XR_TYPE_FRAME_STATE;

            if (xrWaitFrame(session, &wait_info, &frame_state) != XR_SUCCESS) {
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
                continue;
            }

            std::lock_guard<std::mutex> lock(data_mutex);
            
            while (!data_queue.empty()) {
                TrackingData data = data_queue.front();
                data_queue.pop();

                XrSpaceLocation space_loc{};
                space_loc.type = XR_TYPE_SPACE_LOCATION;

                // Convert tracking data to OpenXR format
                // This would normally interface with action spaces for each tracker
                std::cout << "Processing tracker " << data.id << " at ("
                         << data.position[0] << ", " 
                         << data.position[1] << ", "
                         << data.position[2] << ")" << std::endl;
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    }

    bool start() {
        if (!initializeOpenXR()) return false;
        if (!setupTrackers()) return false;
        if (!setupNetworkSocket()) return false;

        running = true;
        
        std::thread receive_thread(&WiVRnFBTService::receiveTrackingData, this);
        std::thread process_thread(&WiVRnFBTService::processPoses, this);
        
        receive_thread.detach();
        process_thread.detach();

        std::cout << "WiVRn FBT Service started successfully" << std::endl;
        return true;
    }

    void stop() {
        running = false;
        if (socket_fd >= 0) {
            close(socket_fd);
        }
        if (session) {
            xrDestroySession(session);
        }
        if (instance) {
            xrDestroyInstance(instance);
        }
    }

    ~WiVRnFBTService() {
        stop();
    }
};

int main() {
    WiVRnFBTService service;
    
    if (!service.start()) {
        std::cerr << "Failed to start service" << std::endl;
        return 1;
    }

    std::cout << "Service running. Press Ctrl+C to stop." << std::endl;
    
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    return 0;
}
