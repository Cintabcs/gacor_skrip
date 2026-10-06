# 📋 Penjelasan Lengkap Proposal Skripsi
**Judul:** Analisis Komparatif Kelayakan Sensor MyoWare Sebagai Low-Cost Portable EMG untuk Klasifikasi Otot Pasien Intraoperatif Menggunakan Wilcoxon Signed Rank Test

**Nama:** Bakhitah Cinta Syahirah | **NIM:** 235150301111037 | **Prodi:** Teknik Informatika, Universitas Brawijaya

---

## 🧠 Intinya Penelitian Ini Tentang Apa?

Saat pasien dioperasi, dokter anestesi menyuntikkan obat pelemas otot (NMBA) agar pasien tidak bergerak. Masalahnya, setelah operasi selesai, kadang otot belum pulih sepenuhnya — ini berbahaya karena bisa menyebabkan gangguan napas.

Untuk memantau apakah otot sudah pulih atau belum, biasanya dokter pakai alat bernama **TOF Scan** (mahal, ~jutaan rupiah). 

**Ide penelitian kamu:** apakah sensor **MyoWare** (murah, portabel) bisa dijadikan *alternatif* TOF Scan untuk memantau kondisi otot pasien saat operasi?

---

## 🎯 Dua Pertanyaan Utama yang Harus Dijawab

1. **Seberapa sesuai** bacaan sensor MyoWare dibandingkan TOF Scan?
2. **Apakah ada perbedaan signifikan** secara statistik antara hasil klasifikasi kondisi otot (Relaksasi vs Kontraksi) antara MyoWare dan TOF Scan?

---

## 🗺️ Alur Lengkap Penelitian (Step by Step)

Berikut adalah **8 langkah** yang tertulis di Bab 3 Metodologi proposal (Halaman 18, poin 1–8):

---

### ✅ LANGKAH 1 — Evaluasi Kualitas Sinyal (SNR)
**Status: SELESAI ✅**

**Apa:** Menghitung nilai **Signal-to-Noise Ratio (SNR)** dalam satuan desibel (dB) pada sinyal RAW hasil akuisisi.

**Kenapa dilakukan dulu sebelum filtering?**
Untuk mengetahui *"seberapa layak"* data mentah yang sudah direkam. Kalau SNR-nya sangat buruk, artinya rekaman kemungkinan gagal (elektroda lepas, banyak gangguan).

**Rumus:**
```
SNR (dB) = 10 × log₁₀ (P_sinyal / P_noise)
```
- P_sinyal = daya sinyal EMG bersih (setelah difilter)
- P_noise  = daya sisa noise (RAW - sinyal bersih)

**Hasil yang sudah didapat:**
- 55 file berhasil dihitung SNR-nya
- SNR rata-rata: **5.33 dB**
- SNR tertinggi: **8.79 dB** (P11_DATA3)
- SNR terendah: **-4.30 dB** (Hasil20260919_210646) → rekaman awal, kemungkinan elektroda belum stabil

**Output:** `preprocessing/testing/output/snr/snr_results.csv`

---

### ✅ LANGKAH 2 — Preprocessing Sinyal
**Status: SELESAI ✅**

**Apa:** Membersihkan sinyal EMG dari gangguan menggunakan dua filter secara berurutan.

#### Filter 1: Band-pass Filter (Butterworth 20–450 Hz)
- **Mempertahankan** frekuensi 20–450 Hz (rentang sinyal otot asli)
- **Membuang** frekuensi < 20 Hz (gerak kabel, baseline drift) dan > 450 Hz (noise elektronik)
- Pakai metode **zero-phase filtering** (`filtfilt`) agar tidak ada pergeseran fase

#### Filter 2: Notch Filter (50 Hz)
- Khusus membuang gangguan jala-jala listrik PLN (50 Hz di Indonesia)
- Tanpa filter ini, sinyal akan ada "denyutan" 50 Hz dari colokan listrik di kamar operasi

**Pipeline:**
```
RAW EMG → Band-pass (20–450 Hz) → Notch (50 Hz) → Preprocessed EMG
```

**Hasil yang sudah didapat:**
- 55 dari 56 file berhasil diproses
- 1 file di-skip (`Hasil20260922_121908.csv`, hanya 19 baris data — rekaman gagal)
- Output tersimpan di: `preprocessing/testing/output/data/`
- Visualisasi plot tersimpan di: `preprocessing/testing/output/plots/`

---

### ⏭️ LANGKAH 3 — Segmentasi / Windowing
**Status: BELUM — NEXT STEP**

**Apa:** Memotong sinyal EMG yang panjang menjadi potongan-potongan kecil (disebut "jendela" atau *window*).

**Kenapa perlu?** Sinyal EMG bisa berlangsung puluhan menit. Kita tidak bisa hitung RMS dari keseluruhan rekaman sekaligus — nanti hasilnya cuma satu angka untuk seluruh operasi. Kita perlu tahu kondisi otot *dari waktu ke waktu*.

**Contoh:** Kalau pakai window 1 detik dengan overlap 50%:
- Window 1: detik 0.0 – 1.0
- Window 2: detik 0.5 – 1.5
- Window 3: detik 1.0 – 2.0
- dst...

**Parameter yang perlu ditentukan:**
- Panjang window (misal: 200 ms = 200 sampel pada Fs=1000 Hz)
- Overlap antar window (misal: 50%)

> 💡 *Referensi dari proposal kamu:* Sa'diah et al. (2025) pakai windowing pada data intraoperatif sebelum hitung RMS.

---

### ⏭️ LANGKAH 4 — Ekstraksi Fitur RMS
**Status: BELUM**

**Apa:** Dari setiap *window*, dihitung satu nilai **Root Mean Square (RMS)** yang merepresentasikan *"seberapa kuat aktivitas otot pada jendela waktu tersebut"*.

**Rumus:**
```
RMS = √(1/N × Σ xᵢ²)
```
Di mana:
- N = jumlah sampel dalam satu window
- xᵢ = nilai amplitudo sinyal pada sampel ke-i

**Hasil:** Satu nilai RMS per window → kalau rekaman 10 menit dengan window 1 detik, ada ±600 nilai RMS.

---

### ⏭️ LANGKAH 5 — Thresholding (Klasifikasi Kondisi Otot)
**Status: BELUM**

**Apa:** Setelah punya nilai RMS, tentukan ambang batas (*threshold*). Nilai RMS dinormalisasi terlebih dahulu, lalu dibandingkan ke threshold:

```
Jika RMS_norm < Threshold  → RELAKSASI
Jika RMS_norm ≥ Threshold  → KONTRAKSI
```

**Normalisasi:** `RMS_norm = RMS / RMS_max`

**Nilai threshold:** Berdasarkan referensi Sa'diah et al. (2025) dan Merbah et al. (2023) yang dipakai di proposal: **65%** (atau 0.65).

> Perlu diingat: threshold 65% ini bisa dieksplorasi dan dikalibrasi berdasarkan datamu sendiri nanti.

---

### ⏭️ LANGKAH 6 — Perbandingan dengan TOF Scan
**Status: BELUM (butuh data TOF Scan)**

**Apa:** Hasil klasifikasi MyoWare (Relaksasi/Kontraksi per window) dibandingkan dengan keputusan klinis dari **TOF Scan** pada waktu yang sama.

**Caranya:**
- TOF Ratio < 0.90 → Otot dalam kondisi **Relaksasi/terblokade**
- TOF Ratio ≥ 0.90 → Otot sudah **Kontraksi/pulih**

Kemudian dibuat tabel berpasangan:
| Waktu | MyoWare | TOF Scan |
|---|---|---|
| Menit ke-5 | Relaksasi | Relaksasi |
| Menit ke-15 | Kontraksi | Relaksasi |
| dst... | ... | ... |

> ⚠️ **Kamu perlu data TOF Scan dari rekaman operasi** untuk melanjutkan langkah ini!

---

### ⏭️ LANGKAH 7 — Uji Statistik Wilcoxon Signed Rank Test
**Status: BELUM**

**Apa:** Uji statistik non-parametrik untuk membuktikan secara matematis apakah perbedaan antara MyoWare dan TOF Scan **signifikan atau tidak**.

**Hipotesis:**
- H₀: Tidak ada perbedaan signifikan antara MyoWare dan TOF Scan *(MyoWare layak dipakai)*
- H₁: Ada perbedaan signifikan *(MyoWare tidak layak)*

**Keputusan:**
- **p-value > 0.05** → H₀ diterima → **MyoWare LAYAK** sebagai alternatif TOF Scan ✅
- **p-value ≤ 0.05** → H₀ ditolak → Ada perbedaan signifikan ❌

> Tingkat signifikansi α = 0.05 (sesuai Bab 3.7 proposal)

---

### ⏭️ LANGKAH 8 — Analisis Hasil & Kesimpulan
**Status: BELUM**

**Apa:** Menarik kesimpulan dari seluruh hasil analisis:
- Apakah SNR-nya cukup baik?
- Apakah preprocessing berhasil membersihkan sinyal?
- Apakah klasifikasi MyoWare sesuai dengan TOF Scan?
- Apakah p-value > 0.05 (MyoWare layak)?

---

## 📊 Ringkasan Progress

| # | Langkah | Status |
|---|---|---|
| 1 | Evaluasi Kualitas Sinyal (SNR) | ✅ Selesai |
| 2 | Preprocessing (Band-pass + Notch) | ✅ Selesai |
| 3 | Segmentasi / Windowing | ⏭️ Selanjutnya |
| 4 | Ekstraksi Fitur RMS | ⏳ Menunggu |
| 5 | Thresholding (Relaksasi/Kontraksi) | ⏳ Menunggu |
| 6 | Perbandingan dengan TOF Scan | ⏳ Butuh data TOF |
| 7 | Uji Wilcoxon Signed Rank Test | ⏳ Menunggu |
| 8 | Analisis & Kesimpulan | ⏳ Menunggu |

---

## 📁 Struktur File yang Sudah Ada

```
C:\Users\FILKOM\Downloads\utama\
│
├── Data_baru/                          ← DATA RAW (JANGAN DIUBAH!)
│   └── [56 file CSV hasil rekaman]
│
├── preprocessing/
│   ├── matlab/
│   │   ├── preprocessing_emg.m        ← Kode MATLAB preprocessing
│   │   ├── snr_emg.m                  ← Kode MATLAB SNR
│   │   └── output/
│   │       ├── data/                  ← Hasil preprocessing MATLAB
│   │       └── plots/                 ← Visualisasi MATLAB
│   │
│   └── testing/
│       ├── preprocessing_emg.py       ← Kode Python preprocessing (SUDAH DIJALANKAN)
│       ├── snr_emg.py                 ← Kode Python SNR (SUDAH DIJALANKAN)
│       └── output/
│           ├── data/                  ← 55 file CSV sudah terfilter
│           ├── plots/                 ← Visualisasi time-domain & PSD
│           └── snr/
│               ├── snr_results.csv    ← Tabel SNR semua file
│               ├── snr_chart.png      ← Bar chart SNR
│               └── snr_histogram.png  ← Histogram distribusi SNR
│
└── Proposal Skripsi_...pdf            ← Dokumen proposal
```

---

## 💡 Catatan Penting

> **Kenapa SNR rata-rata hanya 5.33 dB?**
> Ini wajar untuk sensor MyoWare low-cost di lingkungan kamar operasi. Kamar operasi penuh dengan alat elektronik yang menghasilkan noise elektromagnetik. Garouche & Thamsuwan (2023) yang juga pakai MyoWare juga mencatat sensor ini *"lebih rentan noise"* dibanding alat research-grade. Nilai SNR ini justru menjadi temuan yang menarik untuk dibahas di skripsimu nanti.

> **Data TOF Scan ada di mana?**
> Data TOF Scan adalah data klinis yang dicatat secara manual atau dari alat TOF Scan selama operasi. Kamu perlu mengumpulkan/meminta data ini dari tim dokter anestesi RSUD Dr. Saiful Anwar Malang untuk bisa melanjutkan ke Langkah 6, 7, dan 8.

---

---

## 🔀 DUA VERSI PIPELINE YANG DIBUAT

Karena ada perbedaan urutan antara proposal dan pendekatan alternatif, dibuat **2 versi pipeline** lengkap beserta kode MATLAB dan Python-nya masing-masing.

---

### 📌 VERSI A — Sesuai Proposal (SNR dulu → Preprocessing)

```
RAW EMG (CSV)
     │
     ▼
[1] Evaluasi SNR pada RAW
     (menilai kualitas data SEBELUM difilter)
     │
     ▼
[2] Preprocessing
     ├── Band-pass Filter (20–450 Hz)
     └── Notch Filter (50 Hz)
     │
     ▼
[3] Windowing (potong-potong sinyal)
     │
     ▼
[4] Ekstraksi Fitur RMS per window
     │
     ▼
[5] Thresholding → Relaksasi / Kontraksi
     │
     ▼
[6] Bandingkan dengan TOF Scan
     │
     ▼
[7] Wilcoxon Signed Rank Test
     │
     ▼
[8] Kesimpulan
```

**File kode Versi A:**

| Bahasa | File | Fungsi |
|---|---|---|
| Python | `preprocessing/versi_A/python/1_snr_raw.py` | SNR pada RAW (Langkah 1) |
| Python | `preprocessing/versi_A/python/2_preprocessing.py` | Bandpass + Notch (Langkah 2) |
| Python | `preprocessing/versi_A/python/3_windowing_rms.py` | Windowing + RMS + Threshold (Langkah 3–5) |
| MATLAB | `preprocessing/versi_A/matlab/1_snr_raw.m` | SNR pada RAW (Langkah 1) |
| MATLAB | `preprocessing/versi_A/matlab/2_preprocessing.m` | Bandpass + Notch (Langkah 2) |
| MATLAB | `preprocessing/versi_A/matlab/3_windowing_rms.m` | Windowing + RMS + Threshold (Langkah 3–5) |

**Output Versi A:**
Jika kamu menjalankan script **Python**, hasilnya akan otomatis masuk ke dalam folder `preprocessing/versi_A/python/output/`.
Jika kamu menjalankan script **MATLAB**, hasilnya masuk ke folder `preprocessing/versi_A/matlab/output/`. 

Di dalam folder `output/` tersebut, isinya akan terbagi persis seperti ini:

```
output/
├── snr_raw/          ← OUTPUT LANGKAH 1 (Kualitas Sinyal Awal)
│   ├── snr_raw_results.csv   (Tabel nilai SNR untuk setiap file pasien)
│   ├── snr_raw_chart.png     (Grafik batang nilai SNR semua file)
│   └── snr_raw_histogram.png (Grafik persebaran nilai SNR)
│
├── data/             ← OUTPUT LANGKAH 2 (Sinyal yang Sudah Bersih)
│   └── [55 file CSV]         (File CSV baru yang sudah bersih dari noise 50Hz dll)
│
├── plots/            ← OUTPUT LANGKAH 2 (Visualisasi Filter)
│   └── [55 file PNG]         (Gambar grafik sebelum vs sesudah filter)
│
└── features/         ← OUTPUT LANGKAH 3-5 (Hasil Ekstraksi & Klasifikasi)
    ├── data/
    │   └── [55 file CSV]     (Isinya: Waktu, Nilai RMS, RMS_norm, dan Status Relaksasi/Kontraksi)
    ├── plots/
    │   └── [55 file PNG]     (Gambar grafik pergerakan otot & garis batas/threshold)
    └── feature_summary.csv   (Tabel ringkasan persentase kontraksi semua pasien)
```

---

### 📌 VERSI B — Alternatif (Preprocessing dulu → SNR)

```
RAW EMG (CSV)
     │
     ▼
[1] Preprocessing
     ├── Band-pass Filter (20–450 Hz)
     └── Notch Filter (50 Hz)
     │
     ▼
[2] Evaluasi SNR pada sinyal TERFILTER
     (menilai seberapa bersih sinyal setelah filter)
     │
     ▼
[3] Windowing (potong-potong sinyal)
     │
     ▼
[4] Ekstraksi Fitur RMS per window
     │
     ▼
[5] Thresholding → Relaksasi / Kontraksi
     │
     ▼
[6] Bandingkan dengan TOF Scan
     │
     ▼
[7] Wilcoxon Signed Rank Test
     │
     ▼
[8] Kesimpulan
```

**File kode Versi B:**

| Bahasa | File | Fungsi |
|---|---|---|
| Python | `preprocessing/versi_B/python/1_preprocessing.py` | Bandpass + Notch (Langkah 1) |
| Python | `preprocessing/versi_B/python/2_snr_preprocessed.py` | SNR pada hasil filter (Langkah 2) |
| Python | `preprocessing/versi_B/python/3_windowing_rms.py` | Windowing + RMS + Threshold (Langkah 3–5) |
| MATLAB | `preprocessing/versi_B/matlab/1_preprocessing.m` | Bandpass + Notch (Langkah 1) |
| MATLAB | `preprocessing/versi_B/matlab/2_snr_preprocessed.m` | SNR pada hasil filter (Langkah 2) |
| MATLAB | `preprocessing/versi_B/matlab/3_windowing_rms.m` | Windowing + RMS + Threshold (Langkah 3–5) |

**Output Versi B:**
Sama halnya dengan Versi A, hasilnya akan otomatis masuk ke folder `preprocessing/versi_B/python/output/` atau `preprocessing/versi_B/matlab/output/` tergantung kamu menjalankan script yang mana.

Di dalam folder `output/` tersebut, isinya akan terbagi persis seperti ini:

```
output/
├── data/             ← OUTPUT LANGKAH 1 (Sinyal yang Sudah Bersih)
│   └── [55 file CSV]         (File CSV baru yang sudah bersih dari noise)
│
├── plots/            ← OUTPUT LANGKAH 1 (Visualisasi Filter)
│   └── [55 file PNG]         (Gambar grafik sebelum vs sesudah filter)
│
├── snr/              ← OUTPUT LANGKAH 2 (Kualitas Sinyal Terfilter)
│   ├── snr_results.csv       (Tabel nilai SNR sinyal bersih)
│   ├── snr_chart.png         (Grafik batang nilai SNR semua file)
│   └── snr_histogram.png     (Grafik persebaran nilai SNR)
│
└── features/         ← OUTPUT LANGKAH 3-5 (Hasil Ekstraksi & Klasifikasi)
    ├── data/
    │   └── [55 file CSV]     (Isinya: Waktu, Nilai RMS, RMS_norm, dan Status Relaksasi/Kontraksi)
    ├── plots/
    │   └── [55 file PNG]     (Gambar grafik pergerakan otot & garis batas/threshold)
    └── feature_summary.csv   (Tabel ringkasan persentase kontraksi semua pasien)
```

---

### 🔍 Perbedaan Versi A vs Versi B

| Aspek | Versi A (Proposal) | Versi B (Alternatif) |
|---|---|---|
| **Urutan SNR** | Sebelum preprocessing | Setelah preprocessing |
| **SNR dihitung dari** | Sinyal RAW | Sinyal terfilter |
| **Tujuan SNR** | Evaluasi kualitas data mentah | Evaluasi efektivitas filter |
| **Sesuai proposal?** | ✅ Ya | ⚠️ Modifikasi |
| **Referensi** | Li et al. (2020), halaman 15 proposal | Umum dalam literatur biomedis |

---

## 🛠️ Implementation Plan (Urutan Eksekusi)

### Versi A — Urutan jalankan kode Python:
```
1. python preprocessing/versi_A/python/1_snr_raw.py
2. python preprocessing/versi_A/python/2_preprocessing.py
3. python preprocessing/versi_A/python/3_windowing_rms.py
```

### Versi B — Urutan jalankan kode Python:
```
1. python preprocessing/versi_B/python/1_preprocessing.py
2. python preprocessing/versi_B/python/2_snr_preprocessed.py
3. python preprocessing/versi_B/python/3_windowing_rms.py
```

---

## 📊 Konfigurasi Windowing & RMS

| Parameter | Nilai | Penjelasan |
|---|---|---|
| Sampling frequency (Fs) | 1000 Hz | Sesuai akuisisi MyoWare |
| Panjang window | 200 ms (200 sampel) | Standar EMG surface |
| Overlap | 50% (100 sampel) | Untuk kontinuitas temporal |
| Threshold | 0.65 (65%) | Referensi Sa'diah et al. (2025) |
| Normalisasi | RMS / RMS_max | Normalisasi terhadap nilai maksimum |

---

## 📁 Struktur File Lengkap (Update)

```
C:\Users\FILKOM\Downloads\utama\
│
├── Data_baru/                                  ← RAW (JANGAN DIUBAH)
│   └── [56 file CSV]
│
├── preprocessing/
│   ├── versi_A/                               ← Sesuai Proposal (SNR RAW)
│   │   ├── matlab/
│   │   │   ├── 1_snr_raw.m
│   │   │   ├── 2_preprocessing.m
│   │   │   └── 3_windowing_rms.m
│   │   └── python/
│   │       ├── 1_snr_raw.py
│   │       ├── 2_preprocessing.py
│   │       └── 3_windowing_rms.py
│   │
│   └── versi_B/                               ← Alternatif (SNR Filtered)
│       ├── matlab/
│       │   ├── 1_preprocessing.m
│       │   ├── 2_snr_preprocessed.m
│       │   └── 3_windowing_rms.m
│       └── python/
│           ├── 1_preprocessing.py
│           ├── 2_snr_preprocessed.py
│           └── 3_windowing_rms.py
│
├── penjelasan.md                              ← Dokumen ini
└── Proposal Skripsi_...pdf

