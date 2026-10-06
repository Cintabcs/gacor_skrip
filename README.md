# 🧠 Analisis Komparatif Kelayakan Sensor MyoWare Pasien Intraoperatif

**Judul Penelitian:** Analisis Komparatif Kelayakan Sensor MyoWare Sebagai Low-Cost Portable EMG untuk Klasifikasi Otot Pasien Intraoperatif Menggunakan Wilcoxon Signed Rank Test  
**Peneliti:** Bakhitah Cinta Syahirah | **NIM:** 235150301111037 | **Prodi:** Teknik Informatika, Universitas Brawijaya

---

## 📸 Tabel Master Pembacaan Alat Medis TOFscan (Ground Truth)

Berikut adalah data pembacaan langsung dari layar alat medis **IDMed TOFscan** untuk seluruh rekaman Pasien 10, Pasien 11, Pasien 12, dan Pasien 13:

| Pasien | Nama File | Rasio TOF (%) | Twitch Count | Mode Alat | Status Klinis TOF | Label Klasifikasi |
|:---:|---|:---:|:---:|:---:|---|:---:|
| **Pasien 10** | `P10_ANESTESI_HASIL.csv` | **60%** | `4/4` | Auto TOF | Pre-block / Baseline | Kontraksi |
| | `P10_DATA1_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P10_DATA2_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P10_DATA3_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P10_DATA4_HASIL.csv` | **0%** | `2/4` | Auto TOF | Moderate Block | Relaksasi |
| **Pasien 11** | `P11_ANESTESI_HASIL.csv` | **95%** | `4/4` | Auto TOF | Baseline / Normal | Kontraksi |
| | `P11_DATA1_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P11_DATA2_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P11_DATA3_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P11_DATA4_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| **Pasien 12** | `P12_ANESTESI_HASIL.csv` | **80%** | `4/4` | Auto TOF | Baseline / Normal | Kontraksi |
| | `P12_DATA1_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P12_DATA2_HASIL.csv` | **0%** | `1/4` | Auto TOF | Deep Block | Relaksasi |
| | `P12_DATA3_HASIL.csv` | **0%** | `2/4` | Auto TOF | Moderate Block | Relaksasi |
| | `P12_DATA4_HASIL.csv` | **37%** | `4/4` | Single TOF | Partial Recovery | Kontraksi |
| **Pasien 13** | `P13_ANESTESI_HASIL.csv` | **0%** | `0/4` | Auto TOF | Deep Block | Relaksasi |
| | `P13_DATA1_HASIL.csv` | **51%** | `4/4` | Single TOF | Partial Recovery | Kontraksi |
| | `P13_DATA2_HASIL.csv` | **36%** | `4/4` | Single TOF | Partial Recovery | Kontraksi |
| | `P13_DATA3_HASIL.csv` | **27%** | `4/4` | Single TOF | Partial Recovery | Kontraksi |
| | `P13_DATA4_HASIL.csv` | **0%** | `1/4` | Single TOF | Deep Block | Relaksasi |

---

## 📂 Struktur Project

```
utama/
├── Data_baru/                                 ← Data Mentah + Foto Alat TOFscan
│   ├── PASIEN 10_22-09/
│   ├── PASIEN 11_22-09/
│   ├── PASIEN 12_22-09/
│   └── PASIEN 13_ 05-10/
│
├── preprocessing/                             ← Pipeline Pengolahan Data MATLAB
│   ├── satu_preprocessing.m                   ← Bandpass (20-450Hz) + Notch (50Hz)
│   ├── dua_snr_preprocessed.m                 ← Perhitungan SNR desibel (dB)
│   ├── tiga_windowing_rms.m                   ← Sliding Windowing 200ms & Fitur RMS
│   └── versi_B/matlab/output/
│       ├── snr/snr_results.csv                ← Output Hasil Evaluasi SNR
│       └── features/feature_summary.csv       ← Output Ringkasan Fitur RMS & Kelas
│
├── penjelasan.md                              ← Dokumentasi Metodologi Lengkap
└── README.md                                  ← Ringkasan Utama Project
```

---

## 🛠️ Cara Menjalankan Pipeline MATLAB

1. Jalankan **`satu_preprocessing.m`** untuk filtering sinyal EMG.
2. Jalankan **`dua_snr_preprocessed.m`** untuk menghitung SNR sinyal bersih.
3. Jalankan **`tiga_windowing_rms.m`** untuk windowing 200 ms & ekstraksi fitur RMS.
