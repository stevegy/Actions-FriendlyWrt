#!/bin/bash

set -eu

# ================================================================
# DAE eBPF Kernel Config — FriendlyWRT RK3576 (kernel 6.1)
# ================================================================

CONFIGS=(
    # --- eBPF core & JIT ---
    "CONFIG_BPF=y"
    "CONFIG_BPF_SYSCALL=y"
    "CONFIG_BPF_JIT=y"
    "CONFIG_BPF_JIT_ALWAYS_ON=y"

    # --- Cgroup + eBPF ---
    "CONFIG_CGROUPS=y"
    "CONFIG_CGROUP_BPF=y"

    # --- Kprobes & BPF tracing ---
    "CONFIG_KPROBES=y"
    "CONFIG_KPROBE_EVENTS=y"
    "CONFIG_BPF_EVENTS=y"

    # --- TC / network eBPF hooks ---
    "CONFIG_NET_INGRESS=y"
    "CONFIG_NET_EGRESS=y"
    "CONFIG_NET_SCH_INGRESS=y"
    "CONFIG_NET_CLS_BPF=y"
    "CONFIG_NET_CLS_ACT=y"
    "CONFIG_BPF_STREAM_PARSER=y"

    # --- BTF / debug info (内核 6.1 标准兼容模式) ---
    "CONFIG_DEBUG_INFO=y"
    "CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=y"
    "CONFIG_DEBUG_INFO_BTF=y"

    # --- Runtime config inspection ---
    "CONFIG_IKCONFIG=y"
    "CONFIG_IKCONFIG_PROC=y"
)

DISABLE_CONFIGS=(
    "CONFIG_DEBUG_INFO_NONE"             # 必须置顶去除
    "CONFIG_DEBUG_INFO_REDUCED"          # pahole 无法解析 REDUCED，会导致 BTF 生成失败
    "CONFIG_DEBUG_INFO_SPLIT"            # ⚠️ 绝对不能开启！开启后 pahole 找不到 .dwo 导致 BTF 消失
    "CONFIG_DEBUG_INFO_DWARF5"           # 避免 DWARF5 造成膨胀
    "CONFIG_DEBUG_INFO_DWARF4"
    "CONFIG_DEBUG_INFO_COMPRESSED_ZLIB"
    "CONFIG_DEBUG_INFO_COMPRESSED_ZSTD"
)

# ================================================================

source .current_config.mk

KCFG=kernel/arch/arm64/configs/$(awk '{print $1}' <<< "$TARGET_KERNEL_CONFIG")

echo "Using kernel config: $KCFG"
echo

# ---- Step 1: disable blocking options -------------------------
echo "[1/2] Disabling incompatible options..."
for KEY in "${DISABLE_CONFIGS[@]}"; do
    sed -i \
        -e "/^${KEY}=.*/d" \
        -e "/^# ${KEY} is not set$/d" \
        "$KCFG"
    echo "# ${KEY} is not set" >> "$KCFG"
done

echo
# ---- Step 2: inject required options --------------------------
echo "[2/2] Injecting DAE eBPF options..."
for CONFIG in "${CONFIGS[@]}"; do
    KEY="${CONFIG%%=*}"
    sed -i \
        -e "/^${KEY}=.*/d" \
        -e "/^# ${KEY} is not set$/d" \
        "$KCFG"
    echo "$CONFIG" >> "$KCFG"
done

echo
echo "=================================================="
echo " DAE eBPF kernel config applied successfully"
echo "=================================================="
