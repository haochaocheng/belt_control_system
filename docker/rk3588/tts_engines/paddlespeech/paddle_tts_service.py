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
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] %(message)s',
    handlers=[logging.StreamHandler(sys.stderr)]
)

logger = logging.getLogger(__name__)

# 全局 TTS 对象
tts_executor = None
current_model = None


def initialize_paddlespeech(model_name):
    """
    初始化 PaddleSpeech TTS

    Args:
        model_name: 模型名称（如 "fastspeech2_csmsc"）

    Returns:
        bool: 是否成功
    """
    global tts_executor, current_model

    try:
        logger.info(f"🔧 初始化 PaddleSpeech - 模型: {model_name}")

        # 导入 PaddleSpeech
        from paddlespeech.cli.tts.infer import TTSExecutor

        # 创建 TTS 执行器
        tts_executor = TTSExecutor()

        # 解析模型名称
        # 格式: fastspeech2_csmsc
        parts = model_name.split('_')
        if len(parts) < 2:
            raise ValueError(f"无效的模型名称: {model_name}")

        am_name = parts[0]  # fastspeech2
        dataset = '_'.join(parts[1:])  # csmsc

        # 设置模型参数
        # PaddleSpeech 会自动下载模型
        logger.info(f"📦 加载模型 - AM: {am_name}, Dataset: {dataset}")

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

        # ✅ 2026-02-16 07:00: 修复 PaddleSpeech 调用参数
        # 原因：TTSExecutor.__call__() 不接受 am_dataset 和 voc_dataset 参数
        # 效果：使用正确的参数调用 PaddleSpeech
        # 旧代码：
        # parts = current_model.split('_')
        # am_name = parts[0]
        # dataset = '_'.join(parts[1:])
        # tts_executor(am=am_name, am_dataset=dataset, voc_dataset=voc_dataset, ...)

        # 解析模型名称
        # 模型格式：fastspeech2_csmsc, speedyspeech_csmsc, tacotron2_ljspeech 等
        parts = current_model.split('_')
        am_name = parts[0]  # 声学模型名称：fastspeech2, speedyspeech, tacotron2
        dataset = '_'.join(parts[1:])  # 数据集名称：csmsc, aishell3, ljspeech

        # 选择声码器
        # 中文模型使用 pwgan，英文模型使用 hifigan
        if 'csmsc' in dataset or 'aishell3' in dataset:
            voc_name = 'pwgan_csmsc'  # 完整的声码器名称
            lang = 'zh'
        else:
            voc_name = 'hifigan_ljspeech'  # 完整的声码器名称
            lang = 'en'

        # ✅ 2026-02-16 07:20: 修复 PaddleSpeech 调用参数（第二次）
        # 原因：TTSExecutor.__call__() 也不接受 speed 参数
        # 效果：移除 speed 参数，语速控制需要通过其他方式实现
        # 注意：PaddleSpeech 不支持运行时语速调整，只能在模型训练时固定
        # 旧代码：tts_executor(..., speed=speed)

        # 调用 PaddleSpeech 合成
        # 注意：不传递 am_dataset、voc_dataset 和 speed 参数
        tts_executor(
            text=text,
            output=output_path,
            am=am_name,
            voc=voc_name,
            lang=lang,
            spk_id=speaker_id
        )

        # 如果需要语速调整，可以使用 pydub 或 ffmpeg 后处理音频
        # 例如：ffmpeg -i input.wav -filter:a "atempo=1.5" output.wav

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
