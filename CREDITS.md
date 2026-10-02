# Credits

## Palet

Palet Tsugumori diambil dari **Tsugumori 1.0.0** oleh **samyns**
(Lisensi MIT), file `config/quickshell/theme/Theme.qml` dan `kitty.conf`.
`colors.toml` di repo ini adalah turunan langsung — bukan interpretasi ulang.

## Modifikasi

Perubahan, port ke QML, dan repo publik oleh **Aleph1-9012** (Lisensi MIT).

## Token yang diwarisi

Ramp netral pada `LockView.qml`, `FormationCorner.qml`, dan `PhaseArt.js`
bukan palet Tsugumori. Nilainya diambil dari stock
`/usr/share/omarchy/shell/plugins/lock/` bawaan Omarchy dan sengaja
dipertahankan supaya lock screen tetap terbaca. Hanya empat warna jangkar
yang diganti: `#0a0a0a`, `#080808`, `#cc1515`, `#e8e8e8`.

## Stock Omarchy

Template, CLI, dan struktur lock screen mengikuti Omarchy (GPL-3.0). Repo ini
tidak mendistribusikan kode Omarchy — hanya menimpanya lewat patch yang
di-restore `install.sh`.