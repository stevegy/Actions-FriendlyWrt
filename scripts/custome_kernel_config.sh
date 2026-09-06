#!/bin/bash

set -eu

CONFIGS=(
    "CONFIG_BPF=y"
    "CONFIG_BPF_SYSCALL=y"
    "CONFIG_BPF_JIT=y"

    "CONFIG_CGROUPS=y"
    "CONFIG_KPROBES=y"

    "CONFIG_NET_INGRESS=y"
    "CONFIG_NET_EGRESS=y"
    "CONFIG_NET_SCH_INGRESS=m"
    "CONFIG_NET_CLS_BPF=m"
    "CONFIG_NET_CLS_ACT=y"

    "CONFIG_BPF_STREAM_PARSER=y"

    "CONFIG_DEBUG_INFO=y"
    "CONFIG_DEBUG_INFO_DWARF5=y"
    "CONFIG_DEBUG_INFO_BTF=y"

    "CONFIG_KPROBE_EVENTS=y"
    "CONFIG_BPF_EVENTS=y"
)

source .current_config.mk

KCFG=kernel/arch/arm64/configs/$(awk '{print $1}' <<< "$TARGET_KERNEL_CONFIG")

echo "Using kernel config: $KCFG"

for CONFIG in "${CONFIGS[@]}"; do
    KEY="${CONFIG%%=*}"

    sed -i \
        -e "/^${KEY}=.*/d" \
        -e "/^# ${KEY} is not set$/d" \
        "$KCFG"

    echo "$CONFIG" >> "$KCFG"
done

# Explicitly disable DEBUG_INFO_REDUCED.
sed -i \
    -e '/^CONFIG_DEBUG_INFO_REDUCED=.*/d' \
    -e '/^# CONFIG_DEBUG_INFO_REDUCED is not set$/d' \
    "$KCFG"

echo '# CONFIG_DEBUG_INFO_REDUCED is not set' >> "$KCFG"

echo
echo "=== dae kernel config fragment ==="
grep -E \
    'CONFIG_(BPF|BPF_SYSCALL|BPF_JIT|CGROUPS|KPROBES|NET_INGRESS|NET_EGRESS|NET_SCH_INGRESS|NET_CLS_BPF|NET_CLS_ACT|BPF_STREAM_PARSER|DEBUG_INFO|DEBUG_INFO_BTF|DEBUG_INFO_REDUCED|KPROBE_EVENTS|BPF_EVENTS)' \
    "$KCFG" || true
