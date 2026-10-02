#!/usr/bin/env bash
# Self-check untuk lib/palette.sh. Tanpa framework, tanpa dependensi.
set -uo pipefail
# shellcheck source=../lib/palette.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/palette.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ok=0; bad=0

expect_rc() { # $1=desc $2=rc yang diharapkan, sisanya argumen fungsi
  local desc="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  if [[ $got == "$want" ]]; then ok=$((ok + 1)); printf '  ok   %s\n' "$desc"
  else bad=$((bad + 1)); printf '  FAIL %s (rc=%s, harap rc=%s)\n' "$desc" "$got" "$want"; fi
}

# Cek rc saja tidak cukup: file yang hilang juga bikin rc=1, jadi test drift bisa
# hijau tanpa pernah menguji drift. Karena itu isi pesan error ikut diperiksa.
expect_msg() { # $1=desc $2=file $3=substring yang harus muncul di output
  local desc="$1" file="$2" needle="$3" out rc
  out="$(palette_check "$file" 2>&1)"; rc=$?
  if ((rc == 1)) && [[ $out == *"$needle"* ]]; then
    ok=$((ok + 1)); printf '  ok   %s\n' "$desc"
  else
    bad=$((bad + 1)); printf '  FAIL %s (rc=%s, out=%q, harus memuat %q)\n' \
      "$desc" "$rc" "$out" "$needle"
  fi
}

GOOD='mode = "dark"
accent = "#cc1515"
background = "#0a0a0a"
dark_background = "#080808"
foreground = "#e8e8e8"'

printf '%s\n' "$GOOD" > "$TMP/good.toml"
expect_rc "palette sesuai -> lolos" 0 palette_check "$TMP/good.toml"

printf '%s\n' "$GOOD" | sed 's/#cc1515/#ff0000/' > "$TMP/drift.toml"
expect_msg "accent berubah -> sebut drift" "$TMP/drift.toml" "drift palet: accent"

printf '%s\n' "$GOOD" | grep -v '^accent' > "$TMP/hilang.toml"
expect_msg "slot hilang -> sebut nama slot" "$TMP/hilang.toml" 'slot "accent" tidak ada'

expect_msg "file tidak ada -> sebut path" "$TMP/tidak-ada.toml" "tidak ditemukan"

# Hex huruf besar di colors.toml harus tetap dikenali. Nama slot tetap lowercase:
# justru nama slot yang dibesarkan akan gagal, dan itu memang tidak didukung.
printf '%s\n' 'mode = "dark"
accent = "#CC1515"
background = "#0A0A0A"
dark_background = "#080808"
foreground = "#E8E8E8"' > "$TMP/besar.toml"
expect_rc "huruf besar pada hex tetap dikenali" 0 palette_check "$TMP/besar.toml"

printf '\n  %d ok, %d gagal\n' "$ok" "$bad"
[[ $bad -eq 0 ]]