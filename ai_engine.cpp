#include <opencv2/opencv.hpp>
#include <opencv2/dnn.hpp>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <iostream>
#include <vector>
#include <string>
#include <thread>
#include <atomic>

using namespace std;
using namespace cv;
using namespace cv::dnn;

atomic<int> g_brightness(128); 
atomic<int> g_contrast(32);    
atomic<int> g_saturation(64);  
atomic<int> g_gamma(120);      
atomic<int> g_yolo_enable(0);  

Net yolo_net;
bool yolo_initialized = false;
const vector<string> class_names = {"person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light"};

void init_yolo() {
    try {
        yolo_net = readNet("yolov5s.onnx"); // 需确保同目录下有该模型文件
        yolo_net.setPreferableBackend(DNN_BACKEND_OPENCV);
        yolo_net.setPreferableTarget(DNN_TARGET_CPU); 
        yolo_initialized = true;
        cout << "[YOLO] ONNX Model loaded on Host PC!" << endl;
    } catch (const Exception& e) {
        cerr << "[YOLO] Load failed: " << e.what() << endl;
    }
}

void control_api_server() {
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt));
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(8082);
    bind(server_fd, (struct sockaddr *)&address, sizeof(address));
    listen(server_fd, 3);

    cout << "[API] Control server listening on port 8082" << endl;

    while (true) {
        int client = accept(server_fd, NULL, NULL);
        if (client < 0) continue;

        char buffer[1024] = {0};
        read(client, buffer, 1024);
        string request(buffer);

        if (request.find("GET /set?") != string::npos) {
            size_t qmark = request.find('?');
            if (qmark != string::npos) {
                string params = request.substr(qmark + 1);
                size_t space = params.find(' ');
                if (space != string::npos) params = params.substr(0, space);

                // 解析参数
                size_t pos = 0;
                while ((pos = params.find('&')) != string::npos) {
                    string param = params.substr(0, pos);
                    size_t eq = param.find('=');
                    if (eq != string::npos) {
                        string key = param.substr(0, eq);
                        string val = param.substr(eq + 1);
                        if (key == "b") g_brightness = stoi(val);
                        else if (key == "c") g_contrast = stoi(val);
                        else if (key == "s") g_saturation = stoi(val);
                        else if (key == "g") g_gamma = stoi(val);
                        else if (key == "yolo") g_yolo_enable = stoi(val);
                    }
                    params.erase(0, pos + 1);
                }
                // 处理最后一个参数
                size_t eq = params.find('=');
                if (eq != string::npos) {
                    string key = params.substr(0, eq);
                    string val = params.substr(eq + 1);
                    if (key == "b") g_brightness = stoi(val);
                    else if (key == "c") g_contrast = stoi(val);
                    else if (key == "s") g_saturation = stoi(val);
                    else if (key == "g") g_gamma = stoi(val);
                    else if (key == "yolo") g_yolo_enable = stoi(val);
                }
            }
        }

        string response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nOK";
        send(client, response.c_str(), response.size(), 0);
        close(client);
    }
}

void apply_software_filters(Mat& frame) {
    // 1. 亮度和对比度
    double alpha = g_contrast.load() / 32.0; 
    double beta = g_brightness.load() - 128.0;
    frame.convertTo(frame, -1, alpha, beta);

    // 2. 饱和度
    double sat_val = g_saturation.load() / 64.0;
    if (abs(sat_val - 1.0) > 0.05) {
        Mat hsv;
        cvtColor(frame, hsv, COLOR_BGR2HSV);
        vector<Mat> channels;
        split(hsv, channels);
        channels[1] *= sat_val;
        merge(channels, hsv);
        cvtColor(hsv, frame, COLOR_HSV2BGR);
    }
    
    // 3. Gamma校正
    if (g_gamma.load() != 120) {
        double gamma = g_gamma.load() / 120.0;
        Mat lut(1, 256, CV_8U);
        uchar* p = lut.ptr();
        for (int i = 0; i < 256; i++) {
            p[i] = saturate_cast<uchar>(pow(i / 255.0, gamma) * 255.0);
        }
        LUT(frame, lut, frame);
    }
    
    // 4. YOLO 目标检测流 (增加 NMS 抑制重叠框)
    if (g_yolo_enable.load() && yolo_initialized) {
        Mat blob;
        blobFromImage(frame, blob, 1./255., Size(640, 640), Scalar(), true, false);
        yolo_net.setInput(blob);
        vector<Mat> outputs;
        yolo_net.forward(outputs, yolo_net.getUnconnectedOutLayersNames());

        float* data = (float*)outputs[0].data;
        const int rows = 25200; // YOLOv5s 标准输出维度
        float x_factor = frame.cols / 640.0;
        float y_factor = frame.rows / 640.0;

        vector<int> class_ids;
        vector<float> confidences;
        vector<Rect> boxes;

        // 解析并筛选高置信度目标
        for (int i = 0; i < rows; ++i) {
            float confidence = data[4];
            if (confidence >= 0.4) {
                float* classes_scores = data + 5;
                Mat scores(1, 80, CV_32FC1, classes_scores);
                Point class_id;
                double max_class_score;
                minMaxLoc(scores, 0, &max_class_score, 0, &class_id);
                if (max_class_score > 0.5) {
                    confidences.push_back(confidence);
                    class_ids.push_back(class_id.x);

                    float x = data[0]; float y = data[1];
                    float w = data[2]; float h = data[3];
                    int left = int((x - 0.5 * w) * x_factor);
                    int top = int((y - 0.5 * h) * y_factor);
                    int width = int(w * x_factor);
                    int height = int(h * y_factor);
                    boxes.push_back(Rect(left, top, width, height));
                }
            }
            data += 85;
        }

        // NMS (非极大值抑制) 消除多余的重叠框
        vector<int> indices;
        dnn::NMSBoxes(boxes, confidences, 0.5, 0.4, indices);
        for (size_t i = 0; i < indices.size(); ++i) {
            int idx = indices[i];
            Rect box = boxes[idx];
            // 绘制绿色矩形框
            rectangle(frame, box, Scalar(0, 255, 0), 2);
            // 绘制标签与置信度
            string label = (class_ids[idx] < class_names.size() ? class_names[class_ids[idx]] : "obj") + ":" + to_string(confidences[idx]).substr(0,4);
            putText(frame, label, Point(box.x, box.y - 5), FONT_HERSHEY_SIMPLEX, 0.5, Scalar(0, 255, 0), 2);
        }
    }
}

int main(int argc, char** argv) {
    // 接收从 Flutter 传入的小车 IP 地址
    string robot_ip = "192.168.12.1";
    if (argc > 1) {
        robot_ip = argv[1];
    }

    init_yolo(); 
    thread ctrl_thread(control_api_server);
    ctrl_thread.detach();

    // 【关键修改】：不再读取本地摄像头，而是拉取下位机 web_video_server 的原始流
    string stream_url = "http://" + robot_ip + ":8080/stream?topic=/usb_cam/image_raw";
    VideoCapture cap(stream_url);
    if (!cap.isOpened()) {
        cerr << "Failed to open Robot Camera Stream: " << stream_url << endl;
        return -1;
    }

    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt));
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(8081);
    bind(server_fd, (struct sockaddr *)&address, sizeof(address));
    listen(server_fd, 3);

    cout << "==========================================" << endl;
    cout << "[上位机 AI 引擎就绪] 拉取下位机 IP: " << robot_ip << endl;
    cout << "[引擎就绪] 融合后画面流推向: Localhost:8081" << endl;
    cout << "==========================================" << endl;

    while(true) {
        int client = accept(server_fd, NULL, NULL);
        if (client < 0) continue;
        string header = "HTTP/1.0 200 OK\r\nConnection: close\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";
        send(client, header.c_str(), header.size(), MSG_NOSIGNAL);

        Mat frame;
        vector<uchar> buf;
        vector<int> params = {IMWRITE_JPEG_QUALITY, 85};

        while(true) {
            cap >> frame;
            if(frame.empty()) continue;

            apply_software_filters(frame); 

            imencode(".jpg", frame, buf, params);
            string img_header = "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: " + to_string(buf.size()) + "\r\n\r\n";
            if(send(client, img_header.c_str(), img_header.size(), MSG_NOSIGNAL) < 0) break;
            if(send(client, buf.data(), buf.size(), MSG_NOSIGNAL) < 0) break;
            if(send(client, "\r\n", 2, MSG_NOSIGNAL) < 0) break;
        }
        close(client);
    }
    return 0;
}