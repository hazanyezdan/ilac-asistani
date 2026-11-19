"""TİTCK SKRS e-Reçete ilaç listesinden (Excel) uygulamanın ilaç adı dosyasını üretir.

Kullanım:
  1. https://www.titck.gov.tr/dinamikmodul/43 adresinden en güncel
     "SKRS E-Reçete İlaç ve Diğer Farmasötik Ürünler Listesi" Excel dosyasını indirin.
  2. pip install openpyxl
  3. python3 tool/ilac_listesi_guncelle.py indirilen_dosya.xlsx

Çıktı: assets/ilaclar.tsv  (her satır: 13 haneli barkod <TAB> ilaç adı)
"""

import sys
from pathlib import Path

import openpyxl

SAYFALAR = ["AKTİF ÜRÜNLER LİSTESİ", "PASİF ÜRÜNLER LİSTESİ"]
CIKTI = Path(__file__).resolve().parent.parent / "assets" / "ilaclar.tsv"


def main(excel_yolu: str) -> None:
    kitap = openpyxl.load_workbook(excel_yolu, read_only=True)
    ilaclar: dict[str, str] = {}
    # Aktif ürünler önce gelir; aynı barkod pasif listede de varsa aktif ad kalır.
    for sayfa_adi in SAYFALAR:
        for satir in kitap[sayfa_adi].iter_rows(min_row=4, values_only=True):
            ad, barkod = satir[0], satir[1]
            if not ad or barkod is None:
                continue
            barkod = str(barkod).strip().split(".")[0]
            if not barkod.isdigit():
                continue
            barkod = barkod.zfill(13)
            ad = " ".join(str(ad).split())
            ilaclar.setdefault(barkod, ad)
    with CIKTI.open("w", encoding="utf-8") as dosya:
        for barkod in sorted(ilaclar):
            dosya.write(f"{barkod}\t{ilaclar[barkod]}\n")
    print(f"{len(ilaclar)} ilaç yazıldı: {CIKTI}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Kullanım: python3 tool/ilac_listesi_guncelle.py liste.xlsx")
    main(sys.argv[1])
