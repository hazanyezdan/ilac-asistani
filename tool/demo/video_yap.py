"""demo_test.dart'ın ürettiği karelerden demo videosu hazırlar (simülasyon).

Kullanım: python3 tool/demo/video_yap.py <kare klasörü> <çıktı.mp4>

Gerekenler: Pillow, ffmpeg, espeak-ng (Türkçe ses), Flutter SDK'daki Roboto.
"""

import json
import math
import os
import random
import struct
import subprocess
import sys
import textwrap
import wave

from PIL import Image, ImageDraw, ImageFont

KLASOR, CIKTI = sys.argv[1], sys.argv[2]
GECICI = os.path.join(KLASOR, "video_gecici")
os.makedirs(GECICI, exist_ok=True)

FONTLAR = "/opt/sdk/flutter/bin/cache/artifacts/material_fonts"
EMOJI = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
W, H = 1080, 1920
ARKA = (16, 20, 24)
SARI = (255, 235, 59)


def font(boyut, kalin=False):
    ad = "Roboto-Bold.ttf" if kalin else "Roboto-Regular.ttf"
    return ImageFont.truetype(os.path.join(FONTLAR, ad), int(boyut))


def emoji_resmi(karakter, boyut):
    f = ImageFont.truetype(EMOJI, 109)
    im = Image.new("RGBA", (136, 128), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((0, 0), karakter, font=f, embedded_color=True)
    im = im.crop(im.getbbox())
    oran = boyut / im.height
    return im.resize((max(1, int(im.width * oran)), int(boyut)))


def satirlara_bol(metin, f, genislik, ciz):
    satirlar = []
    for parca in metin.split("\n"):
        kelimeler, satir = parca.split(), ""
        for k in kelimeler:
            dene = (satir + " " + k).strip()
            if ciz.textlength(dene, font=f) <= genislik:
                satir = dene
            else:
                satirlar.append(satir)
                satir = k
        satirlar.append(satir)
    return satirlar


# ---------------------------------------------------------------- telefon ekranı


def yazilari_duzelt(ekran, yazilar):
    """Test ortamının kutu çizdiği metinleri aynı yere Roboto ile yazar."""
    for y in yazilar:
        x0, y0, w, h = y["x"], y["y"], y["w"], y["h"]
        kirp = y.get("kirp") or [0, 0, ekran.width, ekran.height]
        katman = Image.new("RGBA", ekran.size, (0, 0, 0, 0))
        ciz = ImageDraw.Draw(katman)
        ornek_x = min(int(x0 + w + 14), ekran.width - 1)
        ornek_y = max(0, min(int(y0 + 4), ekran.height - 1))
        zemin = ekran.getpixel((ornek_x, ornek_y))
        ciz.rectangle([x0 - 4, y0 - 4, x0 + w + 8, y0 + h + 4], fill=zemin)
        renk = y["renk"]
        rgb = ((renk >> 16) & 255, (renk >> 8) & 255, renk & 255, 255)
        metin = y["metin"]
        f = font(y["boyut"], y["kalin"])
        emoji = None
        if "🎤" in metin:
            emoji = emoji_resmi("🎤", y["boyut"] * 0.9)
            metin = metin.replace("🎤", "").strip()
        yazi_g = ciz.textlength(metin, font=f) + (emoji.width + 16 if emoji else 0)
        bas_x = x0 + (w - yazi_g) / 2
        orta_y = y0 + h / 2
        if emoji:
            katman.alpha_composite(emoji, (int(bas_x), int(orta_y - emoji.height / 2)))
            bas_x += emoji.width + 16
        ciz.text((bas_x, orta_y), metin, font=f, fill=rgb, anchor="lm")
        maske = Image.new("L", ekran.size, 0)
        ImageDraw.Draw(maske).rectangle(kirp, fill=255)
        alfa = Image.composite(katman.getchannel("A"), Image.new("L", ekran.size, 0), maske)
        katman.putalpha(alfa)
        ekran.alpha_composite(katman)


def karekod_ciz(ciz, x, y, boyut, tohum):
    """Temsilî karekod deseni (gerçek bir kod değildir)."""
    n = 14
    m = boyut / n
    rnd = random.Random(tohum)
    ciz.rectangle([x - m, y - m, x + boyut + m, y + boyut + m], fill="white")
    for i in range(n):
        for j in range(n):
            dolu = (
                j == 0
                or i == n - 1
                or (i == 0 and j % 2 == 0)
                or (j == n - 1 and i % 2 == 1)
                or (0 < i < n - 1 and 0 < j < n - 1 and rnd.random() < 0.5)
            )
            if dolu:
                ciz.rectangle(
                    [x + j * m, y + i * m, x + (j + 1) * m, y + (i + 1) * m], fill="black"
                )


def kamera_ciz(ekran, alan, kamera, fener):
    x, y, w, h = alan["x"], alan["y"], alan["w"], alan["h"]
    katman = Image.new("RGB", (int(w), int(h)))
    ciz = ImageDraw.Draw(katman)
    acik = 70 if fener else 40
    for i in range(int(h)):
        ton = acik + int(25 * i / h)
        ciz.line([(0, i), (w, i)], fill=(ton, ton - 4, ton - 10))
    kutular = {
        "coraspin_uzak": ("CORASPIN", "100 mg", 0.08, 0.10, 0.22, True),
        "coraspin_yakin": ("CORASPIN", "100 mg", 0.18, 0.12, 0.64, True),
        "coraspin_on": ("CORASPIN®", "100 mg · 30 tablet", 0.10, 0.12, 0.80, False),
        "majezik": ("MAJEZIK", "100 mg", 0.18, 0.12, 0.64, True),
        "bilinmeyen": ("İLAÇ", "", 0.18, 0.12, 0.64, True),
    }
    if kamera in kutular:
        ad, doz, kx, ky, kw, kod = kutular[kamera]
        bx, by, bw = kx * w, ky * h, kw * w
        bh = bw * 0.62
        ciz.rounded_rectangle([bx, by, bx + bw, by + bh], radius=10, fill=(236, 240, 245))
        ciz.rectangle([bx, by, bx + bw, by + bh * 0.18], fill=(200, 30, 45))
        f = font(bw * 0.12, True)
        ciz.text((bx + bw * 0.06, by + bh * 0.26), ad, font=f, fill=(20, 30, 80))
        if doz:
            ciz.text((bx + bw * 0.06, by + bh * 0.46), doz, font=font(bw * 0.07), fill=(40, 40, 40))
        if kod:
            boyut = bh * 0.42
            karekod_ciz(ciz, bx + bw - boyut - bw * 0.08, by + bh - boyut - bh * 0.1, boyut, kamera)
    etiket = "Temsilî kamera görüntüsü" + (" (fener açık)" if fener else "")
    f = font(30)
    tg = ciz.textlength(etiket, font=f)
    ciz.rounded_rectangle([w - tg - 40, h - 62, w - 14, h - 14], radius=10, fill=(0, 0, 0))
    ciz.text((w - tg - 27, h - 38), etiket, font=f, fill=(255, 255, 255), anchor="lm")
    ekran.paste(katman, (int(x), int(y)))


def izin_penceresi_ciz(ekran, tur):
    karart = Image.new("RGBA", ekran.size, (0, 0, 0, 150))
    ekran.alpha_composite(karart)
    ciz = ImageDraw.Draw(ekran)
    w = ekran.width
    x0, x1 = 70, w - 70
    y0 = 760
    ciz.rounded_rectangle([x0, y0, x1, y0 + 820], radius=48, fill=(238, 242, 247))
    soru = (
        "İlaç Asistanı uygulamasının ses kaydetmesine izin verilsin mi?"
        if tur == "mikrofon"
        else "İlaç Asistanı uygulamasının fotoğraf çekmesine ve video kaydetmesine izin verilsin mi?"
    )
    f = font(52)
    yy = y0 + 70
    for satir in satirlara_bol(soru, f, x1 - x0 - 120, ciz):
        ciz.text((w / 2, yy), satir, font=f, fill=(25, 28, 32), anchor="mt")
        yy += 66
    yy += 40
    for i, d in enumerate(["Uygulamayı kullanırken", "Yalnızca bu sefer", "İzin verme"]):
        renk = (200, 225, 255) if i == 0 else (225, 230, 238)
        ciz.rounded_rectangle([x0 + 50, yy, x1 - 50, yy + 120], radius=60, fill=renk)
        ciz.text((w / 2, yy + 60), d, font=font(46, i == 0), fill=(20, 60, 140), anchor="mm")
        yy += 145
    ciz.text((w / 2, y0 - 50), "Android izin penceresi (temsilî)", font=font(40), fill=SARI, anchor="mm")


def bildirim_ciz(ekran, saat):
    ciz = ImageDraw.Draw(ekran)
    x0, x1, y0 = 40, ekran.width - 40, 60
    ciz.rounded_rectangle([x0, y0, x1, y0 + 420], radius=40, fill=(242, 244, 248))
    ciz.ellipse([x0 + 40, y0 + 40, x0 + 100, y0 + 100], fill=(255, 193, 7))
    ciz.text((x0 + 125, y0 + 70), "İlaç Asistanı · şimdi", font=font(36), fill=(70, 70, 80), anchor="lm")
    ciz.text((x0 + 40, y0 + 140), "İlaç zamanı", font=font(50, True), fill=(20, 20, 25))
    govde = f"Saat {saat}. Coraspin 100 miligram alma zamanı."
    yy = y0 + 210
    for satir in satirlara_bol(govde, font(44), x1 - x0 - 80, ciz):
        ciz.text((x0 + 40, yy), satir, font=font(44), fill=(40, 40, 50))
        yy += 56
    ciz.text((x0 + 40, y0 + 370), "ALDIM", font=font(40, True), fill=(20, 90, 200), anchor="lm")
    ciz.text((x0 + 260, y0 + 370), "ERTELE (10 DAKİKA)", font=font(40, True), fill=(20, 90, 200), anchor="lm")
    ciz.text((ekran.width / 2, y0 + 470), "Bildirim görünümü temsilîdir", font=font(36), fill=SARI, anchor="mm")


def telefon_ekrani(kare, kamera_alani):
    ekran = Image.open(kare["dosya"]).convert("RGBA")
    if kare.get("kameraAcik") and kamera_alani:
        kamera_ciz(ekran, kamera_alani, kare.get("kamera", "bos"), kare.get("fenerAcik"))
    yazilari_duzelt(ekran, kare.get("yazilar", []))
    if kare.get("izinPenceresi"):
        izin_penceresi_ciz(ekran, kare["izinPenceresi"])
    if kare.get("bildirim"):
        bildirim_ciz(ekran, kare.get("bildirimSaati", "09:00"))
    return ekran


# ---------------------------------------------------------------- video karesi


def rozet(ciz):
    f = font(34, True)
    metin = "SİMÜLASYON · gerçek telefon kaydı değildir"
    tg = ciz.textlength(metin, font=f)
    ciz.rounded_rectangle([(W - tg) / 2 - 24, 24, (W + tg) / 2 + 24, 80], radius=28, fill=(190, 30, 45))
    ciz.text((W / 2, 52), metin, font=f, fill="white", anchor="mm")


def video_karesi(kare, kamera_alani, sahne):
    tuval = Image.new("RGB", (W, H), ARKA)
    ciz = ImageDraw.Draw(tuval)
    rozet(ciz)
    if sahne:
        ciz.text((W / 2, 125), sahne, font=font(40, True), fill=SARI, anchor="mm")
    ekran = telefon_ekrani(kare, kamera_alani)
    yukseklik = 1330
    genislik = int(ekran.width * yukseklik / ekran.height)
    ekran = ekran.resize((genislik, yukseklik), Image.LANCZOS)
    px, py = (W - genislik) // 2, 165
    ciz.rounded_rectangle([px - 16, py - 16, px + genislik + 16, py + yukseklik + 16], radius=46, fill=(60, 64, 70))
    maske = Image.new("L", ekran.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle([0, 0, genislik, yukseklik], radius=34, fill=255)
    tuval.paste(ekran.convert("RGB"), (px, py), maske)

    tur = kare["tur"]
    baslik = {
        "uygulama": "🔊 Uygulama söylüyor:",
        "kullanici": "🗣 Kullanıcı:",
        "bip": "🔉 Bip sesleri:",
        "bilgi": "ℹ Açıklama:",
    }[tur]
    y0 = py + yukseklik + 40
    ciz.rounded_rectangle([30, y0, W - 30, H - 30], radius=30, fill=(32, 38, 46))
    simge, yazi = baslik.split(" ", 1)
    e = emoji_resmi(simge, 40)
    tuval.paste(e, (60, y0 + 24), e)
    ciz.text((60 + e.width + 14, y0 + 44), yazi, font=font(36, True), fill=SARI, anchor="lm")
    metin = kare["metin"]
    if tur in ("uygulama", "kullanici") and not metin.startswith("("):
        metin = f"“{metin}”"
    boyut = 40
    while True:
        f = font(boyut)
        satirlar = satirlara_bol(metin, f, W - 140, ciz)
        if len(satirlar) * (boyut + 12) <= H - 30 - (y0 + 80) - 10 or boyut <= 26:
            break
        boyut -= 2
    yy = y0 + 80
    for s in satirlar:
        ciz.text((60, yy), s, font=f, fill="white")
        yy += boyut + 12
    return tuval


def yazi_karti(baslik, satirlar, alt=None):
    tuval = Image.new("RGB", (W, H), ARKA)
    ciz = ImageDraw.Draw(tuval)
    rozet(ciz)
    yy = 640
    for s in satirlara_bol(baslik, font(70, True), W - 140, ciz):
        ciz.text((W / 2, yy), s, font=font(70, True), fill=SARI, anchor="mm")
        yy += 90
    yy += 40
    for parca in satirlar:
        for s in satirlara_bol(parca, font(42), W - 160, ciz):
            ciz.text((W / 2, yy), s, font=font(42), fill="white", anchor="mm")
            yy += 58
        yy += 20
    if alt:
        ciz.text((W / 2, H - 140), alt, font=font(34), fill=(160, 170, 180), anchor="mm")
    return tuval


# ---------------------------------------------------------------- ses


def sure(dosya):
    with wave.open(dosya) as w:
        return w.getnframes() / w.getframerate()


def konus(metin, dosya, kullanici=False):
    ses = ["-v", "tr+f3", "-p", "60", "-s", "150"] if kullanici else ["-v", "tr", "-s", "150"]
    subprocess.run(["espeak-ng", *ses, "-w", dosya, metin], check=True)
    return sure(dosya)


def sessizlik(dosya, saniye, hz=22050):
    with wave.open(dosya, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(hz)
        w.writeframes(b"\x00\x00" * int(saniye * hz))
    return saniye


def bip_sesi(dosya, aralik_ms, saniye=3.2, hz=22050):
    ornekler = []
    adim = aralik_ms / 1000
    for i in range(int(saniye * hz)):
        t = i / hz
        icinde = (t % adim) < 0.06
        ornekler.append(int(12000 * math.sin(2 * math.pi * 1500 * t)) if icinde else 0)
    with wave.open(dosya, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(hz)
        w.writeframes(b"".join(struct.pack("<h", o) for o in ornekler))
    return saniye


# ---------------------------------------------------------------- birleştirme


def parca_yap(resim, ses, saniye, ad):
    png = os.path.join(GECICI, ad + ".png")
    resim.save(png)
    mp4 = os.path.join(GECICI, ad + ".mp4")
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-i", png, "-i", ses,
            "-af", f"apad=whole_dur={saniye:.2f}", "-t", f"{saniye:.2f}",
            "-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p", "-r", "25",
            "-c:a", "aac", "-ar", "44100", "-ac", "1", "-b:a", "96k", mp4,
        ],
        check=True,
    )
    return mp4


def main():
    veri = json.load(open(os.path.join(KLASOR, "kareler.json")))
    alan = veri["kameraAlani"]
    parcalar = []
    no = 0

    def ekle(resim, ses, saniye):
        nonlocal no
        parcalar.append(parca_yap(resim, ses, saniye, f"p{no:03d}"))
        no += 1

    giris = (
        "İlaç Asistanı demo videosu. Bu bir simülasyondur, gerçek telefon kaydı "
        "değildir. Uygulamanın gerçek kodu test ortamında çalıştırıldı; kamera, "
        "mikrofon ve bildirim gibi telefon özellikleri taklit edildi."
    )
    wav = os.path.join(GECICI, "giris.wav")
    s = konus(giris, wav)
    ekle(
        yazi_karti(
            "İlaç Asistanı · Demo",
            [
                "Bu video bir SİMÜLASYONDUR; gerçek telefon kaydı değildir.",
                "Ekranlar ve uygulamanın söyledikleri, uygulamanın gerçek kodu "
                "Flutter test ortamında çalıştırılarak elde edildi.",
                "Kamera, mikrofon, izin pencereleri ve bildirimler taklit edildi; "
                "kamera görüntüsü, izin penceresi ve bildirim temsilî çizimdir.",
                "Ses, bilgisayardaki espeak-ng ile üretildi; telefonda Google "
                "Türkçe sesi çok daha doğal duyulur.",
            ],
        ),
        wav,
        s + 1.5,
    )

    sahne = None
    for kare in veri["kareler"]:
        tur = kare["tur"]
        if tur == "sahne":
            sahne = kare["metin"]
            wav = os.path.join(GECICI, f"s{no:03d}.wav")
            ekle(yazi_karti(sahne, []), wav, sessizlik(wav, 1.8))
            continue
        wav = os.path.join(GECICI, f"s{no:03d}.wav")
        if tur == "uygulama":
            saniye = konus(kare["metin"], wav) + 0.8
        elif tur == "kullanici":
            if kare["metin"].startswith("("):
                saniye = sessizlik(wav, 3.0)
            else:
                saniye = konus(kare["metin"], wav, kullanici=True) + 0.9
        elif tur == "bip":
            saniye = bip_sesi(wav, kare.get("bipAraligi", 600))
        else:
            saniye = sessizlik(wav, 4.5 if len(kare["metin"]) < 120 else 9.0)
        ekle(video_karesi(kare, alan, sahne), wav, max(saniye, 2.5))
        print(".", end="", flush=True)

    son = (
        "Demo bitti. Bu video bir simülasyondur. Uygulama henüz gerçek bir "
        "telefonda denenmedi; asıl deneme telefonda yapılmalıdır."
    )
    wav = os.path.join(GECICI, "son.wav")
    s = konus(son, wav)
    ekle(
        yazi_karti(
            "Demo bitti",
            [
                "Bu video bir simülasyondur.",
                "Uygulama henüz gerçek bir telefonda denenmedi; asıl deneme "
                "telefonda yapılmalıdır.",
            ],
            alt="github.com/hazanyezdan/ilac-asistani",
        ),
        wav,
        s + 2,
    )

    liste = os.path.join(GECICI, "liste.txt")
    with open(liste, "w") as f:
        for p in parcalar:
            f.write(f"file '{p}'\n")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", liste,
         "-c", "copy", "-movflags", "+faststart", CIKTI],
        check=True,
    )
    print(f"\n{len(parcalar)} parça → {CIKTI}")


if __name__ == "__main__":
    main()
