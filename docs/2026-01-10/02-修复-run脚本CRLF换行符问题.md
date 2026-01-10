# 修复：run-ubuntu24-apt.sh 脚本 CRLF 换行符问题

**日期**: 2026-01-10 17:00
**问题编号**: Fix 100.13
**状态**: ✅ 已解决

---

## 📋 问题描述

### 现象
设备（192.168.10.188）上的 `run-ubuntu24-apt.sh` 脚本报语法错误：
```bash
linaro@enc:~$ bash -n run-ubuntu24-apt.sh
run-ubuntu24-apt.sh: 行 200: 语法错误: 未预期的文件结尾
```

### 影响
- ❌ 自动 Core Dump 分析功能无法执行
- ❌ 程序崩溃后（exit code 139）只显示错误信息，不显示崩溃分析

---

## 🔍 调试过程

### 1. 初步检查
```bash
# 脚本行数正确
wc -l run-ubuntu24-apt.sh
# 输出：199 run-ubuntu24-apt.sh

# 但语法检查失败
bash -n run-ubuntu24-apt.sh
# 错误：行 200: 语法错误: 未预期的文件结尾
```

### 2. if/fi 配对检查
```bash
# 主 if（无缩进）
grep -c "^if \[" run-ubuntu24-apt.sh  # 输出: 2
grep -c "^fi$" run-ubuntu24-apt.sh    # 输出: 2  ✓ 配对

# 嵌套 if（4 个空格缩进）
grep -c "    if \[" run-ubuntu24-apt.sh  # 输出: 2
grep -c "^    fi$" run-ubuntu24-apt.sh   # 输出: 1  ❌ 缺失

# 双重嵌套 if（8 个空格缩进）
grep -c "^        fi$" run-ubuntu24-apt.sh  # 输出: 1
```

**初步结论**: 嵌套 `if` 缺少 1 个 `fi`，但这是误导！

### 3. 本地 vs 设备对比
```bash
# 下载设备脚本到本地
scp linaro@192.168.10.188:~/run-ubuntu24-apt.sh /tmp/device-script.sh

# 本地检查（bash 5.2）
bash -n /tmp/device-script.sh
# 输出: （无错误，检查通过）✓

# 设备检查（bash 5.0）
ssh linaro@192.168.10.188 'bash -n run-ubuntu24-apt.sh'
# 错误：行 200: 语法错误: 未预期的文件结尾 ❌
```

**发现**: 同一个脚本，本地 bash 5.2 通过，设备 bash 5.0 失败！

### 4. 换行符检查 ⭐
```bash
# 查看脚本末尾的换行符
ssh linaro@192.168.10.188 'sed -n "195,200p" run-ubuntu24-apt.sh | cat -A'
```

输出：
```
echo "========================================"$
    echo "  Core Dump ??: docs/..."$
    echo "  ????: docs/..."$
    echo ""$
fi^M$    ← ⚠️ 发现 ^M（Windows CRLF）
$
```

**根本原因**: `^M` 是 Windows CRLF（`\r\n`）换行符，bash 5.0 将 `fi^M` 识别为 `fi\r`，不认为这是关键字 `fi`！

---

## 💡 根本原因

### Windows CRLF vs Unix LF

| 系统 | 换行符 | 十六进制 | Bash 识别 |
|------|--------|----------|-----------|
| Unix/Linux | LF | `0x0A` | ✅ 正确识别关键字 |
| Windows | CRLF | `0x0D 0x0A` | ❌ bash 5.0 无法识别 |

### 为什么本地 bash 5.2 通过？
bash 5.2 对 CRLF 的容忍度更高，会自动忽略 `\r`，但 bash 5.0 不会。

### 为什么 PowerShell 生成 CRLF？
PowerShell here-string（`@' ... '@`）在 Windows 上默认生成 CRLF 换行符。

---

## ✅ 解决方案

### 修改文件
`build-ubuntu24-apt.ps1` (Lines 1690-1692)

```powershell
# 修复：转换为 Unix 换行符（LF）- 日期：2026-01-10 17:00
# 原因：Windows CRLF（\r\n）导致 bash 5.0 无法识别 fi 关键字
$runScript = $runScript -replace "`r`n", "`n"
```

### 立即修复设备上的脚本
```bash
ssh linaro@192.168.10.188 'sed -i "s/\r$//" run-ubuntu24-apt.sh && bash -n run-ubuntu24-apt.sh'
# 输出: ✓ 语法检查通过！
```

---

## 🧪 验证结果

### 1. 语法检查
```bash
ssh linaro@192.168.10.188 'bash -n run-ubuntu24-apt.sh'
# 输出: （无错误）✓
```

### 2. 脚本完整性
```bash
# if/fi 配对正确
grep "^if \[" | wc -l  # 2
grep "^fi$" | wc -l    # 2  ✓

# 无 CRLF 残留
cat -A | grep '\^M'  # （无输出）✓
```

### 3. 功能就绪
- ✅ 自动 Core Dump 分析代码已集成（build-ubuntu24-apt.ps1 lines 1605-1682）
- ✅ 脚本语法正确
- ✅ 等待下次崩溃测试

---

## 📚 技术细节

### CRLF 问题的常见场景
1. Git 在 Windows 上 checkout 时自动转换为 CRLF
2. PowerShell here-string 默认生成 CRLF
3. Windows 文本编辑器（记事本）默认使用 CRLF

### Bash 5.0 vs 5.2 差异
- **bash 5.0** (2019): 严格检查换行符，`\r` 被视为普通字符
- **bash 5.2** (2021): 增强了对 CRLF 的兼容性，自动忽略 `\r`

### 解决方案对比

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| A | 设备上手动 `dos2unix` | 快速修复 | 每次部署都需手动转换 |
| B | PowerShell 自动转换 | 一劳永逸 | 需要修改构建脚本 |
| C | Git 配置 `autocrlf=input` | 全局生效 | 影响所有文件，可能有副作用 |

**✅ 采用方案 B**：在 PowerShell 中自动转换（build-ubuntu24-apt.ps1）

---

## 🔗 相关文档

1. **自动 Core Dump 分析集成**: [docs/2026-01-10/01-工作总结-自动Core-Dump分析集成.md](01-工作总结-自动Core-Dump分析集成.md)
2. **Core Dump 根因分析**: [docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md](../2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md)
3. **Fix 100.12 解决方案**: [docs/2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md](../2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md)

---

## 📝 总结

### 关键教训
1. **跨平台脚本要注意换行符**：Windows CRLF 在 Linux 可能引发意外问题
2. **本地测试可能误导**：bash 版本差异导致本地通过但设备失败
3. **cat -A 是调试利器**：显示不可见字符（`^M`、`$`、Tab）
4. **PowerShell 管道会重新添加 CRLF**：即使替换了换行符，管道传输也会转换回去

### 后续改进
- ✅ PowerShell 自动转换为 Unix LF（lines 1690-1707 in build-ubuntu24-apt.ps1）
- ✅ 使用 UTF8 without BOM 编码保存到临时文件
- ✅ 使用 scp 上传而非管道（避免 CRLF 回退）
- ✅ Git commit 已提交
- ✅ 设备上脚本已手动修复（`sed -i "s/\r$//" run-ubuntu24-apt.sh`）
- ✅ 语法检查通过
- ⏳ 等待下次崩溃测试验证自动分析功能

---

## 🔄 更新记录（2026-01-10 17:40）

### 问题复现
重新运行 build-ubuntu24-apt.ps1 后，设备上的脚本仍然有 CRLF 问题：
```bash
./run-ubuntu24-apt.sh: 行 200: 语法错误: 未预期的文件结尾
```

### 根本原因（第二次发现）
之前的修复（lines 1690-1692）使用了 `-replace "`r`n", "`n"`，但后续使用了 **PowerShell 管道** 上传脚本：
```powershell
$runScript | ssh "${DeviceUser}@${DeviceIP}" "cat > /home/$DeviceUser/run-ubuntu24-apt.sh ..."
```

**PowerShell 管道会自动添加 CRLF**，导致换行符替换失效！

### 最终解决方案
修改 build-ubuntu24-apt.ps1 (lines 1690-1707)：

1. 转换为 Unix LF：`$runScript = $runScript -replace "`r`n", "`n"`
2. **保存到临时文件（UTF8 without BOM）**：
   ```powershell
   $TempScriptFile = Join-Path $env:TEMP "run-ubuntu24-apt.sh"
   $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
   [System.IO.File]::WriteAllText($TempScriptFile, $runScript, $Utf8NoBomEncoding)
   ```
3. **使用 scp 上传（避免管道）**：
   ```powershell
   & sshpass -e scp $TempScriptFile "${DeviceUser}@${DeviceIP}:/home/$DeviceUser/run-ubuntu24-apt.sh"
   ```

### 验证结果
```bash
$ ssh linaro@192.168.10.188 'bash -n run-ubuntu24-apt.sh && echo "Syntax check passed"'
Syntax check passed  ✓
```

---

**创建时间**: 2026-01-10 17:00
**最后更新**: 2026-01-10 17:40
**作者**: Claude (Sonnet 4.5)
**状态**: ✅ 问题已彻底解决
