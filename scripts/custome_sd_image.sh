#!/bin/bash
set -eu

# ============================================================================
# FriendlyWrt RK3576: make room for the BTF-enabled kernel
# ============================================================================
#
# Enabling CONFIG_DEBUG_INFO_BTF=y adds an *allocated* .BTF section to the
# arm64 Image, so kernel.img grows by several MiB. The stock SD / eMMC layout
# only reserves 40 MiB (0x14000 sectors) for the kernel partition and the
# sd_update tool silently skips an image that does not fit:
#
#   copy part.5 start : 0x2400000 size 0x2800000 (0x2917814) more than
#   capacity 2800000 : ./friendlywrt25/kernel.img
#
# The raw image is still created and looks fine, but it has no kernel.
#
# This script rewrites the sd-fuse partition templates (and any parameter.txt
# that was already generated) so that the kernel partition is big enough and
# every partition that follows it is shifted by the same amount. Partition
# names, order and everything before the kernel partition stay untouched.
#
# Override the size (in 512-byte sectors) with KERNEL_PARTITION_SECTORS, e.g.:
#   KERNEL_PARTITION_SECTORS=$((0x20000)) ./scripts/custome_sd_image.sh

KERNEL_PARTITION_SECTORS=${KERNEL_PARTITION_SECTORS:-$((0x20000))}  # 64 MiB
KERNEL_PARTITION_MARGIN=${KERNEL_PARTITION_MARGIN:-$((0x4000))}     # 8 MiB
SDFUSE_DIR=${SDFUSE_DIR:-scripts/sd-fuse}
KERNEL_IMG=${KERNEL_IMG:-kernel/kernel.img}

# Partition sizes/addresses are kept aligned to 4 MiB (0x2000 sectors).
ALIGNMENT=$((0x2000))

# ---------------------------------------------------------------
# Grow the kernel partition when the built kernel needs more room
# ---------------------------------------------------------------
if [ -f "${KERNEL_IMG}" ]; then
    kernel_img_size=$(stat -c '%s' "${KERNEL_IMG}")
    needed_sectors=$(( (kernel_img_size + 511) / 512 + KERNEL_PARTITION_MARGIN ))
    needed_sectors=$(( (needed_sectors + ALIGNMENT - 1) / ALIGNMENT * ALIGNMENT ))
    echo "kernel.img size: ${kernel_img_size} bytes (needs $((needed_sectors / 2048)) MiB with margin)"
    if [ "${needed_sectors}" -gt "${KERNEL_PARTITION_SECTORS}" ]; then
        KERNEL_PARTITION_SECTORS=${needed_sectors}
    fi
fi

# ---------------------------------------------------------------
# Rewrite the "CMDLINE: mtdparts=..." line of a parameter file
# ---------------------------------------------------------------
rewrite_parameter() {
    local file=$1
    [ -f "${file}" ] || return 0

    local line
    line=$(grep -m1 -E '^CMDLINE:.*rk29xxnand:' "${file}" || true)
    [ -n "${line}" ] || return 0

    local head=${line%%rk29xxnand:*}
    local list=${line#*rk29xxnand:}

    local -a parts=()
    local -a out=()
    local IFS=','
    read -r -a parts <<< "${list}"

    local part size addr name base old_size delta=0 resized=0
    for part in "${parts[@]}"; do
        if [[ ${part} =~ ^([^@]+)@([^()]+)\((.*)\)$ ]]; then
            size=${BASH_REMATCH[1]}
            addr=${BASH_REMATCH[2]}
            name=${BASH_REMATCH[3]}
            base=${name%%:*}

            if [ "${base}" = "kernel" ]; then
                old_size=$((size))
                if [ "${old_size}" -ge "${KERNEL_PARTITION_SECTORS}" ]; then
                    return 0
                fi
                delta=$((KERNEL_PARTITION_SECTORS - old_size))
                size=$(printf '0x%08x' "${KERNEL_PARTITION_SECTORS}")
                resized=1
            elif [ "${resized}" -eq 1 ] && [[ ${addr} =~ ^0x[0-9a-fA-F]+$ ]]; then
                addr=$(printf '0x%08x' $((addr + delta)))
            fi
            part="${size}@${addr}(${name})"
        fi
        out+=("${part}")
    done

    [ "${resized}" -eq 1 ] || return 0

    local new_list new_line mode tmp
    new_list=$(IFS=','; echo "${out[*]}")
    new_line="${head}rk29xxnand:${new_list}"

    mode=$(stat -c '%a' "${file}")
    tmp=$(mktemp)
    awk -v new="${new_line}" '/^CMDLINE:/ { print new; next } { print }' "${file}" > "${tmp}"
    chmod "${mode}" "${tmp}"
    mv "${tmp}" "${file}"

    echo "  ${file}"
    echo "    old: rk29xxnand:${list}"
    echo "    new: rk29xxnand:${new_list}"
}

# ---------------------------------------------------------------

if [ ! -d "${SDFUSE_DIR}/prebuilt" ]; then
    echo "ERROR: ${SDFUSE_DIR}/prebuilt not found, run this from the project directory." >&2
    exit 1
fi

echo "=== Enlarging kernel partition to $((KERNEL_PARTITION_SECTORS * 512 / 1024 / 1024)) MiB"
for parameter in \
    "${SDFUSE_DIR}/prebuilt/parameter-opt.template" \
    "${SDFUSE_DIR}/prebuilt/parameter.template" \
    "${SDFUSE_DIR}"/*/parameter.txt
do
    rewrite_parameter "${parameter}"
done

echo "=== Kernel partition layout updated"
