/**
 * Sherpa-ONNX TTS 独立服务进程 (MSVC编译)
 *
 * 用途: 解决 MinGW/MSVC ABI 不兼容问题
 * 通信: JSON via stdin/stdout
 * 编译: MSVC (使用预编译的 sherpa-onnx-v1.12.9-win-x64-shared)
 */

#include <iostream>
#include <string>
#include <fstream>
#include <vector>
#include <cstdint>
#include <stdexcept>
#include <memory>

// Windows 特定头文件
#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

// JSON库 - 使用简单的手动解析，避免外部依赖
#include "sherpa-onnx/c-api/cxx-api.h"

using namespace sherpa_onnx::cxx;

// 简单的JSON解析（仅支持基本字段）
struct TtsRequest {
    std::string command;      // "init", "synthesize", "stop"
    std::string text;         // 待合成文本
    std::string output_path;  // 输出WAV文件路径
    std::string model_dir;    // 模型目录（用于init）
    double rate = 1.0;        // 语速
    double volume = 0.8;      // 音量（暂不使用，由主程序控制）
    int speaker_id = 0;       // 说话人ID
};

// 简单的JSON响应
struct TtsResponse {
    bool success;
    std::string message;
    std::string output_path;
};

// 全局TTS引擎实例
std::unique_ptr<OfflineTts> g_tts = nullptr;
int32_t g_sample_rate = 0;

// 解析简单JSON（手动实现，避免第三方库）
TtsRequest parseRequest(const std::string& json) {
    TtsRequest req;

    // 简单字符串解析（假设格式规范）
    size_t pos = 0;

    // 查找 "command"
    pos = json.find("\"command\"");
    if (pos != std::string::npos) {
        size_t start = json.find("\"", pos + 9) + 1;
        size_t end = json.find("\"", start);
        req.command = json.substr(start, end - start);
    }

    // 查找 "text"
    pos = json.find("\"text\"");
    if (pos != std::string::npos) {
        size_t start = json.find("\"", pos + 6) + 1;
        size_t end = json.find("\"", start);
        req.text = json.substr(start, end - start);
    }

    // 查找 "output_path"
    pos = json.find("\"output_path\"");
    if (pos != std::string::npos) {
        size_t start = json.find("\"", pos + 13) + 1;
        size_t end = json.find("\"", start);
        req.output_path = json.substr(start, end - start);
    }

    // 查找 "model_dir"
    pos = json.find("\"model_dir\"");
    if (pos != std::string::npos) {
        size_t start = json.find("\"", pos + 11) + 1;
        size_t end = json.find("\"", start);
        req.model_dir = json.substr(start, end - start);
    }

    // 查找 "rate"
    pos = json.find("\"rate\"");
    if (pos != std::string::npos) {
        size_t start = json.find(":", pos) + 1;
        size_t end = json.find_first_of(",}", start);
        req.rate = std::stod(json.substr(start, end - start));
    }

    // 查找 "speaker_id"
    pos = json.find("\"speaker_id\"");
    if (pos != std::string::npos) {
        size_t start = json.find(":", pos) + 1;
        size_t end = json.find_first_of(",}", start);
        req.speaker_id = std::stoi(json.substr(start, end - start));
    }

    return req;
}

// 生成JSON响应
std::string generateResponse(const TtsResponse& resp) {
    std::string json = "{";
    json += "\"success\":" + std::string(resp.success ? "true" : "false") + ",";
    json += "\"message\":\"" + resp.message + "\"";
    if (!resp.output_path.empty()) {
        json += ",\"output_path\":\"" + resp.output_path + "\"";
    }
    json += "}";
    return json;
}

// 保存WAV文件
bool saveWavFile(const std::vector<float>& samples, int32_t sample_rate, const std::string& path) {
    std::ofstream file(path, std::ios::binary);
    if (!file.is_open()) {
        return false;
    }

    // WAV文件头
    struct WavHeader {
        char riff[4] = {'R', 'I', 'F', 'F'};
        uint32_t file_size;
        char wave[4] = {'W', 'A', 'V', 'E'};
        char fmt[4] = {'f', 'm', 't', ' '};
        uint32_t fmt_size = 16;
        uint16_t audio_format = 1;  // PCM
        uint16_t num_channels = 1;  // Mono
        uint32_t sample_rate_hz;
        uint32_t byte_rate;
        uint16_t block_align;
        uint16_t bits_per_sample = 16;
        char data[4] = {'d', 'a', 't', 'a'};
        uint32_t data_size;
    } header;

    header.sample_rate_hz = sample_rate;
    header.byte_rate = sample_rate * 2;
    header.block_align = 2;
    header.data_size = static_cast<uint32_t>(samples.size() * 2);
    header.file_size = 36 + header.data_size;

    // 写入头
    file.write(reinterpret_cast<const char*>(&header), sizeof(header));

    // 转换float到int16并写入
    for (float sample : samples) {
        int16_t pcm = static_cast<int16_t>(sample * 32767.0f);
        file.write(reinterpret_cast<const char*>(&pcm), sizeof(pcm));
    }

    file.close();
    return true;
}

// 初始化TTS引擎
TtsResponse handleInit(const TtsRequest& req) {
    TtsResponse resp;

    try {
        OfflineTtsConfig config;

        // 构建模型路径
        std::string model_path = req.model_dir + "/model.onnx";
        std::string lexicon_path = req.model_dir + "/lexicon.txt";
        std::string tokens_path = req.model_dir + "/tokens.txt";
        std::string dict_dir = req.model_dir + "/dict";

        // VITS模型配置
        config.model.vits.model = model_path;
        config.model.vits.lexicon = lexicon_path;
        config.model.vits.tokens = tokens_path;

        // 只有当dict目录存在时才设置（部分模型不需要）
        #ifdef _WIN32
        struct _stat buffer;
        bool dict_exists = (_stat(dict_dir.c_str(), &buffer) == 0);
        #else
        struct stat buffer;
        bool dict_exists = (stat(dict_dir.c_str(), &buffer) == 0);
        #endif

        if (dict_exists) {
            config.model.vits.dict_dir = dict_dir;
        } else {
            config.model.vits.dict_dir = "";  // 不设置字典目录
        }

        // 其他配置
        config.model.num_threads = 2;
        config.model.debug = false;
        config.model.provider = "cpu";

        // 创建TTS实例
        OfflineTts tts = OfflineTts::Create(config);
        g_sample_rate = tts.SampleRate();
        g_tts = std::make_unique<OfflineTts>(std::move(tts));

        resp.success = true;
        resp.message = "TTS engine initialized successfully. Sample rate: " + std::to_string(g_sample_rate) + "Hz";

    } catch (const std::exception& e) {
        resp.success = false;
        resp.message = std::string("Initialization failed: ") + e.what();
    }

    return resp;
}

// 合成语音
TtsResponse handleSynthesize(const TtsRequest& req) {
    TtsResponse resp;

    if (!g_tts) {
        resp.success = false;
        resp.message = "TTS engine not initialized";
        return resp;
    }

    try {
        // 生成语音
        GeneratedAudio audio = g_tts->Generate(
            req.text,
            req.speaker_id,
            req.rate
        );

        if (audio.samples.empty()) {
            resp.success = false;
            resp.message = "Generated audio is empty";
            return resp;
        }

        // 保存WAV文件
        if (!saveWavFile(audio.samples, audio.sample_rate, req.output_path)) {
            resp.success = false;
            resp.message = "Failed to save WAV file";
            return resp;
        }

        resp.success = true;
        resp.message = "Synthesis successful. Samples: " + std::to_string(audio.samples.size());
        resp.output_path = req.output_path;

    } catch (const std::exception& e) {
        resp.success = false;
        resp.message = std::string("Synthesis failed: ") + e.what();
    }

    return resp;
}

// 主循环：读取stdin命令，执行，返回stdout响应
int main(int argc, char* argv[]) {
    // 设置二进制模式（Windows需要）
    #ifdef _WIN32
    _setmode(_fileno(stdin), _O_BINARY);
    _setmode(_fileno(stdout), _O_BINARY);
    #endif

    std::cerr << "Sherpa-ONNX TTS Service started (MSVC build)" << std::endl;

    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty()) continue;

        std::cerr << "Received request: " << line.substr(0, 100) << "..." << std::endl;

        try {
            // 解析请求
            TtsRequest req = parseRequest(line);

            // 处理命令
            TtsResponse resp;
            if (req.command == "init") {
                resp = handleInit(req);
            } else if (req.command == "synthesize") {
                resp = handleSynthesize(req);
            } else if (req.command == "stop") {
                resp.success = true;
                resp.message = "Service stopping";
                std::cout << generateResponse(resp) << std::endl;
                break;
            } else {
                resp.success = false;
                resp.message = "Unknown command: " + req.command;
            }

            // 发送响应
            std::string response = generateResponse(resp);
            std::cout << response << std::endl;
            std::cout.flush();

            std::cerr << "Sent response: " << response.substr(0, 100) << "..." << std::endl;

        } catch (const std::exception& e) {
            TtsResponse resp;
            resp.success = false;
            resp.message = std::string("Exception: ") + e.what();
            std::cout << generateResponse(resp) << std::endl;
            std::cout.flush();
        }
    }

    std::cerr << "Sherpa-ONNX TTS Service stopped" << std::endl;
    return 0;
}
