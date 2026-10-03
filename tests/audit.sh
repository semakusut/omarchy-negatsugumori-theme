#!/usr/bin/env bash
# Gate pra-publish. Exit 0 = aman dipublikasikan.
# Cek di sini sengaja statis dan tanpa dependensi — harus jalan di CI mana pun.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
bad() { printf '  FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }
ok()  { printf '  ok   %s\n' "$1"; }

# 1. Layout: colors.toml WAJIB di root. Kalau hilang, omarchy-theme-set
#    fallback ke alacritty.toml yang justru dilarang di theme clone —
#    tema "jalan" tapi warnanya bukan punya kita, tanpa error.
if [[ -f colors.toml ]]; then ok "colors.toml ada di root"
else bad "colors.toml hilang di root — tema akan fallback ke alacritty.toml"; fi

# 2. 26 slot wajib: 1 mode + 25 warna.
missing=()
while read -r line; do
  for s in $line; do
    grep -qE "^[[:space:]]*$s[[:space:]]*=" colors.toml 2>/dev/null || missing+=("$s")
  done
done <<'SLOTS'
mode
accent selection muted
background dark_background darker_background lighter_background
foreground dark_foreground light_foreground bright_foreground
red yellow orange green cyan blue magenta brown
bright_red bright_yellow bright_green bright_cyan bright_blue bright_magenta
SLOTS
if ((${#missing[@]} == 0)); then ok "26 slot lengkap"
else bad "slot hilang: ${missing[*]}"; fi

# 3. License: dua notice wajib.
if [[ -f LICENSE ]]; then
  for n in 'Copyright (c) 2026 samyns' 'Modifications Copyright (c) 2026 Aleph1-9012'; do
    grep -qF "$n" LICENSE && ok "notice: $n" || bad "notice hilang: $n"
  done
else bad "LICENSE tidak ada"; fi

# 4. Batas ukuran. Asal (font/background mentah) dulu dilarang karena bisa
#    masuk 20MB dalam satu commit. Sekarang background memang ikut, jadi
#    blanket ban sudah tidak jujur — yang dijaga adalah UKURAN hasil turunnya:
#      - sumber asli tidak boleh ikut (git tidak butuh 8000x4500)
#      - preview.png dikecualikan: konvensi Omarchy sendiri 200k-900k
#      - backgrounds/ per-file <=512k, total repo <=5M
big=$(find . -path ./.git -prune -o -type f -size +512k \
        ! -name preview.png -print 2>/dev/null)
if [[ -z $big ]]; then ok "tidak ada file >512k (kecuali preview.png)"
else bad "file besar ikut: $big"; fi

if [[ -f preview.png ]]; then
  preview_k=$(du -k preview.png | cut -f1)
  if ((preview_k <= 1024)); then ok "preview.png ${preview_k}k (ikut konvensi Omarchy)"
  else bad "preview.png ${preview_k}k — konvensi Omarchy 200-900k, ini kegedean"; fi
fi

repo_k=$(du -sk --exclude=.git . | cut -f1)
if ((repo_k <= 5120)); then ok "repo ${repo_k}k (batas 5M)"
else bad "repo ${repo_k}k — lewat batas 5M, background atau font mentah ikut"; fi

# 5. Payload: 12 file di path persis (install.sh menyalin dari daftar ini).
expected=(
  patches/bar/clock/BarWidget.qml
  patches/bar/menu/BarWidget.qml
  patches/bar/widgets/WidgetButton.qml
  patches/bar/widgets/Workspaces.qml
  patches/lock/LockView.qml
  patches/lock/FormationCorner.qml
  patches/lock/PhaseLines.qml
  patches/lock/PhaseCpuFallback.qml
  patches/lock/PhaseArt.js
  patches/lock/shaders/lines.vert.qsb
  patches/lock/shaders/lines.frag.qsb
  patches/menu/Menu.qml
)
found=0
for f in "${expected[@]}"; do
  if [[ -f $f ]]; then found=$((found + 1)); else bad "payload hilang: $f"; fi
done
[[ $found -eq 12 ]] && ok "12 file payload ada ($found/12)"

# 6. File terlarang untuk theme clone — semuanya di-regenerate dari colors.toml.
# Pindai SELURUH pohon, bukan hanya daftar di atas: file terlarang tambahan
# tidak akan pernah muncul di $expected, jadi tidak akan pernah tertangkap.
while IFS= read -r f; do
  case "${f##*/}" in
    *.lua|alacritty.toml|foot.ini|ghostty.conf|kitty.conf|vscode.json)
      bad "file terlarang ikut ter-commit: $f" ;;
  esac
done < <(find . -path ./.git -prune -o -type f -print)

# 7. Service.qml tidak boleh disentuh sama sekali.
if grep -rqE 'shell/plugins/lock/Service\.qml' patches/ 2>/dev/null; then
  bad "payload menyentuh Service.qml — power logic harus tetap stock"
else ok "Service.qml tidak disentuh"; fi

# 8. Jangkar palet masih utuh di payload.
for a in '#0a0a0a' '#080808' '#cc1515' '#e8e8e8'; do
  grep -rqF "$a" patches/ || bad "jangkar $a hilang dari payload"
done

# 9. Sudoers harus per-file, tanpa wildcard maupun ALL.
if grep -rnE 'NOPASSWD:.*(\*|ALL)' install.sh hooks/ patches/ 2>/dev/null >/dev/null; then
  bad "NOPASSWD wildcard/ALL — harus daftar path eksplisit"
else ok "sudoers tanpa wildcard"; fi

# 10. install.sh tidak boleh menyalin file terlarang theme clone.
if grep -nE 'terminal/kitty\.conf|fastfetch' install.sh >/dev/null 2>&1; then
  bad "install.sh masih menyalin kitty/fastfetch — di-regenerate colors.toml / out of scope"
else ok "install.sh bersih dari kitty/fastfetch"; fi

# 11. install.sh harus memanggil pemeriksa palet sebelum menulis file, DAN palet
#     di colors.toml harus benar-benar dicocokkan dengan payload. Cek string saja
#     tidak cukup: "palette_check" bisa ada di install.sh sementara tidak pernah
#     dipanggil, atau colors.toml sudah drift dan audit tetap lolos.
if grep -q 'palette_check' install.sh; then ok "install.sh memverifikasi palet"
else bad "install.sh tidak memanggil palette_check"; fi

if [[ -f lib/palette.sh && -f colors.toml ]]; then
  if drift="$(bash -c 'source lib/palette.sh && palette_check colors.toml' 2>&1)"; then
    ok "jangkar colors.toml cocok dengan payload"
  else
    bad "drift palet: ${drift//$'\n'/; }"
  fi
else bad "lib/palette.sh atau colors.toml hilang — palet tidak bisa diverifikasi"; fi

# 12. README harus jujur soal batas cakupan.
missing_sections=()
for section in 'fzf, lazygit, gitui, htop' 'Lock screen perlu' 'Uninstall' 'omarchy update'; do
  grep -qF "$section" README.md 2>/dev/null || missing_sections+=("$section")
done
if ((${#missing_sections[@]} == 0)); then
  ok "README memuat batas cakupan dan cara uninstall"
else
  bad "README tidak menyebut: ${missing_sections[*]}"
fi

# 13. README tidak boleh menjanjikan semua app.
if grep -qiE 'semua (aplikasi|app|terminal).*(ikut|ter-cover)' README.md; then
  bad "README menjanjikan cakupan penuh — kontradiktif dengan bagian 'Yang tidak ikut'"
else ok "README tidak menjanjikan cakupan penuh"; fi

# 14. Tidak ada kredensial.
# Hanya file yang akan dipublish yang dipindai: .git dan .superpowers/ (gitignored,
# jadi tidak pernah masuk repo) tidak ikut — termasuk laporan kerja yang isinya
# memang boleh menyebut path absolut.
if grep -rInE '(api[_-]?key|secret|token|password|passwd)[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9/+_-]{16,}' \
     --exclude-dir=.git --exclude-dir=.superpowers . >/dev/null 2>&1; then
  bad "kemungkinan kredensial terdeteksi — periksa manual sebelum publish"
else ok "tidak ada kredensial"; fi

# 15. Tidak ada path absolut mesin ini.
# Polanya generik (/home/<user>/), bukan nama user literal: kalau nama user ditulis
# literal, baris ini akan cocok dengan dirinya sendiri dan check selalu gagal.
if grep -rInE '/home/[A-Za-z0-9._-]+/' \
     --exclude-dir=.git --exclude-dir=.superpowers . >/dev/null 2>&1; then
  bad "path absolut /home/<user> bocor ke repo publik"
else ok "tidak ada path absolut"; fi

# 16. Riwayat git bersih. Repo yang belum punya commit belum punya riwayat:
#     laporan N/A, bukan "lolos" — supaya tidak ada yang mengira history sudah
#     diperiksa padahal belum ada apa-apa untuk diperiksa.
if git rev-parse --git-dir >/dev/null 2>&1; then
  if [[ -z $(git rev-list --all 2>/dev/null) ]]; then
    ok "riwayat git belum ada (nol commit) — cek token aktif setelah commit pertama"
  elif git log -p --all 2>/dev/null | grep -InE 'ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}' >/dev/null; then
    bad "token ditemukan di riwayat git"
  else ok "riwayat git bersih"; fi
fi

# 17. File TANPA template .tpl di Omarchy — satu-satunya yang wajib disorhut repo.
#    omarchy-theme-set hanya refusing menimpa file yang sudah ada di folder tema,
#     sisanya di-generate dari colors.toml. Tapi tiga nama ini tidak punya
#     .tpl di /usr/share/omarchy/default/themed sama sekali:
#       walker.css  -> tanpa ini launcher/menu jatuh ke default GTK
#       backgrounds/ -> tanpa ini theme-set memunculkan "No background was found"
#       preview.png -> tanpa ini carousel theme picker kosong untuk tema ini
#     Gate ini harus gagal kalau salah satu hilang; dia diuji dengan mutasi.
for f in walker.css preview.png; do
  if [[ -s $f ]]; then ok "$f ada dan tidak kosong"
  else bad "$f hilang/kosong — Omarchy tidak punya ${f}.tpl, theme harus membawanya sendiri"; fi
done

if [[ -d backgrounds ]]; then
  bg=$(find backgrounds -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) 2>/dev/null)
  if [[ -n $bg ]]; then ok "backgrounds/ punya gambar ($(wc -l <<<"$bg") file)"
  else bad "backgrounds/ kosong atau tanpa gambar — theme-set akan gagal cari background"; fi
else bad "backgrounds/ hilang — theme-set akan gagal cari background"; fi

# 18. Warna walker.css harus nyambung ke colors.toml. Kalau palette berubah tapi
#     walker.css tidak, menu diam-diam jadi warna theme lain tanpa error.
if [[ -f walker.css && -f colors.toml ]]; then
  # background walker = isi kotak, jadi darker_background — bukan background
  # halaman. Tori/vantablack juga begitu (#040004 vs base), jadi ini disengaja.
  for pair in 'base:0a0a0a' 'background:050505' 'foreground:e8e8e8' 'bright_red:cc1515'; do
    k=${pair%%:*}; want=${pair##*:}
    if grep -qE "@define-color[[:space:]]+$k[[:space:]]+#?$want\b" walker.css; then
      ok "walker.css $k = #$want"
    else bad "walker.css $k tidak cocok colors.toml (harus #$want)"; fi
  done
else bad "walker.css atau colors.toml hilang — palet menu tidak bisa diverifikasi"; fi

printf '\n'
if ((fail)); then printf '  %d pemeriksaan gagal\n' "$fail" >&2; exit 1; fi
printf '  semua pemeriksaan lolos\n'