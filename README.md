Bukti last modified: https://github.com/cnotgate/this-triangle-will-die/blob/main/bukti-date-modified-file.png

# THIS TRIANGLE WILL DIE

Survive the unknown. Fight for your last breath.

Source code:

About The Game This Triangle Will Die is a tense 2D action side-scroller where precision is everything. You are trapped in a hostile environment, trying to survive against relentless enemies. Master your stamina, time your parries perfectly, and dodge through deadly attacks to stay alive.

Key Features

Brutal Combat System: Manage your stamina carefully. Every attack, dodge, and parry has a cost.
Perfect Parry Mechanic: Time your block perfectly to stun enemies, cancel their attacks, and open a window for a deadly counter-attack.
I-Frame Dodge: Dash straight through enemy bodies to reposition yourself safely. (Boss can't be dashed straight through)
Intense Boss Fight: Face off against a brutal boss with random attack patterns in a locked-down arena.
Controls

Move: Arrow Keys / A D
Jump: Space
Attack: Left Click
Parry & Block: Right Click
Dodge: Shift

## UAS Revisi Individual Game Challenge

Perubahan yang dilakukan: Menambahkan enemy baru (Diamond Enemy) dengan bentuk visual diamond dan pola serangan menerjang (*lunge/charge*), serta memperbaiki beberapa bug kritis terkait registrasi tabrakan dan area kematian.

Penjelasan Perubahan:

1. **Modifikasi Pendeteksian Kerusakan Player (`player.gd`)**:
   * Mengganti pengecekan kelompok (*group*) `"gatekeeper"` pada sinyal pedang menjadi pemeriksaan dinamis `.has_method("take_damage")`. Modifikasi ini memungkinkan Player untuk melukai jenis musuh baru mana pun tanpa mengharuskan musuh tersebut masuk kelompok penjaga gerbang.

2. **Pembuatan Scene dan Script Musuh Baru (`DiamondEnemy.tscn` & `diamond_enemy.gd`)**:
   * **Visual & Collider**: Menggunakan node `Polygon2D` berbentuk diamond sebagai representasi visual, dilengkapi dengan `CollisionShape2D` (fisika tubuh) dan `HurtBox` (penerima serangan).
   * **Pola Serangan Menerjang**: Menambahkan fungsionalitas `State.ATTACKING` yang mendorong musuh dengan kecepatan tinggi (`LUNGE_SPEED = 400.0`) dalam durasi singkat (`LUNGE_DURATION = 0.4` detik) ke arah posisi Player.
   * **Visual Feedback**: Mengubah properti `body.color` secara langsung pada node `Polygon2D` (Kuning saat bersiap/windup, Merah saat menerjang, Biru saat pusing/stunned) agar visualisasi pertarungan lebih intuitif tanpa mengacaukan warna bar HP.
   * **Statistik Lebih Mudah**: Memiliki kapasitas kesehatan lebih kecil (`HP = 25`), persiapan serang lebih lama (`0.8` detik), dan durasi pusing lebih lama (`2.5` detik) agar bersahabat bagi pemula.

3. **Perbaikan Masalah Hitbox Jarak Dekat Player (`player.tscn`)**:
   * Mengatur ulang posisi `CollisionShape2D` pada `SwordArea` menjadi `(0, -450)` dan memperbesar ukurannya. Hal ini menghilangkan *blind spot* (titik buta) di dekat tubuh Player agar musuh yang berada sangat dekat tetap dapat terkena serangan.

4. **Registrasi Tabrakan Pedang Dinamis (`player.gd`)**:
   * Menyinkronkan status keaktifan hitbox pedang (`sword_col.disabled`) secara berkala dengan siklus serangan. Hitbox dinonaktifkan (`true`) saat diam dan hanya diaktifkan (`false`) saat menyerang agar sinyal `area_entered` berhasil terpicu ketika menebas musuh yang menempel.

5. **Perbaikan Masalah Deteksi Jurang Kematian (`level1.tscn`)**:
   * Menyesuaikan konfigurasi **Collision Mask** milik `KillArea` menjadi **Layer 2** agar sejajar dengan posisi *collision layer* milik Player. Perubahan ini memastikan jurang kematian dapat mendeteksi jatuhnya Player dan memicu fungsi `die()` dengan tepat.
