#!/bin/bash
# Instal reskin Negatsugumori untuk Omarchy: bar + menu + lock.
#
# Palet TIDAK di-install lewat script ini — `Install > Theme` di Omarchy yang
# menangani itu. Script ini hanya menimpa file root-owned yang tidak bisa ditulis
# user, lalu memasang hook supaya penimpaan itu otomatis kembali setelah update.
#
# Cara uninstall: `sudo rm /etc/sudoers.d/omarchy-tsugumori`, hapus hook dari
# ~/.config/omarchy/hooks/post-update.d/, lalu `omarchy update` untuk mengembalikan
# file asli.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_DST="/usr/share/omarchy/shell/plugins/lock"

# shellcheck source=lib/palette.sh
source "$SRC/lib/palette.sh"

say() { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }

# ---------------------------------------------------------------- palet
# QML kita hardcode empat jangkar. Kalau colors.toml berubah tanpa QML ikut,
# setengah mesin diam-diam warna basi. Tangkap di sini, sebelum file ditulis.
if ! palette_check "$SRC/colors.toml"; then
  echo "  GAGAL: palet tidak cocok dengan payload. Lihat CREDITS.md." >&2
  exit 1
fi

# ---------------------------------------------------------------- bar
DST="$HOME/.local/share/omarchy-bar-tsugumori"
mkdir -p "$DST/clock" "$DST/menu" "$DST/widgets"
cp -f "$SRC/patches/bar/clock/BarWidget.qml" "$DST/clock/"
cp -f "$SRC/patches/bar/menu/BarWidget.qml" "$DST/menu/"
cp -f "$SRC/patches/bar/widgets/WidgetButton.qml" "$SRC/patches/bar/widgets/Workspaces.qml" "$DST/widgets/"
say "bar      -> $DST"

# ---------------------------------------------------------------- launcher menu
MST="$HOME/.local/share/omarchy-menu-tsugumori"
mkdir -p "$MST"
cp -f "$SRC/patches/menu/Menu.qml" "$MST/"
say "menu     -> $MST"

# ---------------------------------------------------------------- lock screen
LST="$HOME/.local/share/omarchy-lock-tsugumori"
mkdir -p "$LST/shaders"
cp -f "$SRC/patches/lock/LockView.qml" "$SRC/patches/lock/FormationCorner.qml" \
      "$SRC/patches/lock/PhaseLines.qml" "$SRC/patches/lock/PhaseCpuFallback.qml" \
      "$SRC/patches/lock/PhaseArt.js" "$LST/"
cp -f "$SRC/patches/lock/shaders/lines.vert.qsb" "$SRC/patches/lock/shaders/lines.frag.qsb" "$LST/shaders/"
say "lock     -> $LST"

# ---------------------------------------------------------------- post-update hooks
HOOKS="$HOME/.config/omarchy/hooks/post-update.d"
mkdir -p "$HOOKS"
# Kosongkan dulu supaya hook lama dari instalasi sebelumnya tidak tertinggal diam-diam.
# Kalau belum ada hook (mis. repo baru, atau Task 5 belum jalan), beri peringatan
# dan lanjutkan — baris ringkasan "hooks ->" jadi jujur soal apa yang terpasang,
# dan Task 5 butuh baris itu untuk memverifikasi hook-nya benar-benar ter-copy.
shopt -s nullglob
rm -f "$HOOKS/restore-tsugumori-"*.hook
found=()
for hook in "$SRC/hooks/"*.hook; do
  found+=("$hook"); cp -f "$hook" "$HOOKS/"; chmod +x "$HOOKS/$(basename "$hook")"
done
shopt -u nullglob
if (( ${#found[@]} == 0 )); then
  warn "hooks    -> BELUM ADA di $SRC/hooks — restore tiap omarchy update tidak aktif"
else
  say "hooks    -> $HOOKS (${#found[@]} hook, restore otomatis tiap omarchy update)"
fi

# ---------------------------------------------------------------- sudoers (generated)
# Hook restore butuh `sudo -n cp` tanpa password. Dibatasi per-file, tanpa wildcard,
# supaya tidak membuka akses root blanket. Path di-generate dari $HOME sehingga
# tetap benar di PC/laptop lain yang username-nya berbeda.
#
# Daftar src:dst ini WAJIB sinkron dengan DST= di hooks/*.hook. Kalau lo menambah
# file reskin baru, tambah juga di sini — cek_ di bawah akan menangkap kalau lupa.
COPY_PAIRS=(
  # bar
  "$DST/widgets/Workspaces.qml:/usr/share/omarchy/shell/plugins/bar/widgets/Workspaces.qml"
  "$DST/clock/BarWidget.qml:/usr/share/omarchy/shell/plugins/panels/clock/BarWidget.qml"
  "$DST/menu/BarWidget.qml:/usr/share/omarchy/shell/plugins/menu/BarWidget.qml"
  "$DST/widgets/WidgetButton.qml:/usr/share/omarchy/shell/Ui/WidgetButton.qml"
  # launcher menu
  "$MST/Menu.qml:/usr/share/omarchy/shell/plugins/menu/Menu.qml"
  # lock
  "$LST/LockView.qml:$LOCK_DST/LockView.qml"
  "$LST/FormationCorner.qml:$LOCK_DST/FormationCorner.qml"
  "$LST/PhaseLines.qml:$LOCK_DST/PhaseLines.qml"
  "$LST/PhaseCpuFallback.qml:$LOCK_DST/PhaseCpuFallback.qml"
  "$LST/PhaseArt.js:$LOCK_DST/PhaseArt.js"
  "$LST/shaders/lines.vert.qsb:$LOCK_DST/shaders/lines.vert.qsb"
  "$LST/shaders/lines.frag.qsb:$LOCK_DST/shaders/lines.frag.qsb"
)
MKDIRS=( "$LOCK_DST/shaders" )

# Skip pemasian sudoers: untuk dry-run, CI, atau mesin yang sudo-nya sudah cukup
if [[ ${TUGUMORI_SKIP_SUDO:-0} == 1 ]]; then
  say "sudoers  -> dilewati (TUGUMORI_SKIP_SUDO=1)"
else
  SUDOERS="$(mktemp)"
  # cmds = daftar command persis yang dipakai hook (tanpa koma penggantung —
  # koma setelah item terakhir bikin visudo reject dengan "syntax error")
  cmds=()
  for pair in "${COPY_PAIRS[@]}"; do
    cmds+=("/usr/bin/cp ${pair%%:*} ${pair##*:}")
  done
  for d in "${MKDIRS[@]}"; do cmds+=("/usr/bin/mkdir -p $d"); done
  {
    echo "# NOPASSWD hanya untuk restore hook Tsugumori (bar, menu, lock)."
    echo "# Dibuat otomatis oleh install.sh — jangan diedit manual."
    echo "# Hapus file ini untuk mencabut akses: sudo rm /etc/sudoers.d/omarchy-tsugumori"
    printf '%s ALL=(root) NOPASSWD:' "$(id -un)"
    printf ' %s' "$(IFS=,; echo "${cmds[*]}")"
    printf '\n'
  } > "$SUDOERS"

  if visudo -cf "$SUDOERS" >/dev/null 2>&1; then
    echo
    echo "  Passphrase sudo dibutuhkan SEKALI untuk pasang sudoers (${#cmds[@]} command, tanpa wildcard):"
    if ! sudo install -m 0440 -o root -g root "$SUDOERS" /etc/sudoers.d/omarchy-tsugumori; then
      echo "  GAGAL memasang sudoers." >&2
    else
      say "sudoers  -> /etc/sudoers.d/omarchy-tsugumori"
    fi
  else
    echo "  GAGAL: sudoers hasil generate tidak lolos visudo -c. Tidak dipasang (aman)." >&2
    visudo -cf "$SUDOERS" 2>&1 | sed 's/^/    /' >&2
  fi
  rm -f "$SUDOERS"

  # Self-check. `sudo -n -l <cmd>` TIDAK bisa dipakai sebagai oracle: exit 0
  # baik itu command-nya diizinkan atau tidak. Jadi jalankan restore-nya
  # sungguhan (isi file cuma ditulis ulang dengan isi yang sama, tidak merusak),
  # lalu bandingkan hasilnya.
  missing=0
  for pair in "${COPY_PAIRS[@]}"; do
    src="${pair%%:*}"; dst="${pair##*:}"
    if [[ ! -f $src ]]; then
      echo "  ! source tidak ada: $src" >&2; missing=$((missing + 1)); continue
    fi
    if ! sudo -n cp "$src" "$dst" 2>/dev/null; then
      echo "  ! sudoers menolak: cp $src" >&2; missing=$((missing + 1)); continue
    fi
    cmp -s "$src" "$dst" || { echo "  ! hasil restore beda: $dst" >&2; missing=$((missing + 1)); }
  done
  for d in "${MKDIRS[@]}"; do
    sudo -n mkdir -p "$d" 2>/dev/null \
      || { echo "  ! sudoers menolak: mkdir -p $d" >&2; missing=$((missing + 1)); }
  done
  if (( missing > 0 )); then
    echo "  $missing command tidak tercakup -> hook TIDAK auto-restore setelah update." >&2
    echo "  Perbaiki: sudo rm /etc/sudoers.d/omarchy-tsugumori && ./install.sh" >&2
  else
    say "cek      -> ${#COPY_PAIRS[@]} cp + ${#MKDIRS[@]} mkdir terpasang & restore OK"
  fi
fi

echo
say "OK. Palet + reskin terpasang."
say "Restart shell: omarchy restart shell"