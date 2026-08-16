#!/usr/bin/env bash
#
# setup-openbox.sh
# Full customization: Kali Linux + Openbox -> Cybersecurity Workstation
# Dark / Frosted / Blue-Cyan / Minimal / Futuristic
#
# Aman dijalankan berkali-kali (idempotent untuk sebagian besar langkah).
# Tidak menghapus konfigurasi lama tanpa backup lebih dulu.
# Tidak menggunakan command destruktif (rm -rf /, dsb).

set -uo pipefail

LOG_FILE="$HOME/.setup-openbox.log"
exec > >(tee -a "$LOG_FILE") 2>&1

C_RESET='\033[0m'; C_INFO='\033[1;36m'; C_OK='\033[1;32m'; C_WARN='\033[1;33m'; C_ERR='\033[1;31m'
log_info(){ printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
log_ok(){   printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
log_warn(){ printf "${C_WARN}[WARN]${C_RESET} %s\n" "$*"; }
log_err(){  printf "${C_ERR}[FAIL]${C_RESET} %s\n" "$*" >&2; }

BACKUP_DIR=""
error_handler() {
    local line=$1
    log_err "Script berhenti di baris ${line}."
    log_err "Log lengkap: ${LOG_FILE}"
    if [ -n "$BACKUP_DIR" ]; then
        log_err "Konfigurasi lama Anda aman di: ${BACKUP_DIR}"
    fi
    exit 1
}
trap 'error_handler $LINENO' ERR

echo ""
echo "=================================================================="
echo "  KALI + OPENBOX :: CYBERSECURITY WORKSTATION THEME INSTALLER"
echo "=================================================================="
echo ""

# ------------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------------
cmd_exists(){ command -v "$1" &>/dev/null; }
pkg_installed(){ dpkg -s "$1" &>/dev/null; }
pkg_available(){ apt-cache show "$1" &>/dev/null 2>&1; }

detect_first() {
    for c in "$@"; do
        if cmd_exists "$c"; then echo "$c"; return 0; fi
    done
    echo ""
}

# ==================================================================
# STEP 1: DEPENDENCY CHECK / SYSTEM DETECTION
# ==================================================================
log_info "STEP 1/14 - Deteksi sistem..."

KALI_VERSION="unknown"
if [ -f /etc/os-release ]; then
    KALI_VERSION=$(. /etc/os-release && echo "${PRETTY_NAME:-unknown}")
fi

SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"

GPU_INFO=""
if cmd_exists lspci; then
    GPU_INFO=$(lspci 2>/dev/null | grep -Ei 'vga compatible controller|3d controller|display controller' || true)
fi
GPU_VENDOR="unknown"
if echo "$GPU_INFO" | grep -qi nvidia; then
    GPU_VENDOR="nvidia"
elif echo "$GPU_INFO" | grep -qi amd; then
    GPU_VENDOR="amd"
elif echo "$GPU_INFO" | grep -qi intel; then
    GPU_VENDOR="intel"
fi

RAM_TOTAL_MB=0
if cmd_exists free; then
    RAM_TOTAL_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    RAM_TOTAL_MB=${RAM_TOTAL_MB:-0}
fi

SCREEN_RES="unknown"
if cmd_exists xrandr && [ -n "${DISPLAY:-}" ]; then
    SCREEN_RES=$(xrandr 2>/dev/null | grep '\*' | awk '{print $1}' | head -n1)
    SCREEN_RES=${SCREEN_RES:-unknown}
fi

LOW_RESOURCE_MODE=false
if [ "$RAM_TOTAL_MB" -gt 0 ] && [ "$RAM_TOTAL_MB" -lt 2048 ]; then
    LOW_RESOURCE_MODE=true
fi

log_info "  Distro     : ${KALI_VERSION}"
log_info "  Session    : ${SESSION_TYPE}"
log_info "  GPU        : ${GPU_VENDOR} (${GPU_INFO:-tidak terdeteksi})"
log_info "  RAM        : ${RAM_TOTAL_MB} MB (low-resource mode: ${LOW_RESOURCE_MODE})"
log_info "  Resolusi   : ${SCREEN_RES}"

if [ "$SESSION_TYPE" = "wayland" ]; then
    log_warn "Session terdeteksi Wayland. Openbox adalah X11 window manager,"
    log_warn "konfigurasi tetap akan dibuat, tapi pastikan Anda login memakai sesi X11/Openbox."
fi

if [ "$EUID" -eq 0 ]; then
    log_warn "Script dijalankan sebagai root. Konfigurasi desktop sebaiknya dibuat sebagai user biasa."
    log_warn "Melanjutkan tetap menulis ke \$HOME milik root kecuali Anda ganti user."
fi

# ==================================================================
# STEP 2: BACKUP KONFIGURASI LAMA
# ==================================================================
log_info "STEP 2/14 - Backup konfigurasi lama..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config-backup-openbox-${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

BACKUP_TARGETS=(
    "$HOME/.config/openbox"
    "$HOME/.config/picom"
    "$HOME/.config/rofi"
    "$HOME/.config/tint2"
    "$HOME/.config/polybar"
    "$HOME/.config/gtk-3.0"
    "$HOME/.gtkrc-2.0"
    "$HOME/.config/nitrogen"
    "$HOME/.themes"
)

ANY_BACKED_UP=false
for target in "${BACKUP_TARGETS[@]}"; do
    if [ -e "$target" ]; then
        rel_name=$(basename "$target")
        cp -a "$target" "$BACKUP_DIR/${rel_name}.bak" 2>/dev/null || log_warn "Gagal backup: $target"
        log_ok "Backup: $target -> $BACKUP_DIR/${rel_name}.bak"
        ANY_BACKED_UP=true
    fi
done

if [ "$ANY_BACKED_UP" = false ]; then
    log_info "Tidak ada konfigurasi lama yang ditemukan (instalasi bersih)."
fi

# Buat script restore otomatis di dalam folder backup
cat > "$BACKUP_DIR/restore.sh" <<RESTOREEOF
#!/usr/bin/env bash
# Restore otomatis hasil backup ${TIMESTAMP}
set -uo pipefail
BK="$BACKUP_DIR"
echo "Memulihkan konfigurasi dari: \$BK"
[ -d "\$BK/openbox.bak" ]  && rm -rf "$HOME/.config/openbox"  && cp -a "\$BK/openbox.bak"  "$HOME/.config/openbox"
[ -d "\$BK/picom.bak" ]    && rm -rf "$HOME/.config/picom"    && cp -a "\$BK/picom.bak"    "$HOME/.config/picom"
[ -d "\$BK/rofi.bak" ]     && rm -rf "$HOME/.config/rofi"     && cp -a "\$BK/rofi.bak"     "$HOME/.config/rofi"
[ -d "\$BK/tint2.bak" ]    && rm -rf "$HOME/.config/tint2"    && cp -a "\$BK/tint2.bak"    "$HOME/.config/tint2"
[ -d "\$BK/polybar.bak" ]  && rm -rf "$HOME/.config/polybar"  && cp -a "\$BK/polybar.bak"  "$HOME/.config/polybar"
[ -d "\$BK/gtk-3.0.bak" ]  && rm -rf "$HOME/.config/gtk-3.0"  && cp -a "\$BK/gtk-3.0.bak"  "$HOME/.config/gtk-3.0"
[ -f "\$BK/.gtkrc-2.0.bak" ] && cp -a "\$BK/.gtkrc-2.0.bak" "$HOME/.gtkrc-2.0"
[ -d "\$BK/nitrogen.bak" ] && rm -rf "$HOME/.config/nitrogen" && cp -a "\$BK/nitrogen.bak" "$HOME/.config/nitrogen"
[ -d "\$BK/themes.bak" ]   && cp -a "\$BK/themes.bak/." "$HOME/.themes/" 2>/dev/null || true
echo "Selesai. Jalankan: openbox --restart"
RESTOREEOF
chmod +x "$BACKUP_DIR/restore.sh"
log_ok "Script rollback otomatis dibuat: $BACKUP_DIR/restore.sh"

# ==================================================================
# STEP 3: INSTALL DEPENDENCY
# ==================================================================
log_info "STEP 3/14 - Cek & install dependency..."

if ! cmd_exists apt-get; then
    log_err "apt-get tidak ditemukan. Script ini khusus Kali/Debian-based."
    exit 1
fi

sudo apt-get update -qq || log_warn "apt-get update gagal/parsial, melanjutkan dengan cache yang ada."

CORE_PKGS=(openbox picom rofi lxappearance papirus-icon-theme nitrogen feh xterm)

# obconf vs obconf-qt
OBCONF_PKG=""
if pkg_installed obconf || pkg_available obconf; then
    OBCONF_PKG="obconf"
elif pkg_installed obconf-qt || pkg_available obconf-qt; then
    OBCONF_PKG="obconf-qt"
fi
[ -n "$OBCONF_PKG" ] && CORE_PKGS+=("$OBCONF_PKG")

# Font: JetBrains Mono -> fallback Fira Code -> Hack
FONT_PKG=""
for f in fonts-jetbrains-mono fonts-firacode fonts-hack; do
    if pkg_installed "$f" || pkg_available "$f"; then
        FONT_PKG="$f"
        break
    fi
done
[ -n "$FONT_PKG" ] && CORE_PKGS+=("$FONT_PKG")

FONT_NAME="monospace"
case "$FONT_PKG" in
    fonts-jetbrains-mono) FONT_NAME="JetBrains Mono" ;;
    fonts-firacode)       FONT_NAME="Fira Code" ;;
    fonts-hack)           FONT_NAME="Hack" ;;
esac

# Panel: pilih berdasar resource terendah & ketersediaan (tint2 diprioritaskan)
PANEL_CHOICE="none"
if pkg_installed polybar; then
    PANEL_CHOICE="polybar"
elif pkg_available tint2; then
    PANEL_CHOICE="tint2"
elif pkg_available polybar; then
    PANEL_CHOICE="polybar"
fi
[ "$PANEL_CHOICE" != "none" ] && CORE_PKGS+=("$PANEL_CHOICE")

TO_INSTALL=()
ALREADY_OK=()
UNAVAILABLE=()
for p in "${CORE_PKGS[@]}"; do
    if pkg_installed "$p"; then
        ALREADY_OK+=("$p")
    elif pkg_available "$p"; then
        TO_INSTALL+=("$p")
    else
        UNAVAILABLE+=("$p")
    fi
done

[ "${#ALREADY_OK[@]}" -gt 0 ] && log_info "Sudah terinstall: ${ALREADY_OK[*]}"
[ "${#UNAVAILABLE[@]}" -gt 0 ] && log_warn "Tidak tersedia di repo, dilewati: ${UNAVAILABLE[*]}"

if [ "${#TO_INSTALL[@]}" -gt 0 ]; then
    log_info "Menginstall: ${TO_INSTALL[*]}"
    sudo apt-get install -y "${TO_INSTALL[@]}"
    log_ok "Instalasi paket selesai."
else
    log_info "Tidak ada paket baru yang perlu diinstall."
fi

if [ "$PANEL_CHOICE" = "none" ]; then
    log_warn "tint2 maupun polybar tidak tersedia di repo. Panel akan dilewati."
fi

# ==================================================================
# STEP 4: BUAT DIRECTORY
# ==================================================================
log_info "STEP 4/14 - Membuat struktur direktori..."

mkdir -p "$HOME/.config/openbox"
mkdir -p "$HOME/.config/picom"
mkdir -p "$HOME/.config/rofi"
[ "$PANEL_CHOICE" = "tint2" ]    && mkdir -p "$HOME/.config/tint2"
[ "$PANEL_CHOICE" = "polybar" ]  && mkdir -p "$HOME/.config/polybar"
mkdir -p "$HOME/.config/gtk-3.0"
mkdir -p "$HOME/.themes/CyberDark-OB/openbox-3"
mkdir -p "$HOME/.icons"
mkdir -p "$HOME/Pictures/wallpapers"
log_ok "Direktori siap."

# Deteksi aplikasi terinstall untuk menu & shortcut
TERMINAL_APP=$(detect_first xfce4-terminal kitty alacritty gnome-terminal qterminal xterm)
FILEMANAGER_APP=$(detect_first thunar pcmanfm nautilus dolphin)
BROWSER_APP=$(detect_first firefox-esr firefox chromium chromium-browser brave-browser)
EDITOR_APP=$(detect_first mousepad gedit leafpad featherpad)
SCREENSHOT_APP=$(detect_first flameshot scrot)
VOLUME_APP=$(detect_first pavucontrol pactl amixer)

[ -z "$TERMINAL_APP" ] && TERMINAL_APP="xterm"
[ -z "$FILEMANAGER_APP" ] && log_warn "File manager grafis tidak terdeteksi. Item menu 'File Manager' akan memakai fallback aman."
[ -z "$BROWSER_APP" ] && log_warn "Browser tidak terdeteksi. Item menu 'Browser' akan dilewati."

log_info "  Terminal      : $TERMINAL_APP"
log_info "  File Manager  : ${FILEMANAGER_APP:-tidak ditemukan}"
log_info "  Browser       : ${BROWSER_APP:-tidak ditemukan}"

# ==================================================================
# STEP 5: KONFIGURASI OPENBOX
# ==================================================================
log_info "STEP 5/14 - Menulis konfigurasi Openbox (rc.xml, menu.xml, theme)..."

# --- Openbox native theme (dark / blue-cyan) ---
cat > "$HOME/.themes/CyberDark-OB/openbox-3/themerc" <<'THEMEEOF'
window.active.border.color: #00CFFF
window.inactive.border.color: #1B2530
window.active.title.bg.color: #0D1117
window.inactive.title.bg.color: #0D1117
window.active.label.text.color: #7FE7FF
window.inactive.label.text.color: #55606B
window.active.button.unpressed.image.color: #7FE7FF
window.inactive.button.unpressed.image.color: #55606B
window.active.button.pressed.image.color: #00CFFF
window.active.button.hover.image.color: #00CFFF
border.width: 1
padding.width: 2
padding.height: 2
window.handle.width: 4
window.client.padding.width: 0
menu.items.bg.color: #0D1117
menu.items.text.color: #C9D8E3
menu.items.active.bg.color: #123240
menu.items.active.text.color: #00CFFF
menu.title.bg.color: #0D1117
menu.title.text.color: #00CFFF
menu.border.color: #00CFFF
menu.border.width: 1
osd.bg.color: #0D1117
osd.border.color: #00CFFF
osd.border.width: 1
osd.label.text.color: #00CFFF
THEMEEOF
log_ok "Openbox theme CyberDark-OB dibuat."

# --- rc.xml ---
cat > "$HOME/.config/openbox/rc.xml" <<'RCEOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">

  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>

  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>

  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
  </placement>

  <theme>
    <name>CyberDark-OB</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
    <font place="ActiveWindow">
      <name>${FONT_NAME_PLACEHOLDER}</name>
      <size>9</size>
      <weight>Bold</weight>
      <slant>Normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>${FONT_NAME_PLACEHOLDER}</name>
      <size>9</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
    <font place="MenuHeader">
      <name>${FONT_NAME_PLACEHOLDER}</name>
      <size>9</size>
      <weight>Bold</weight>
    </font>
    <font place="MenuItem">
      <name>${FONT_NAME_PLACEHOLDER}</name>
      <size>9</size>
      <weight>Normal</weight>
    </font>
    <font place="OnScreenDisplay">
      <name>${FONT_NAME_PLACEHOLDER}</name>
      <size>9</size>
      <weight>Bold</weight>
    </font>
  </theme>

  <desktops>
    <number>4</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Workspace 1</name>
      <name>Workspace 2</name>
      <name>Workspace 3</name>
      <name>Workspace 4</name>
    </names>
    <popupTime>400</popupTime>
  </desktops>

  <keyboard>
    <!-- Default penting Openbox (dipertahankan) -->
    <keybind key="A-Tab">
      <action name="NextWindow"/>
    </keybind>
    <keybind key="A-S-Tab">
      <action name="PreviousWindow"/>
    </keybind>
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <keybind key="A-space">
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </keybind>
    <keybind key="C-A-Left">
      <action name="GoToDesktop"><to>left</to></action>
    </keybind>
    <keybind key="C-A-Right">
      <action name="GoToDesktop"><to>right</to></action>
    </keybind>
    <keybind key="A-Escape">
      <action name="Lower"/><action name="FocusToBottom"/><action name="Unfocus"/>
    </keybind>

    <!-- Custom shortcut sesuai permintaan -->
    <keybind key="W-Return">
      <action name="Execute"><command>${TERMINAL_APP_PLACEHOLDER}</command></action>
    </keybind>
    <keybind key="W-r">
      <action name="Execute"><command>rofi -show drun</command></action>
    </keybind>
    <keybind key="W-e">
      <action name="Execute"><command>${FILEMANAGER_CMD_PLACEHOLDER}</command></action>
    </keybind>
    <keybind key="W-q">
      <action name="Close"/>
    </keybind>
    <keybind key="W-w">
      <action name="Close"/>
    </keybind>
    <keybind key="W-Tab">
      <action name="NextWindow"/>
    </keybind>
    <keybind key="W-1">
      <action name="GoToDesktop"><to>1</to></action>
    </keybind>
    <keybind key="W-2">
      <action name="GoToDesktop"><to>2</to></action>
    </keybind>
    <keybind key="W-3">
      <action name="GoToDesktop"><to>3</to></action>
    </keybind>
    <keybind key="W-4">
      <action name="GoToDesktop"><to>4</to></action>
    </keybind>
    <keybind key="W-d">
      <action name="ToggleShowDesktop"/>
    </keybind>
    <keybind key="W-l">
      <action name="Execute"><command>xset s activate</command></action>
    </keybind>
  </keyboard>

  <applications>
    <application class="*">
      <decor>yes</decor>
    </application>
  </applications>

</openbox_config>
RCEOF
log_ok "rc.xml dibuat."

# --- Substitusi placeholder (menghindari masalah escaping heredoc) ---
FILEMANAGER_CMD="${FILEMANAGER_APP:-xterm -e ranger}"
sed -i \
    -e "s|\${FONT_NAME_PLACEHOLDER}|${FONT_NAME:-monospace}|g" \
    -e "s|\${TERMINAL_APP_PLACEHOLDER}|${TERMINAL_APP}|g" \
    -e "s|\${FILEMANAGER_CMD_PLACEHOLDER}|${FILEMANAGER_CMD}|g" \
    "$HOME/.config/openbox/rc.xml"

# --- menu.xml (dinamis, hanya memuat aplikasi yang terdeteksi) ---
MENU_APPS=""
add_menu_item() {
    local label="$1" cmd="$2"
    MENU_APPS="${MENU_APPS}
    <item label=\"${label}\">
      <action name=\"Execute\"><command>${cmd}</command></action>
    </item>"
}

[ -n "$BROWSER_APP" ] && add_menu_item "Browser" "$BROWSER_APP"
add_menu_item "Terminal" "$TERMINAL_APP"
add_menu_item "File Manager" "$FILEMANAGER_CMD"
[ -n "$EDITOR_APP" ] && add_menu_item "Text Editor" "$EDITOR_APP"
[ -n "$SCREENSHOT_APP" ] && add_menu_item "Screenshot" "$SCREENSHOT_APP"

SYS_TOOLS=""
add_sys_item() {
    local label="$1" cmd="$2"
    SYS_TOOLS="${SYS_TOOLS}
    <item label=\"${label}\">
      <action name=\"Execute\"><command>${cmd}</command></action>
    </item>"
}
[ -n "$OBCONF_PKG" ] && cmd_exists "$OBCONF_PKG" && add_sys_item "Window Manager Settings" "$OBCONF_PKG"
cmd_exists lxappearance && add_sys_item "Appearance (GTK/Icons)" "lxappearance"
cmd_exists nitrogen && add_sys_item "Wallpaper" "nitrogen"
[ -n "$VOLUME_APP" ] && add_sys_item "Volume Control" "$VOLUME_APP"
cmd_exists htop && add_sys_item "System Monitor" "${TERMINAL_APP} -e htop"

cat > "$HOME/.config/openbox/menu.xml" <<MENUEOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">

  <menu id="root-menu" label="Applications">
    <menu id="apps-menu" label="Applications">${MENU_APPS}
    </menu>
    <menu id="systools-menu" label="System Tools">${SYS_TOOLS}
    </menu>
    <separator/>
    <item label="Reload Openbox">
      <action name="Reconfigure"/>
    </item>
    <item label="Restart Openbox">
      <action name="Restart"/>
    </item>
    <separator/>
    <item label="Exit">
      <action name="Exit"><prompt>yes</prompt></action>
    </item>
  </menu>

</openbox_menu>
MENUEOF
log_ok "menu.xml dibuat (aplikasi terdeteksi otomatis)."

# --- autostart (isi ditulis di STEP 12, buat placeholder dulu agar Openbox tidak error jika direload lebih awal) ---
[ -f "$HOME/.config/openbox/autostart" ] || touch "$HOME/.config/openbox/autostart"

# ==================================================================
# STEP 6: KONFIGURASI PICOM
# ==================================================================
log_info "STEP 6/14 - Menulis konfigurasi Picom..."

PICOM_SUPPORTS_CORNERS=false
if cmd_exists picom; then
    PV=$(picom --version 2>/dev/null | head -n1 | grep -oE '[0-9]+' | head -n1 || echo "0")
    [ "${PV:-0}" -ge 8 ] 2>/dev/null && PICOM_SUPPORTS_CORNERS=true
fi

USE_BLUR=true
BACKEND="glx"
if [ "$LOW_RESOURCE_MODE" = true ] || [ "$GPU_VENDOR" = "unknown" ]; then
    USE_BLUR=false
    BACKEND="xrender"
    log_warn "Mode ringan dipakai untuk Picom (RAM rendah atau GPU tidak terdeteksi): blur dimatikan, backend xrender."
elif [ "$GPU_VENDOR" = "nvidia" ]; then
    log_warn "GPU NVIDIA terdeteksi (kemungkinan proprietary driver). Blur GLX bisa berat/tearing -> pakai xrender fallback."
    USE_BLUR=false
    BACKEND="xrender"
fi

{
    echo "# picom.conf - auto-generated, prioritas: performance > effects"
    echo "backend = \"${BACKEND}\";"
    echo "vsync = true;"
    echo ""
    echo "shadow = true;"
    echo "shadow-radius = 12;"
    echo "shadow-opacity = 0.45;"
    echo "shadow-offset-x = -10;"
    echo "shadow-offset-y = -10;"
    echo "shadow-exclude = ["
    echo "  \"class_g = 'rofi'\","
    echo "  \"_GTK_FRAME_EXTENTS@:c\""
    echo "];"
    echo ""
    echo "fading = true;"
    echo "fade-in-step = 0.04;"
    echo "fade-out-step = 0.04;"
    echo "fade-delta = 6;"
    echo ""
    echo "inactive-opacity = 0.92;"
    echo "active-opacity = 0.97;"
    echo "frame-opacity = 0.90;"
    echo "inactive-opacity-override = false;"
    echo ""
    if [ "$USE_BLUR" = true ]; then
        echo "blur-method = \"dual_kawase\";"
        echo "blur-strength = 5;"
        echo "blur-background = true;"
        echo "blur-background-exclude = ["
        echo "  \"window_type = 'dock'\","
        echo "  \"window_type = 'desktop'\""
        echo "];"
        echo ""
    fi
    if [ "$PICOM_SUPPORTS_CORNERS" = true ]; then
        echo "corner-radius = 8;"
        echo "rounded-corners-exclude = ["
        echo "  \"window_type = 'dock'\","
        echo "  \"window_type = 'desktop'\""
        echo "];"
        echo ""
    fi
    echo "mark-wmwin-focused = true;"
    echo "mark-ovredir-focused = true;"
    echo "detect-rounded-corners = true;"
    echo "detect-client-opacity = true;"
    echo "detect-transient = true;"
    echo "use-damage = true;"
    echo ""
    echo "wintypes:"
    echo "{"
    echo "  dock = { shadow = false; };"
    echo "  dropdown_menu = { opacity = 0.95; };"
    echo "  popup_menu = { opacity = 0.95; };"
    echo "  tooltip = { fade = true; shadow = false; opacity = 0.9; };"
    echo "};"
} > "$HOME/.config/picom/picom.conf"

log_ok "picom.conf dibuat (backend=${BACKEND}, blur=${USE_BLUR}, rounded-corners=${PICOM_SUPPORTS_CORNERS})."

# ==================================================================
# STEP 7: KONFIGURASI ROFI
# ==================================================================
log_info "STEP 7/14 - Menulis konfigurasi Rofi..."

cat > "$HOME/.config/rofi/cyber-dark.rasi" <<'ROFITHEMEEOF'
* {
    bg0:        #0D1117E6;
    bg1:        #101A24E6;
    bg-selected: #123240FF;
    fg0:        #C9D8E3FF;
    accent:     #00CFFFFF;
    accent-dim: #5C6773FF;

    background-color:   transparent;
    text-color:         @fg0;
}

window {
    background-color: @bg0;
    border:           1px;
    border-color:     @accent;
    border-radius:    10px;
    padding:          16px;
    width:            32%;
}

mainbox {
    background-color: transparent;
    children: [ inputbar, listview ];
    spacing: 12px;
}

inputbar {
    background-color: @bg1;
    text-color:        @accent;
    border:             1px;
    border-color:       @accent-dim;
    border-radius:      8px;
    padding:             10px;
    children: [ prompt, entry ];
}

prompt {
    text-color: @accent;
    padding: 0px 8px 0px 0px;
}

entry {
    placeholder: "Search...";
    placeholder-color: @accent-dim;
    text-color: @fg0;
}

listview {
    background-color: transparent;
    lines: 8;
    spacing: 4px;
    scrollbar: false;
}

element {
    background-color: transparent;
    text-color: @fg0;
    border-radius: 6px;
    padding: 8px;
}

element selected {
    background-color: @bg-selected;
    text-color: @accent;
}

element-text {
    background-color: transparent;
    text-color: inherit;
}
ROFITHEMEEOF

cat > "$HOME/.config/rofi/config.rasi" <<ROFICFGEOF
configuration {
    modi:               "drun,run,window";
    show-icons:          true;
    icon-theme:          "Papirus-Dark";
    font:                "${FONT_NAME:-monospace} 11";
    display-drun:        " Apps";
    display-run:         " Run";
    display-window:      " Window";
    drun-display-format: "{name}";
}

@theme "cyber-dark"
ROFICFGEOF

log_ok "Rofi (config.rasi + cyber-dark.rasi) dibuat."

# ==================================================================
# STEP 8: KONFIGURASI PANEL (Tint2 / Polybar)
# ==================================================================
log_info "STEP 8/14 - Menulis konfigurasi panel (${PANEL_CHOICE})..."

if [ "$PANEL_CHOICE" = "tint2" ]; then
cat > "$HOME/.config/tint2/tint2rc" <<TINT2EOF
# ==== Panel geometry ====
panel_items = TSC
panel_size = 100% 30
panel_margin = 0 0
panel_padding = 8 0 8
panel_background_id = 1
panel_position = top center horizontal
panel_layer = top
panel_monitor = all
wm_menu = 1
panel_dock = 0
autohide = 0

# ==== Background 1: dark frosted ====
rounded = 0
border_width = 0
background_color = #0D1117 88
border_color = #00CFFF 40

# ==== Taskbar ====
taskbar_mode = single_desktop
taskbar_padding = 4 2 4
taskbar_background_id = 0
taskbar_active_background_id = 0
taskbar_name = 1
taskbar_hide_inactive_tasks = 0

task_text = 1
task_icon = 1
task_centered = 0
task_maximum_size = 160 30
task_padding = 6 2
task_font_color = #C9D8E3 100
task_active_font_color = #00CFFF 100
task_background_id = 0
task_active_background_id = 0

# ==== Clock ====
time1_format = %H:%M
time2_format = %a %d %b
clock_font_color = #00CFFF 100
clock_padding = 8 0
clock_background_id = 0

# ==== System tray ====
systray_padding = 4 4 6
systray_background_id = 0
systray_sort = ascending
systray_icon_size = 18

# ==== Fonts ====
panel_items_order = TSC
task_font = ${FONT_NAME:-monospace} 9
clock_font = ${FONT_NAME:-monospace} 9 Bold

# ==== Executor: CPU ====
execp = new
execp_command = sh -c "printf 'CPU %s%%' \$(top -bn1 | grep 'Cpu(s)' | awk '{printf \"%d\", \$2+\$4}')"
execp_interval = 3
execp_font_color = #7FE7FF 100
execp_font = ${FONT_NAME:-monospace} 9
execp_padding = 8 0

# ==== Executor: RAM ====
execp = new
execp_command = sh -c "free -m | awk '/^Mem:/{printf \"RAM %d%%\", (\$3/\$2)*100}'"
execp_interval = 5
execp_font_color = #7FE7FF 100
execp_font = ${FONT_NAME:-monospace} 9
execp_padding = 8 0

# ==== Executor: Network up/down ====
execp = new
execp_command = sh -c "cat /proc/net/dev | awk -v RS='' '{for(i=1;i<=NF;i++) if(\$i ~ /:/) print \$i}' | head -1"
execp_interval = 5
execp_font_color = #7FE7FF 100
execp_font = ${FONT_NAME:-monospace} 9
execp_padding = 8 0

# ==== Executor: Volume ====
execp = new
execp_command = sh -c "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -1 | grep -oE '[0-9]+%' | head -1 || echo 'VOL --'"
execp_interval = 5
execp_font_color = #7FE7FF 100
execp_font = ${FONT_NAME:-monospace} 9
execp_padding = 8 0
TINT2EOF
    log_ok "tint2rc dibuat (CPU/RAM/Net/Volume via Execp, clock, systray)."

elif [ "$PANEL_CHOICE" = "polybar" ]; then
cat > "$HOME/.config/polybar/config.ini" <<POLYBAREOF
[colors]
bg = #E60D1117
bg-alt = #E6101A24
fg = #C9D8E3
accent = #00CFFF
accent-dim = #5C6773

[bar/cybertop]
width = 100%
height = 30
radius = 0
background = \${colors.bg}
foreground = \${colors.fg}
line-size = 2
border-size = 0
padding-left = 1
padding-right = 1
module-margin = 1
font-0 = "${FONT_NAME:-monospace}:size=10;2"
modules-left = workspaces
modules-center = date
modules-right = cpu memory network-status volume tray
tray-position = right
tray-padding = 4

[module/workspaces]
type = internal/xworkspaces
label-active = %name%
label-active-foreground = \${colors.accent}
label-active-background = \${colors.bg-alt}
label-active-padding = 2
label-inactive = %name%
label-inactive-foreground = \${colors.accent-dim}
label-inactive-padding = 2

[module/date]
type = internal/date
interval = 5
date = %H:%M
date-alt = %a %d %b %Y
label-foreground = \${colors.accent}

[module/cpu]
type = internal/cpu
interval = 2
label = CPU %percentage%%
label-foreground = \${colors.fg}

[module/memory]
type = internal/memory
interval = 3
label = RAM %percentage_used%%
label-foreground = \${colors.fg}

[module/network-status]
type = internal/network
interface-type = wired
interval = 3
label-connected = "NET %downspeed:9%"
label-disconnected = "NET --"
label-connected-foreground = \${colors.fg}
label-disconnected-foreground = \${colors.accent-dim}

[module/volume]
type = internal/pulseaudio
label-volume = VOL %percentage%%
label-volume-foreground = \${colors.fg}
label-muted = VOL mute
label-muted-foreground = \${colors.accent-dim}

[module/tray]
type = internal/tray
POLYBAREOF

cat > "$HOME/.config/polybar/launch.sh" <<'POLYLAUNCHEOF'
#!/usr/bin/env bash
pkill -x polybar 2>/dev/null
sleep 0.3
polybar cybertop >/tmp/polybar.log 2>&1 &
disown
POLYLAUNCHEOF
chmod +x "$HOME/.config/polybar/launch.sh"
    log_ok "polybar config.ini + launch.sh dibuat."
else
    log_warn "Tidak ada panel yang dikonfigurasi (tint2/polybar tidak tersedia)."
fi

# ==================================================================
# STEP 9: KONFIGURASI GTK
# ==================================================================
log_info "STEP 9/14 - Menulis konfigurasi GTK..."

GTK_THEME_NAME="Adwaita-dark"
if pkg_installed arc-theme; then
    GTK_THEME_NAME="Arc-Dark"
else
    log_info "arc-theme tidak terinstall, memakai Adwaita-dark (built-in GTK, paling stabil)."
fi

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

cat > "$HOME/.config/gtk-3.0/settings.ini" <<GTK3EOF
[Settings]
gtk-theme-name=${GTK_THEME_NAME}
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=${FONT_NAME:-monospace} 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
gtk-enable-animations=1
gtk-primary-button-warps-slider=0
GTK3EOF

cp "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

cat > "$HOME/.gtkrc-2.0" <<GTK2EOF
gtk-theme-name="${GTK_THEME_NAME}"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="${FONT_NAME:-monospace} 10"
gtk-cursor-theme-name="Adwaita"
GTK2EOF

if cmd_exists gsettings; then
    gsettings set org.gnome.desktop.interface gtk-theme "${GTK_THEME_NAME}" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true
fi

log_ok "GTK2/GTK3/GTK4 diarahkan ke tema ${GTK_THEME_NAME} + Papirus-Dark."

# ==================================================================
# STEP 10: KONFIGURASI ICON THEME
# ==================================================================
log_info "STEP 10/14 - Konfigurasi icon theme..."

if pkg_installed papirus-icon-theme; then
    cmd_exists gtk-update-icon-cache && gtk-update-icon-cache -f "/usr/share/icons/Papirus-Dark" 2>/dev/null || true
    log_ok "Papirus-Dark aktif sebagai icon theme default."
else
    log_warn "papirus-icon-theme tidak terinstall, icon theme sistem tetap dipakai."
fi

# ==================================================================
# STEP 11: KONFIGURASI WALLPAPER
# ==================================================================
log_info "STEP 11/14 - Konfigurasi wallpaper..."

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
mkdir -p "$WALLPAPER_DIR"
WALLPAPER_FILE=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | head -n1 || true)

if [ -n "$WALLPAPER_FILE" ]; then
    log_ok "Wallpaper ditemukan: $WALLPAPER_FILE"
else
    log_warn "Belum ada wallpaper di ${WALLPAPER_DIR}."
    log_warn "Taruh gambar dark/blue-cyan/cyber Anda sendiri di folder itu (format jpg/png),"
    log_warn "lalu jalankan ulang 'nitrogen' atau restart autostart. Sebagai fallback, warna"
    log_warn "latar solid dark akan dipakai lewat xsetroot."
fi

if cmd_exists nitrogen; then
    mkdir -p "$HOME/.config/nitrogen"
    cat > "$HOME/.config/nitrogen/nitrogen.cfg" <<NITROCFGEOF
[nitrogen]
view=icon
recurse=true
sort=alphabetic
icon_caption=true

[geometry]
posx=0
posy=0
sizex=800
sizey=600
NITROCFGEOF

    if [ -n "$WALLPAPER_FILE" ]; then
        cat > "$HOME/.config/nitrogen/bg-saved.cfg" <<BGCFGEOF
[xin_-1]
file=${WALLPAPER_FILE}
mode=5
bgcolor=#0D1117
BGCFGEOF
    fi
fi

# ==================================================================
# STEP 12: AUTOSTART
# ==================================================================
log_info "STEP 12/14 - Menulis autostart..."

AUTOSTART_FILE="$HOME/.config/openbox/autostart"

{
    echo "#!/usr/bin/env bash"
    echo "# Auto-generated autostart - CyberDark Openbox"
    echo ""
    echo "# --- Wallpaper ---"
    if cmd_exists nitrogen; then
        echo 'pgrep -x nitrogen >/dev/null || (nitrogen --restore &)'
    elif cmd_exists feh; then
        if [ -n "$WALLPAPER_FILE" ]; then
            echo "feh --bg-fill \"${WALLPAPER_FILE}\" &"
        else
            echo '# Belum ada wallpaper file, gunakan warna solid dark sebagai fallback'
            echo 'cmd_exists xsetroot 2>/dev/null && xsetroot -solid "#0D1117" &'
        fi
    fi
    echo ""
    echo "# --- Compositor ---"
    echo 'pgrep -x picom >/dev/null || (picom --config "$HOME/.config/picom/picom.conf" -b &)'
    echo ""
    echo "# --- Panel ---"
    if [ "$PANEL_CHOICE" = "tint2" ]; then
        echo 'pgrep -x tint2 >/dev/null || (tint2 &)'
    elif [ "$PANEL_CHOICE" = "polybar" ]; then
        echo 'pgrep -x polybar >/dev/null || ("$HOME/.config/polybar/launch.sh" &)'
    fi
    echo ""
    echo "# --- Notifikasi (opsional, jika terinstall) ---"
    echo 'cmd_exists() { command -v "$1" &>/dev/null; }'
    echo 'cmd_exists dunst && (pgrep -x dunst >/dev/null || (dunst &))'
    echo ""
    echo "# --- Numlock, dsb bisa ditambah manual di sini ---"
} > "$AUTOSTART_FILE"

chmod +x "$AUTOSTART_FILE"
log_ok "autostart dibuat (idempotent, pakai pgrep sebelum start ulang proses)."

# ==================================================================
# STEP 13: VALIDASI KONFIGURASI
# ==================================================================
log_info "STEP 13/14 - Validasi konfigurasi..."

VALIDATION_OK=true

validate_xml() {
    local file="$1"
    if cmd_exists python3; then
        if python3 -c "import xml.etree.ElementTree as ET; ET.parse('${file}')" 2>/dev/null; then
            log_ok "XML valid: $(basename "$file")"
        else
            log_err "XML TIDAK valid: $(basename "$file")"
            VALIDATION_OK=false
        fi
    else
        log_warn "python3 tidak ada, lewati validasi XML untuk $(basename "$file")."
    fi
}

validate_xml "$HOME/.config/openbox/rc.xml"
validate_xml "$HOME/.config/openbox/menu.xml"

if [ -s "$HOME/.config/picom/picom.conf" ]; then
    log_ok "picom.conf tidak kosong."
else
    log_err "picom.conf kosong/gagal ditulis."
    VALIDATION_OK=false
fi

if [ -s "$HOME/.config/rofi/config.rasi" ] && [ -s "$HOME/.config/rofi/cyber-dark.rasi" ]; then
    log_ok "Konfigurasi Rofi lengkap."
else
    log_err "Konfigurasi Rofi tidak lengkap."
    VALIDATION_OK=false
fi

if [ "$PANEL_CHOICE" = "tint2" ] && [ ! -s "$HOME/.config/tint2/tint2rc" ]; then
    log_err "tint2rc kosong/gagal ditulis."
    VALIDATION_OK=false
fi
if [ "$PANEL_CHOICE" = "polybar" ] && [ ! -s "$HOME/.config/polybar/config.ini" ]; then
    log_err "polybar config.ini kosong/gagal ditulis."
    VALIDATION_OK=false
fi

if [ "$VALIDATION_OK" = true ]; then
    log_ok "Semua file konfigurasi tervalidasi dengan baik."
else
    log_warn "Ada file yang gagal validasi, cek pesan [FAIL] di atas sebelum reload Openbox."
fi

# ==================================================================
# STEP 14: RINGKASAN
# ==================================================================
echo ""
echo "=================================================================="
echo "  RINGKASAN INSTALASI"
echo "=================================================================="
echo "  Distro          : ${KALI_VERSION}"
echo "  GPU             : ${GPU_VENDOR}"
echo "  RAM             : ${RAM_TOTAL_MB} MB (low-resource: ${LOW_RESOURCE_MODE})"
echo "  Picom backend   : ${BACKEND} | blur=${USE_BLUR} | rounded-corners=${PICOM_SUPPORTS_CORNERS}"
echo "  Panel           : ${PANEL_CHOICE}"
echo "  Font            : ${FONT_NAME:-monospace} (${FONT_PKG:-tidak diinstall, pakai font sistem})"
echo "  Terminal        : ${TERMINAL_APP}"
echo "  File Manager    : ${FILEMANAGER_CMD}"
echo "  Browser di menu : ${BROWSER_APP:-tidak ada}"
echo "  Wallpaper       : ${WALLPAPER_FILE:-belum ada, lihat folder $WALLPAPER_DIR}"
echo "  Backup lama     : ${BACKUP_DIR}"
echo "  Rollback script : ${BACKUP_DIR}/restore.sh"
echo "  Log lengkap     : ${LOG_FILE}"
echo "=================================================================="
echo ""
log_ok "Setup selesai. Jalankan 'openbox --restart' untuk menerapkan (lihat instruksi terpisah)."
