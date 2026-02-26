#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PaddleSpeech TTS 服务进程

通过 stdin/stdout 与 C++ 进程通信，使用 JSON 格式

✅ 2026-02-13 [Phase 7.46.3]: 创建 PaddleSpeech 服务进程
"""

import sys
import json
import os
import logging
from pathlib import Path

# 配置日志
# ✅ 2026-02-22 00:20: 禁用日志缓冲，确保实时输出
# 原因：Python 的 stderr 默认有缓冲，导致日志延迟输出
# 解决：设置 stream 为无缓冲模式
import io
stderr_unbuffered = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', line_buffering=True)
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] %(message)s',
    handlers=[logging.StreamHandler(stderr_unbuffered)]
)

logger = logging.getLogger(__name__)

# ✅ 2026-02-26 11:00 [Phase 7.47.7]: 检查并设置 PADDLESPEECH_HOME 环境变量
# 原因：确保 PaddleSpeech 使用本地模型，避免网络下载
# ✅ 2026-02-26 12:30 [Phase 7.47.8]: 修复路径（移除多余的 models 层级）
# ✅ 2026-02-26 14:30 [Phase 7.47.10]: 恢复正确路径（设备实际路径是 /home/linaro/belt-control-data/models/tts_models/）
paddlespeech_home = os.environ.get('PADDLESPEECH_HOME', '')
logger.info(f"📂 PADDLESPEECH_HOME 环境变量: '{paddlespeech_home}'")

if not paddlespeech_home:
    # 自动检测模型路径
    possible_paths = [
        '/home/linaro/belt-control-data/models/tts_models/paddlespeech',
        '/home/pi/belt-control-data/models/tts_models/paddlespeech',
        '/app/tts_models/paddlespeech'
    ]
    for path in possible_paths:
        if os.path.exists(os.path.join(path, 'models')):
            paddlespeech_home = path
            os.environ['PADDLESPEECH_HOME'] = paddlespeech_home
            logger.info(f"✅ 自动设置 PADDLESPEECH_HOME={paddlespeech_home}")
            break
    if not paddlespeech_home:
        logger.warning("⚠️ 未找到本地模型路径，PaddleSpeech 可能会尝试下载模型")
else:
    logger.info(f"✅ 使用环境变量 PADDLESPEECH_HOME={paddlespeech_home}")

# 全局 TTS 对象
tts_executor = None
current_model = None


def initialize_paddlespeech(model_name):
    """
    初始化 PaddleSpeech TTS

    Args:
        model_name: 模型路径或名称
                   如: "/home/pi/.../fastspeech2_csmsc" 或 "fastspeech2_csmsc"

    Returns:
        bool: 是否成功
    """
    global tts_executor, current_model

    try:
        logger.info(f"🔧 初始化 PaddleSpeech - 模型: {model_name}")

        # ✅ 2026-02-21 21:30: 从路径中提取模型名称
        # 原因：PaddleSpeech 期望预定义模型名称，不是文件路径
        # 效果：支持路径和名称两种输入方式

        # 如果是路径，提取最后一部分作为模型名称
        if '/' in model_name or '\\' in model_name:
            model_name = os.path.basename(model_name)
            logger.info(f"📝 提取模型名称: {model_name}")

        # 导入 PaddleSpeech
        from paddlespeech.cli.tts.infer import TTSExecutor

        # 创建 TTS 执行器
        tts_executor = TTSExecutor()

        # 保存模型名称（不带语言后缀）
        current_model = model_name

        logger.info("✅ PaddleSpeech 初始化成功")
        return True

    except Exception as e:
        logger.error(f"❌ 初始化失败: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        return False


def synthesize_speech(text, output_path, speaker_id=0, speed=1.0, volume=0.8):
    """
    合成语音

    Args:
        text: 要合成的文本
        output_path: 输出文件路径
        speaker_id: 说话人ID
        speed: 语速（0.5-2.0）
        volume: 音量（0.0-1.0）

    Returns:
        bool: 是否成功
    """
    global tts_executor, current_model

    if tts_executor is None:
        logger.error("❌ TTS 未初始化")
        return False

    try:
        logger.info(f"🎙️ 合成语音 - 文本: {text}, 说话人ID: {speaker_id}, 语速: {speed}")

        # ✅ 2026-02-21 22:30: 使用预定义模型名称（带语言后缀）
        # 原因：PaddleSpeech 期望 'fastspeech2_csmsc-zh' 而不是路径或不带后缀的名称
        # 效果：让 PaddleSpeech 使用预定义模型（自动下载）
        #
        # 参考：https://github.com/PaddlePaddle/PaddleSpeech/blob/develop/paddlespeech/cli/tts/infer.py
        # 支持的参数：text, am, voc, lang, spk_id, output, device, use_onnx, cpu_threads, fs
        # 不支持的参数：am_dataset, voc_dataset, speed
        #
        # ⚠️ 2026-02-21 22:30: 修复重复添加语言后缀的问题
        # 问题：如果 current_model 已经包含 -zh/-en/-mix 后缀，会重复添加
        # 例如：fastspeech2_csmsc-zh → fastspeech2_csmsc-zh-zh（错误）
        # 解决：先检查是否已经包含后缀

        # ✅ 2026-02-22 01:45: 修复重复添加语言后缀的问题
        # 根本原因：PaddleSpeech 库会根据 lang 参数自动添加后缀
        # 例如：am='fastspeech2_csmsc' + lang='zh' → PaddleSpeech 内部使用 'fastspeech2_csmsc-zh'
        # 所以我们不需要手动添加后缀，直接使用模型名称即可

        print(f"[DEBUG] 🔍 current_model = '{current_model}'", file=sys.stderr, flush=True)

        # 如果模型名称已经包含后缀，需要去掉（因为 PaddleSpeech 会自动添加）
        am_name = current_model
        if current_model.endswith('-zh'):
            am_name = current_model[:-3]  # 去掉 '-zh'
            print(f"[DEBUG] 📝 去掉语言后缀: {current_model} → {am_name}", file=sys.stderr, flush=True)
        elif current_model.endswith('-en'):
            am_name = current_model[:-3]  # 去掉 '-en'
            print(f"[DEBUG] 📝 去掉语言后缀: {current_model} → {am_name}", file=sys.stderr, flush=True)
        elif current_model.endswith('-mix'):
            am_name = current_model[:-4]  # 去掉 '-mix'
            print(f"[DEBUG] 📝 去掉语言后缀: {current_model} → {am_name}", file=sys.stderr, flush=True)
        elif current_model.endswith('-canton'):
            am_name = current_model[:-7]  # 去掉 '-canton'
            print(f"[DEBUG] 📝 去掉语言后缀: {current_model} → {am_name}", file=sys.stderr, flush=True)
        else:
            print(f"[DEBUG] 📝 使用原始模型名称: {am_name}", file=sys.stderr, flush=True)

        # 根据模型名称选择声码器和语言
        # ✅ 2026-02-22 03:50 [Phase 7.46.32]: 修复 aishell3 声码器配置
        # ✅ 2026-02-22 05:25 [Phase 7.46.33]: 使用 hifigan_aishell3 声码器
        # 原因：下载的是 hifigan_aishell3_ckpt_0.2.0.zip，不是 pwgan
        # 效果：aishell3 多说话人模型可以正常合成
        if 'aishell3' in am_name:
            voc_name = 'hifigan_aishell3'
            lang = 'zh'
        elif 'csmsc' in am_name:
            voc_name = 'pwgan_csmsc'
            lang = 'zh'
        elif 'canton' in am_name:
            voc_name = 'pwgan_csmsc'
            lang = 'canton'
        elif 'ljspeech' in am_name:
            voc_name = 'hifigan_ljspeech'
            lang = 'en'
        elif 'vctk' in am_name:
            voc_name = 'hifigan_ljspeech'
            lang = 'en'
        elif 'mix' in am_name:
            voc_name = 'pwgan_csmsc'
            lang = 'mix'
        else:
            # 默认使用中文
            voc_name = 'pwgan_csmsc'
            lang = 'zh'

        logger.info(f"📦 使用模型: am={am_name}, voc={voc_name}, lang={lang}")

        # 调用 PaddleSpeech 合成
        # 使用预定义模型名称（带语言后缀）
        tts_executor(
            text=text,
            output=output_path,
            am=am_name,        # 预定义模型名称，如 'fastspeech2_csmsc-zh'
            voc=voc_name,      # 预定义声码器名称，如 'pwgan_csmsc'
            lang=lang,         # 语言：'zh' 或 'en'
            spk_id=speaker_id  # 说话人ID
        )

        # 检查输出文件
        if not os.path.exists(output_path):
            logger.error(f"❌ 输出文件不存在: {output_path}")
            return False

        # 调整音量（使用 pydub）
        if volume != 1.0:
            try:
                from pydub import AudioSegment
                audio = AudioSegment.from_wav(output_path)
                # 转换音量（0.0-1.0 -> dB）
                volume_db = 20 * (volume - 1)  # 0.8 -> -4dB, 1.0 -> 0dB
                audio = audio + volume_db
                audio.export(output_path, format='wav')
                logger.info(f"🔊 调整音量: {volume} ({volume_db:.1f}dB)")
            except ImportError:
                logger.warning("⚠️ pydub 未安装，跳过音量调整")

        logger.info(f"✅ 合成成功: {output_path}")
        return True

    except Exception as e:
        logger.error(f"❌ 合成失败: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        return False


def handle_command(command_json):
    """
    处理命令

    Args:
        command_json: JSON 命令对象

    Returns:
        dict: JSON 响应对象
    """
    command = command_json.get('command')

    if command == 'initialize':
        model = command_json.get('model', 'fastspeech2_csmsc')
        success = initialize_paddlespeech(model)
        return {
            'status': 'success' if success else 'error',
            'error': None if success else '初始化失败'
        }

    elif command == 'synthesize':
        text = command_json.get('text')
        output_path = command_json.get('output_path')
        speaker_id = command_json.get('speaker_id', 0)
        speed = command_json.get('speed', 1.0)
        volume = command_json.get('volume', 0.8)

        success = synthesize_speech(text, output_path, speaker_id, speed, volume)
        return {
            'status': 'success' if success else 'error',
            'error': None if success else '合成失败'
        }

    elif command == 'stop':
        # PaddleSpeech 不支持中途停止，直接返回成功
        return {'status': 'success'}

    elif command == 'shutdown':
        logger.info("🔴 收到关闭命令")
        return {'status': 'success'}

    else:
        logger.warning(f"⚠️ 未知命令: {command}")
        return {
            'status': 'error',
            'error': f'未知命令: {command}'
        }


def main():
    """
    主循环：读取 stdin 命令，处理后输出到 stdout
    """
    logger.info("🚀 PaddleSpeech TTS 服务启动")
    logger.info(f"📂 工作目录: {os.getcwd()}")
    logger.info(f"🐍 Python 版本: {sys.version}")

    try:
        while True:
            # 读取一行 JSON 命令
            line = sys.stdin.readline()
            if not line:
                logger.info("📭 stdin 关闭，退出服务")
                break

            line = line.strip()
            if not line:
                continue

            try:
                # 解析 JSON 命令
                command_json = json.loads(line)
                logger.info(f"📨 收到命令: {command_json.get('command')}")

                # 处理命令
                response = handle_command(command_json)

                # 输出 JSON 响应
                response_str = json.dumps(response, ensure_ascii=False)
                print(response_str, flush=True)
                logger.info(f"📤 发送响应: {response['status']}")

                # 如果是关闭命令，退出循环
                if command_json.get('command') == 'shutdown':
                    break

            except json.JSONDecodeError as e:
                logger.error(f"❌ JSON 解析错误: {e}")
                error_response = {
                    'status': 'error',
                    'error': f'JSON 解析错误: {str(e)}'
                }
                print(json.dumps(error_response), flush=True)
            except Exception as e:
                logger.error(f"❌ 处理命令时出错: {e}")
                import traceback
                traceback.print_exc(file=sys.stderr)
                error_response = {
                    'status': 'error',
                    'error': str(e)
                }
                print(json.dumps(error_response), flush=True)

    except KeyboardInterrupt:
        logger.info("⚠️ 收到中断信号")
    except Exception as e:
        logger.error(f"❌ 服务异常: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
    finally:
        logger.info("🔴 PaddleSpeech TTS 服务关闭")


if __name__ == '__main__':
    main()
