#!/usr/bin/env bash
# Pemeriksa drift palet: QML kita hardcode empat warna jangkar, colors.toml
# memegang slot bernama. Kalau slotnya berubah, QML jadi basi — di sini kita
# tangkap. Ramp netral lain di payload sengaja TIDAK diperiksa: itu token yang
# diwarisi dari stock Omarchy, bukan slot palet (lihat CREDITS.md).

# Dipisah dari install.sh supaya bisa di-source tanpa menjalankan efek samping.
readonly TSUGUMORI_ANCHORS=(
  "#0a0a0a:background"
  "#080808:dark_background"
  "#cc1515:accent"
  "#e8e8e8:foreground"
)

# Cetak hex lowercase untuk satu slot; kosong kalau slotnya tidak ada.
tsugumori_slot_value() {
  grep -oE "^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"?#[0-9a-fA-F]{6}" "$2" 2>/dev/null \
    | grep -oE '#[0-9a-fA-F]{6}' | tr 'A-F' 'a-f' | head -1
}

# 0 = semua jangkar cocok, 1 = ada drift atau file hilang.
palette_check() {
  local file="${1:?path colors.toml wajib}" pair hex slot want drift=0
  if [[ ! -f $file ]]; then
    printf '  ! colors.toml tidak ditemukan: %s\n' "$file" >&2
    return 1
  fi
  for pair in "${TSUGUMORI_ANCHORS[@]}"; do
    hex="${pair%%:*}"; slot="${pair##*:}"
    want="$(tsugumori_slot_value "$slot" "$file")"
    if [[ -z $want ]]; then
      printf '  ! slot "%s" tidak ada di %s\n' "$slot" "$file" >&2
      drift=$((drift + 1))
    elif [[ $want != "$hex" ]]; then
      printf '  ! drift palet: %s = %s, tapi payload masih hardcode %s\n' \
        "$slot" "$want" "$hex" >&2
      drift=$((drift + 1))
    fi
  done
  ((drift == 0)) && printf '  palet   -> 4 jangkar cocok\n'
  return $((drift > 0))
}