#!/bin/bash

set -eu

# 强制编译进内核 (=y)，严禁使用 =m
CONFIGS=(
    # eBPF 核心与 JIT
    "CONFIG_BPF=y"
    "CONFIG_BPF_SYSCALL=y"
    "CONFIG_BPF_JIT=y"
    "CONFIG_BPF_JIT_ALWAYS_ON=y"

    # Cgroup 与 eBPF 结合 (dae 必需)
    "CONFIG_CGROUPS=y"
    "CONFIG_CGROUP_BPF=y"

    # Kprobes & Tracing
    "CONFIG_KPROBES=y"
    "CONFIG_KPROBE_EVENTS=y"
    "CONFIG_BPF_EVENTS=y"

    # 网络 TC 与 eBPF (必须全 =y)
    "CONFIG_NET_INGRESS=y"
    "CONFIG_NET_EGRESS=y"
    "CONFIG_NET_SCH_INGRESS=y"
    "CONFIG_NET_CLS_BPF=y"
    "CONFIG_NET_CLS_ACT=y"
    "CONFIG_BPF_STREAM_PARSER=y"

    # BTF 调试信息支持 (去除 DWARF5，由系统工具链自动适配)
    "CONFIG_DEBUG_INFO=y"
    "CONFIG_DEBUG_INFO_BTF=y"

    # 允许 /proc/config.gz 查询
    "CONFIG_IKCONFIG=y"
    "CONFIG_IKCONFIG_PROC=y"
)

source .current_config.mk

KCFG=kernel/arch/arm64/configs/$(awk '{print $1}' <<< "$TARGET_KERNEL_CONFIG")

echo "Using kernel config: $KCFG"

# 1. 注入核心选项
for CONFIG in "${CONFIGS[@]}"; do
    KEY="${CONFIG%%=*}"

    sed -i \
        -e "/^${KEY}=.*/d" \
        -e "/^# ${KEY} is not set$/d" \
        "$KCFG"

    echo "$CONFIG" >> "$KCFG"
done

# 2. 明确禁用引发内核镜像体积暴增/超出的选项
DISABLE_CONFIGS=(
    "CONFIG_DEBUG_INFO_REDUCED"
    "CONFIG_DEBUG_INFO_DWARF5"
    "CONFIG_DEBUG_INFO_DWARF4"
)

for KEY in "${DISABLE_CONFIGS[@]}"; do
    sed -i \
        -e "/^${KEY}=.*/d" \
        -e "/^# ${KEY} is not set$/d" \
        "$KCFG"
    echo "# ${KEY} is not set" >> "$KCFG"
done

echo
echo "=== dae kernel config fragment updated successfully ==="
