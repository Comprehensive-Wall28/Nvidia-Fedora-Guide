#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR="${HOME}/.cache/install-nvidia-fedora"
PHASE_FILE="${STATE_DIR}/phase"
KEYS_REPO_DIR="${STATE_DIR}/silverblue-akmods-keys"

mkdir -p "$STATE_DIR"

log() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf '\nWARNING: %s\n' "$*" >&2
}

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required command not found: $1"
}

sudo_available() {
    sudo -n true >/dev/null 2>&1 || sudo -v
}

get_phase() {
    if [[ -f "$PHASE_FILE" ]]; then
        cat "$PHASE_FILE"
    else
        echo "prepare"
    fi
}

set_phase() {
    printf '%s\n' "$1" > "$PHASE_FILE"
}

reboot_now() {
    log "Rebooting into the new Fedora deployment."
    systemctl reboot
}

detect_system() {
    source /etc/os-release

    [[ "${ID:-}" == "fedora" ]] ||
        die "This script requires Fedora."

    command -v rpm-ostree >/dev/null 2>&1 ||
        die "rpm-ostree was not found."

    if [[ ! -e /run/ostree-booted ]]; then
        die "This does not appear to be a Fedora Atomic/rpm-ostree system."
    fi

    FEDORA_VERSION="$(rpm -E %fedora)"

    [[ "$FEDORA_VERSION" =~ ^[0-9]+$ ]] ||
        die "Could not determine the Fedora release."

    FEDORA_VARIANT="${VARIANT_ID:-${VARIANT:-unknown}}"

    log "Detected Fedora Atomic variant: ${FEDORA_VARIANT}"
    log "Detected Fedora release: ${FEDORA_VERSION}"
}

detect_secure_boot() {
    SECURE_BOOT="unknown"

    if command -v mokutil >/dev/null 2>&1; then
        if mokutil --sb-state 2>/dev/null | grep -qi enabled; then
            SECURE_BOOT="enabled"
            warn "Secure Boot is enabled. Secure Boot enrollment is intentionally omitted."
            warn "The NVIDIA modules may not load until you handle module signing separately."
            # Enable script progress once Secure Boot support is estabilished.
            die "At this time install script doesn't support automation for Secure Boot enabled systems."
        elif mokutil --sb-state 2>/dev/null | grep -qi disabled; then
            SECURE_BOOT="disabled"
        fi
    fi
}

detect_cpu() {
    CPU_VENDOR="unknown"

    if grep -qi 'GenuineIntel' /proc/cpuinfo; then
        CPU_VENDOR="Intel"
    elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
        CPU_VENDOR="AMD"
    fi

    log "Detected CPU vendor: ${CPU_VENDOR}"

    if [[ "$CPU_VENDOR" == "Intel" ]]; then
        IGPU_DRIVER="i915"
    elif [[ "$CPU_VENDOR" == "AMD" ]]; then
        IGPU_DRIVER="amdgpu"
    else
        IGPU_DRIVER=""
    fi
}

detect_laptop() {
    IS_LAPTOP="no"

    local chassis_type=""
    if [[ -r /sys/class/dmi/id/chassis_type ]]; then
        chassis_type="$(cat /sys/class/dmi/id/chassis_type)"
    fi

    case "$chassis_type" in
        8|9|10|11|12|14)
            IS_LAPTOP="yes"
            ;;
    esac

    if [[ "$IS_LAPTOP" == "yes" ]]; then
        log "Detected laptop hardware."
    else
        log "Detected desktop/non-laptop hardware."
    fi
}

detect_luks() {
    HAS_LUKS="no"

    if lsblk -rno FSTYPE 2>/dev/null |
        grep -Eiq '^(crypto_LUKS|luks)$'; then
        HAS_LUKS="yes"
    fi

    if [[ "$HAS_LUKS" == "yes" ]]; then
        log "Detected LUKS encryption."
    else
        log "No LUKS-encrypted block device detected."
    fi
}

detect_gpu() {
    require_command lspci

    NVIDIA_LINES="$(
        lspci -nn 2>/dev/null |
            grep -iE 'NVIDIA|VGA compatible controller|3D controller' |
            grep -i 'NVIDIA' || true
    )"

    [[ -n "$NVIDIA_LINES" ]] ||
        die "No NVIDIA GPU was detected by lspci."

    GPU_NAME="$(
        printf '%s\n' "$NVIDIA_LINES" |
            sed -E 's/^.*NVIDIA Corporation ([^[]+).*/\1/' |
            sed -E 's/[[:space:]]+$//' |
            head -n1
    )"

    [[ -n "$GPU_NAME" ]] ||
        die "Could not determine the NVIDIA GPU model."

    log "Detected NVIDIA GPU: ${GPU_NAME}"
    echo "Select your GPU architecture"
    echo "1) Fermi: GeForce 400-500 and common Quadro/Tesla equivalents. /n
    Fermi support is experimental/end-of-life and may not work on modern Fedora releases."
    echo "2) Kepler: all GeForce 600, most GeForce 700, and Quadro K-series. /n
    Kepler requires X11; Wayland (and therefor Fedora) is not suitable for this legacy driver."
    echo "3) Maxwell or Pascal: GTX 745 and up to 1xxx series, including TITAN V and X."
    echo "4) Current GPUs: RTX series 2xxx all the way to 5xxx and onward."
    select GPU_NAME_CHOICE in "1" "2" "3" "4"; do
            case $iGPU_CHOICE in
                "1")
                    GPU_FAMILY="fermi"
                    NVIDIA_PACKAGE_SUFFIX="390xx"
                    break
                    ;;
                "2")
                    GPU_FAMILY="kepler"
                    NVIDIA_PACKAGE_SUFFIX="470xx"
                    break
                    ;;
                "3")
                    GPU_FAMILY="maxwell-pascal"
                    if (( FEDORA_VERSION >= 44 )); then
                        NVIDIA_PACKAGE_SUFFIX="580xx"
                    else
                        NVIDIA_PACKAGE_SUFFIX="current"
                    fi
                    break
                    ;;
                "4")
                    GPU_FAMILY="current"
                    NVIDIA_PACKAGE_SUFFIX="current"
                    break
                    ;;
                *)
                    echo "Invalid option. Please enter y/n."
                    ;;
            esac
        done
    log "Selected GPU family: ${GPU_FAMILY}"
    log "Selected NVIDIA package branch: ${NVIDIA_PACKAGE_SUFFIX}"
    if [[ "$GPU_FAMILY" == "fermi" ]]; then
        warn "Fermi support is experimental/end-of-life and may not work on modern Fedora releases."
    elif [[ "$GPU_FAMILY" == "kepler" ]]; then
        warn "Kepler requires X11; Wayland is not suitable for this legacy driver."
    fi
}

configure_kernel_arguments() {
    log "Configuring kernel arguments."

    local existing
    existing="$(rpm-ostree kargs 2>/dev/null || true)"

    local args=(
        "rd.driver.blacklist=nouveau,nova_core"
        "modprobe.blacklist=nouveau,nova_core"
        "nvidia-drm.modeset=1"
        "plymouth.use-simpledrm=1"
        #! "initcall_blacklist=simpledrm_platform_driver_init"
    )

    local arg
    local pending_args=()

    for arg in "${args[@]}"; do
        if ! grep -Fq -- "$arg" <<<"$existing"; then
            pending_args+=("--append=${arg}")
        fi
    done

    if ((${#pending_args[@]} > 0)); then
        sudo rpm-ostree kargs "${pending_args[@]}"
    else
        log "Required kernel arguments are already present."
    fi
}

install_rpmfusion_and_dependencies() {
    log "Updating Fedora and installing RPM Fusion plus build dependencies."
    sudo rpm-ostree update
    sudo rpm-ostree install \
        rpmdevtools \
        akmods \
        git \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

    set_phase "install-driver"

    cat <<'EOF'

The RPM Fusion and akmods deployment has been queued.

Reboot now, then run this same script again:

  ./install-nvidia-fedora.sh

EOF

    reboot_now
}

install_akmods_keys() {
    # This is not Secure Boot enrollment. It installs the Atomic akmods helper used by the guide for reliable akmods handling on immutable Fedora systems.
    log "Installing the Atomic akmods helper."

    rm -rf "$KEYS_REPO_DIR"
    git clone --depth=1 \
        https://github.com/CheariX/silverblue-akmods-keys.git \
        "$KEYS_REPO_DIR"

    pushd "$KEYS_REPO_DIR" >/dev/null
    sudo bash setup.sh

    shopt -s nullglob
    local key_rpms=(akmods-keys-*.rpm)
    shopt -u nullglob

    ((${#key_rpms[@]} > 0)) ||
        die "The akmods-keys build did not produce an RPM."

    sudo rpm-ostree install "${key_rpms[@]}"
    popd >/dev/null
}

install_nvidia_driver() {
    log "Installing NVIDIA driver packages."

    case "$NVIDIA_PACKAGE_SUFFIX" in
        current)
            sudo rpm-ostree install \
                akmod-nvidia \
                xorg-x11-drv-nvidia \
                xorg-x11-drv-nvidia-cuda
            ;;

        580xx)
            sudo rpm-ostree install \
                akmod-nvidia-580xx \
                xorg-x11-drv-nvidia-580xx \
                xorg-x11-drv-nvidia-580xx-cuda
            ;;

        470xx)
            sudo rpm-ostree install \
                akmod-nvidia-470xx \
                xorg-x11-drv-nvidia-470xx \
                xorg-x11-drv-nvidia-470xx-cuda
            ;;

        390xx)
            sudo rpm-ostree install \
                akmod-nvidia-390xx \
                xorg-x11-drv-nvidia-390xx \
                xorg-x11-drv-nvidia-390xx-cuda
            ;;

        *)
            die "Unknown NVIDIA package branch: $NVIDIA_PACKAGE_SUFFIX"
            ;;
    esac
}

configure_luks_initramfs() {
    [[ "$HAS_LUKS" == "yes" ]] || return 0

    log "Configuring the initramfs for LUKS."
    printf '%s\n' 'force_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "' |
        sudo tee /etc/dracut.conf.d/nvidia.conf >/dev/null
    
    if [[ "$IS_LAPTOP" == "no" ]]; then
        echo "If you have a CPU with integrated graphics (iGPU) and are on Desktop,
        do you want to prevent it from stealing the display before Nvidia takes over?
        (If your monitor is plugged directly into the NVIDIA GPU instead of Motherboard
        and you want to prevent the iGPU from interfering)/n y/n:"
        select choice in "y" "n"; do
            case $iGPU_CHOICE in
                "y")
                    echo 'omit_drivers+=" ${IGPU_DRIVER} "' | sudo tee /etc/dracut.conf.d/omit-amdgpu.conf
                    break
                    ;;
                "n")
                    break
                    ;;
                *)
                    echo "Invalid option. Please enter y/n."
                    ;;
            esac
        done
    fi
    

    # Do not omit i915 or amdgpu automatically. On laptops, the internal display commonly depends on the integrated GPU. On desktops, the monitor may also be connected to the motherboard output.
    if [[ "$CPU_VENDOR" == "Intel" || "$CPU_VENDOR" == "AMD" ]]; then
        log "Integrated GPU driver is ${IGPU_DRIVER}; it will be retained."
    fi

    sudo rpm-ostree initramfs --enable
}

prepare_driver_deployment() {
    # !!
    # install_akmods_keys
    install_nvidia_driver
    configure_kernel_arguments
    configure_luks_initramfs

    set_phase "verify"

    cat <<EOF

The NVIDIA driver deployment has been queued.

Detected:
  GPU:       ${GPU_NAME}
  GPU class: ${GPU_FAMILY}
  CPU:       ${CPU_VENDOR}
  Laptop:    ${IS_LAPTOP}
  LUKS:      ${HAS_LUKS}
  SecureBoot: ${SECURE_BOOT}

Reboot now, then run this same script once more to verify:

  ./install-nvidia-fedora.sh

EOF

    reboot_now
}

verify_installation() {
    log "Verifying the NVIDIA kernel module."

    local version
    version="$(modinfo -F version nvidia 2>/dev/null || true)"

    if [[ -z "$version" ]]; then
        warn "The NVIDIA kernel module is not available yet."
        warn "The akmods build may still be running, or Secure Boot may be blocking it."

        if [[ "$SECURE_BOOT" == "enabled" ]]; then
            warn "Secure Boot is enabled and this script intentionally did not perform MOK enrollment."
        fi

        exit 1
    fi

    printf 'NVIDIA kernel module version: %s\n' "$version"

    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi || warn "nvidia-smi could not communicate with the driver."
    else
        warn "nvidia-smi was not found, although the kernel module is installed."
    fi

    log "NVIDIA installation verification completed successfully."
}

main() {
    require_command rpm
    require_command rpm-ostree
    require_command lsblk
    sudo_available

    detect_system
    detect_secure_boot
    detect_cpu
    detect_laptop
    detect_luks
    detect_gpu

    case "$(get_phase)" in
        prepare)
            install_rpmfusion_and_dependencies
            ;;

        install-driver)
            prepare_driver_deployment
            ;;

        verify)
            verify_installation
            ;;

        *)
            die "Unknown installer phase: $(get_phase)"
            ;;
    esac
}

main "$@"
