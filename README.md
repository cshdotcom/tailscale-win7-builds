# Tailscale 最新源码 → Windows 7 兼容版（实测编译通过）

## 实测结论

| 项目 | 结果 |
|---|---|
| 源码 | Tailscale main 分支，commit `566f89e0`（2026-10-24） |
| 官方 Go 1.27.3 交叉编译 | ✅ 0 错误，但 PE SubsystemVersion = **10.0**，Win7 加载器拒绝启动 |
| go-legacy-win7（Go 1.27.2 补丁版）交叉编译 | ✅ 0 错误，PE SubsystemVersion = **6.1**，Win7 可启动 |

**"编译无错误" 不等于 "Win7 能跑"**。卡点不在 Tailscale 代码（其官方 manifest 仍声明支持 Windows 7），而在 Go 工具链：Go 1.21+ 把 PE 头最低版本写死为 10.0。用 `thongtech/go-legacy-win7` 工具链即可解决。

## 交付文件

- `tailscaled-win7-legacy.exe` —— 守护进程（服务端，BDS 联机场景用这个）
- `tailscale-win7-legacy.exe` —— CLI（登录、up、status 等）
- 均为 Windows amd64，PE 声明 Windows 7（6.1）

## 编译复现命令（Linux 交叉编译）

```bash
# 1. 官方 Go 1.27.3（引导 + 对比用）
curl -LO https://mirrors.aliyun.com/golang/go1.27.3.linux-amd64.tar.gz
tar -C /tmp -xzf go1.27.3.linux-amd64.tar.gz

# 2. 克隆 Tailscale（最新）
git clone --depth=1 https://github.com/tailscale/tailscale.git /tmp/tailscale-src
# go.mod 里 go 1.27.3 降为 go 1.27（go-legacy-win7 是 1.27.2）

# 3. 克隆并构建 go-legacy-win7（main 分支 = go1.27.2）
git clone --depth=1 https://github.com/thongtech/go-legacy-win7.git /tmp/go-legacy-win7
cd /tmp/go-legacy-win7/src
GOROOT_BOOTSTRAP=/tmp/go1.27.3/go ./make.bash

# 4. 交叉编译（关键：GOTOOLCHAIN=local 防止自动回退官方工具链）
cd /tmp/tailscale-src
export PATH=/tmp/go-legacy-win7/bin:$PATH GOROOT=/tmp/go-legacy-win7
export GOOS=windows GOARCH=amd64 CGO_ENABLED=0 GOTOOLCHAIN=local
go build -o tailscaled.exe ./cmd/tailscaled
go build -o tailscale.exe ./cmd/tailscale
```

## Windows 7 上使用

1. 系统要求：Windows 7 SP1 x64（go-legacy-win7 实测支持 7600 无补丁，含无 KB2533623 环境）
2. 以管理员身份运行 CMD，先装服务：
   ```
   tailscaled.exe install-system-daemon
   ```
   或前台运行：`tailscaled.exe --state=mem:`
3. 登录：`tailscale.exe up`
4. 虚拟网卡依赖 wintun 驱动（tailscaled 自动下载安装），Win7 x64 受支持；如驱动安装失败需手动确认 wintun 版本

## 注意

- 这是编译实验产物，未在真实 Win7 上跑过完整登录/组网；wintun 驱动加载、WFP 防火墙规则为运行时环节，需在 Win7 实测
- Tailscale 官方不支持 Win7（最低 Win10），本方案为社区补丁续命，无官方支持
- go-legacy-win7 修复点（摘录）：PE 最低版本 6.1、无 KB2533623 的 DLL 加载、无 ProcessPrng 回退 RtlGenRandom、Win7 无 SP1 的 WSA_FLAG_NO_HANDLE_INHERIT、完成端口兼容、控制台句柄等

## Win7 真机测试步骤

在 Windows 7 SP1 x64 上：

1. 下载本仓库 `tailscaled-win7-legacy.exe`、`tailscale-win7-legacy.exe`、`test-login-win7.bat` 到同一文件夹
2. 双击 `test-login-win7.bat`（如权限不足，右键"以管理员身份运行"）
3. 脚本会自动：启动 tailscaled → 执行 `tailscale up` → 打印登录链接 → 登录后 `tailscale status` 校验

判定标准：
- `tailscale status` 显示机器名 + `100.x.x.x` 地址 = 登录成功、组网正常
- 报"不是有效的 Win32 应用程序" = 加载器仍拒绝（理论上不会，PE 已声明 6.1）
- 闪退/找不到入口点 = 运行时 API 缺失（go-legacy-win7 已覆盖已知项，如仍有请反馈）

已知运行时依赖：wintun 驱动（tailscaled 首次启动自动下载安装，Win7 x64 受支持）。

## GitHub Actions 实测结果（2026-10-25，windows-latest runner）

Workflow：`.github/workflows/test-win7-build.yml`（push / 手动触发）

| 步骤 | 结果 |
|---|---|
| `tailscale version` | ✅ `1.105.0-dev20261025` / go1.27.2（产物可执行） |
| 启动 tailscaled（userspace 模式） | ✅ PID 存活，无崩溃 |
| `tailscale status` | ✅ `Logged out.`（CLI↔守护进程通信正常） |
| `tailscale up`（无 key） | ✅ 获取到 `https://login.tailscale.com/a/...`（控制平面连接正常，登录流程可发起） |
| `tailscale up --authkey` + `ping` | ⏳ 需要仓库 Secret `TS_AUTHKEY` 才执行 |

启用真实账号登录测试：Tailscale 控制台 → Settings → Keys → 生成 Auth Key → 填入仓库
`Settings → Secrets and variables → Actions → TS_AUTHKEY`，再重新运行 workflow。
