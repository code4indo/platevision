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

2. **Multi-class dataset**: Dataset produksi saat ini (`yolo_v3_production`) menggunakan 4 kelas: colony, bubble, dust, crack. Kelas artifact (bubble/dust/crack) ditambahkan secara sintetis untuk mengatasi false positive pada deteksi koloni.

3. **Dataset size**: Dataset produksi V4 (`yolo_v3_production`) berisi ~5,357 gambar, terdiri dari 3,357 gambar stratified split + 2,000 gambar synthetic colony augmentation (via `augment_colony_v2.py`). Dataset awal V1 hanya 294 gambar single-class.

4. **Image quality**: Gambar berasal dari berbagai sumber dengan pencahayaan, resolusi, dan kualitas yang bervariasi.

5. **Class imbalance mitigation**: Stratified split memastikan minimal 150 instance per kelas di validation set. Synthetic colony augmentation menambahkan 2,000 gambar colony untuk mengurangi class imbalance antara colony dan crack.
