# Data Sources - Plate Count Reader

## Dataset Overview

| # | Dataset | Ukuran | Jumlah Gambar | Format Anotasi | Lisensi |
|---|---------|--------|---------------|----------------|---------|
| 1 | AGAR | ~6.3 GB | 20,623 | Segmentation Masks | CC BY 4.0 |
| 2 | DIBaS | ~4.2 GB | 692 | Tidak ada (hanya gambar) | Academic |
| 3 | Microbial Colony Recognition | ~83 MB | 40 | JSON Bounding Box | CC0 |
| 4 | Figshare Colony Counting | ~500 MB | - | COCO JSON | CC BY 4.0 |

## Detail Sumber Data

### 1. AGAR - Annotated Germs in Agar Plates
- **Kaggle**: https://www.kaggle.com/datasets/clb2256095392/automatic-colony-counting
- **Website**: https://agar.neurosys.pl/
- **Paper**: "AGAR: A Microbial Colony Dataset for Deep Learning" (2022)
- **Konten**: 18,000+ gambar agar plate dengan berbagai tingkat kepadatan koloni
- **Anotasi**: Segmentation masks (dikonversi ke bounding box menggunakan connected components)
- **Catatan**: Dataset terbesar yang digunakan, mencakup berbagai jenis media agar

### 2. DIBaS - Digital Images of Bacterial Species
- **Kaggle**: https://www.kaggle.com/datasets/samaarashidaarbi/dibas-bacterial-colony-dataset
- **Website**: https://misztal.edu.pl/software/databases/dibas/
- **Konten**: 660+ gambar mikroskopis dari 33 spesies bakteri
- **Catatan**: Sebagian besar tidak memiliki anotasi bounding box; digunakan sebagai data augmentasi

### 3. Microbial Colony Recognition
- **Kaggle**: https://www.kaggle.com/datasets/zoya77/microbial-colony-recognition-dataset
- **Konten**: 40 gambar dengan JSON bounding box annotations
- **Format**: {"x": number, "y": number, "width": number, "height": number}

### 4. Figshare Colony Counting
- **URL**: https://figshare.com/articles/dataset/11332968
- **API**: https://api.figshare.com/v2/articles/11332968
- **Konten**: Dataset colony counting dengan COCO format annotations
- **Catatan**: Tidak berhasil didownload karena keterbatasan akses dari Kaggle

## Data Pipeline

```
Raw Data → Download → Extract → Convert to YOLOv8 → Split → Train/Val/Test
    │                                          │
    ├── AGAR: segmentation masks ────────────► scipy.ndimage.label → connected components → bbox
    ├── DIBaS: no annotations ──────────────► excluded from training (used for augmentation only)
    ├── Microbial: JSON bbox ───────────────► direct conversion (x,y,w,h → normalized cx,cy,nw,nh)
    └── Figshare: COCO JSON ────────────────► (not available - download failed)
```

## Data Quality Notes

1. **AGAR conversion**: Menggunakan `scipy.ndimage.label` untuk mengekstrak connected components dari segmentation masks. Hal ini menghasilkan bounding box yang akurat tetapi mungkin memasukkan noise sebagai koloni kecil.

2. **Class imbalance**: Hanya 1 kelas ("colony") - tidak ada distingsi antara spesies bakteri yang berbeda.

3. **Dataset size**: Total 294 gambar setelah konversi relatif kecil. Disarankan untuk memperbesar dataset di iterasi berikutnya.

4. **Image quality**: Gambar berasal dari berbagai sumber dengan pencahayaan, resolusi, dan kualitas yang bervariasi.
