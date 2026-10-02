# Negatsugumori

Tema Omarchy bernuansa Tsugumori (Knights of Sidonia) — merah `#cc1515` di atas
hitam `#0a0a0a`, dengan lock screen, bar, dan launcher menu yang reskin penuh.

## Instalasi

```bash
git clone https://github.com/semakusut/omarchy-negatsugumori-theme
cd omarchy-negatsugumori-theme
```

1. Di Omarchy: **Install → Theme → negatsugumori**. Ini yang memasang palet.
2. `./install.sh` — menimpa file root-owned, memasang hook dan sudoers.
3. `omarchy restart shell`

Font terminal (opsional, paket sistem — bukan file di repo ini):

```bash
omarchy-install-font "IBM Plex Mono Nerd" ttf-ibmplex-mono-nerd
```

## Apa yang ikut berubah

Semua ini **di-render otomatis** dari `colors.toml` oleh `omarchy-theme-set-templates`
— tidak ada file per-aplikasi di repo ini:

Alacritty, Foot, Ghostty, Kitty, btop, Chromium, Helix, Walker, Neovim (LazyVim +
Aether), VS Code, Claude, Pi, T3Code, Hyprland, keyboard RGB, Obsidian, shell.

Dan ini di-patch oleh `install.sh`:

- **Bar** — jam pill, logo kanji di menu, Workspaces, tombol widget
- **Launcher menu**
- **Lock screen** — semua fase, shader included

## Yang **tidak** ikut

Jujur, karena ini yang paling sering bikin orang kecewa:

- **fzf, lazygit, gitui, htop, delta, zoxide, starship** — Omarchy tidak punya
  template untuk mereka, jadi palet tidak bisa menjangkau. Butuh konfigurasi
  manual per aplikasi.
- **Background** — tidak dibundel. Pakai `Set Background` bawaan Omarchy.
- **Ikon** — `icons.theme` bawaan dipakai apa adanya.

## Lock screen perlu `install.sh`

Stock `LockView.qml` **hardcode** warnanya dan tidak membaca palet. Tanpa
`./install.sh`, lock screen tetap warna bawaan — bukan karena theme gagal, tapi
karena memang tidak ada jalur mewarnainya.

Tombol power tetap dua-klik: klik pertama menyiagakan, klik kedua menjalankan.
Guard `sessionLock.secure` bawaan Omarchy tidak pernah disentuh.

## Setiap `omarchy update`

Hook `post-update.d` mengembalikan file yang wipes oleh update. Sudoers dibuat
otomatis: 12 `cp` + 1 `mkdir`, tanpa wildcard. Cabut aksesnya dengan:

```bash
sudo rm /etc/sudoers.d/omarchy-tsugumori
```

Lalu `omarchy update` mengembalikan file asli.

## Palet

`colors.toml` adalah satu-satunya sumber warna. Empat warna jangkar di payload
QML dicek terhadapnya setiap kali `install.sh` jalan; kalau tidak cocok, install
dibatalkan. Ramp netral yang lain diwarisi dari lock screen bawaan Omarchy —
lihat [CREDITS.md](CREDITS.md).

## Uninstall

```bash
sudo rm /etc/sudoers.d/omarchy-tsugumori
rm ~/.config/omarchy/hooks/post-update.d/restore-tsugumori-*.hook
omarchy update
```

Lalu kembalikan tema lewat **Install → Theme** ke tema lain.

## Lisensi

MIT. Lihat [LICENSE](LICENSE) dan [CREDITS.md](CREDITS.md).