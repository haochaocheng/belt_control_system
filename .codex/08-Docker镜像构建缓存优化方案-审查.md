# 08-Docker镜像构建缓存优化方案 审查结论

- 审查对象: `docs/2026-02-24/08-Docker镜像构建缓存优化方案.md`
- 审查时间: 2026-02-24
- 结论: 文档方向正确，但与当前工程实现存在关键偏差，需修订后再执行。

## 主要发现（按严重级别）

1. [阻断] 文档的核心前提与当前构建脚本不一致
- 文档描述: 修改 `requirements.txt` 会触发基础镜像重建并耗时 80+ 分钟（`docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:4`）。
- 当前实现: `build-ubuntu24-apt.ps1` 仅根据 `Dockerfile.ubuntu24-base` 哈希判断是否重建基础镜像（`build-ubuntu24-apt.ps1:1059`, `build-ubuntu24-apt.ps1:1068`, `build-ubuntu24-apt.ps1:1074`）。
- 影响: 仅修改 `docker/rk3588/tts_engines/paddlespeech/requirements.txt` 时，脚本可能直接跳过基础镜像构建，导致变更未生效，而不是“重建 80 分钟”。
- 建议: 将 `requirements.txt`（以及相关依赖文件）纳入基础镜像缓存键。

2. [高] BuildKit 缓存挂载方案与 `--no-cache-dir` 冲突
- 文档建议: `RUN --mount=type=cache,target=/root/.cache/pip ...`（`docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:258`）。
- 现状: 示例和现有 Dockerfile 均使用 `pip --no-cache-dir`（`docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:259`, `Dockerfile.ubuntu24-base:156`）。
- 影响: pip 不写入缓存目录，BuildKit cache mount 基本失效。
- 建议: 若要使用 BuildKit pip 缓存，需去掉 `--no-cache-dir`，并在镜像层结尾清理不必要缓存文件。

3. [高] 文档中的“短期方案 3.3”会加剧依赖漂移风险
- 文档建议: 不改 requirements，直接在 Dockerfile `RUN` 里追加包（`docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:330`）。
- 现状: 依赖已集中在 `docker/rk3588/tts_engines/paddlespeech/requirements.txt`（`docker/rk3588/tts_engines/paddlespeech/requirements.txt:9`）。
- 影响: 依赖来源分散（Dockerfile + requirements 文件），后续难以审计和复现。
- 建议: 保持单一依赖源（requirements/constraints），Dockerfile 只负责安装流程和缓存策略。

4. [中] `--cache-from` 建议不完整，实操收益可能低于预期
- 文档建议: `docker build --cache-from ...`（`docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:298`）。
- 现状: 当前脚本主要走本地 `docker build`（`build-ubuntu24-apt.ps1:1098`, `build-ubuntu24-apt.ps1:1565`），未配置 inline cache/export cache。
- 影响: 在跨机/CI 场景下，`--cache-from` 没有配套 cache metadata 时效果有限。
- 建议: 若要跨环境复用缓存，统一切到 `buildx` + `cache-to/cache-from`。

5. [中] 文档行号引用易过期
- 文档给出固定行号（如 `Dockerfile.ubuntu24-base` 155-160，`build-ubuntu24-apt.ps1` 1099-1122；见 `docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:25`, `docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:543`）。
- 影响: 后续文件变更后，定位会失真。
- 建议: 行号保留为辅助信息，同时给出稳定锚点（关键命令片段/函数名）。

6. [低] `docker commit` 作为常规缓解手段不利于可复现构建
- 文档建议: 通过 `docker commit` 保存中间层（`docs/2026-02-24/08-Docker镜像构建缓存优化方案.md:286`）。
- 风险: 镜像来源不可追溯，不适合团队长期维护。
- 建议: 仅用于临时救火，不作为标准流程。

## 建议修订方向（可直接落地）

1. 先修脚本触发条件（优先级最高）
- 在 `build-ubuntu24-apt.ps1` 的 Base 哈希里加入以下文件:
  - `docker/rk3588/tts_engines/paddlespeech/requirements.txt`
  - （如果后续引入）`requirements-extra.txt` / `constraints.txt`

2. 统一依赖策略
- 保持依赖定义单一来源（requirements + constraints）。
- 不建议长期采用“直接改 Dockerfile RUN 包列表”。

3. 再引入 BuildKit 缓存
- 启用 BuildKit / buildx。
- 调整 pip 参数，避免与 `--mount=type=cache` 冲突。

4. 文档文本修订
- 把“修改 requirements 会触发重建”改成“在当前脚本下可能不会触发重建，需先修复哈希策略”。
- 明确区分“本地缓存复用”和“跨机器缓存复用”的方案。

## 复核依据（关键文件）

- `docs/2026-02-24/08-Docker镜像构建缓存优化方案.md`
- `Dockerfile.ubuntu24-base:155`
- `Dockerfile.ubuntu24-base:156`
- `build-ubuntu24-apt.ps1:1059`
- `build-ubuntu24-apt.ps1:1068`
- `build-ubuntu24-apt.ps1:1098`
- `build-ubuntu24-apt.ps1:1565`
- `docker/rk3588/tts_engines/paddlespeech/requirements.txt:9`
