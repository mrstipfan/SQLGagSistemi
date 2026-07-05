<p align="center">
  <a href="https://csarea.org">
    <img
      src="https://csarea.org/storage/uploads/2026/06/650x-20260620-155413-3c6836ef06.png"
      alt="CSArea"
      width="650"
    >
  </a>
</p>

<h1 align="center">CSArea SQL GAG Sistemi</h1>

<p align="center">
  Counter-Strike 1.6 sunucuları için SQL tabanlı chat ve mikrofon susturma sistemi.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Sürüm-3.1-red" alt="Sürüm 3.1">
  <img src="https://img.shields.io/badge/Yapımcı-Onur%20MrStipFan%20MASALCI-black" alt="Yapımcı">
  <img src="https://img.shields.io/badge/Dil-Pawn-orange" alt="Pawn">
  <img src="https://img.shields.io/badge/Veritabanı-MySQL%20%7C%20MariaDB-blue" alt="MySQL veya MariaDB">
  <img src="https://img.shields.io/badge/Platform-AMX%20Mod%20X-green" alt="AMX Mod X">
</p>

---

## İçindekiler

- [Proje Hakkında](#proje-hakkında)
- [Öne Çıkan Özellikler](#öne-çıkan-özellikler)
- [Gag Türleri](#gag-türleri)
- [Çalışma Mantığı](#çalışma-mantığı)
- [Gereksinimler](#gereksinimler)
- [Dosya Yapısı](#dosya-yapısı)
- [Kurulum](#kurulum)
- [Veritabanı Kullanıcısı Oluşturma](#veritabanı-kullanıcısı-oluşturma)
- [Yapılandırma](#yapılandırma)
- [Komutlar](#komutlar)
- [Yetki Sistemi](#yetki-sistemi)
- [Menü Sistemi](#menü-sistemi)
- [Kötü Kelime Sistemi](#kötü-kelime-sistemi)
- [Sunucuya Giriş Özellikleri](#sunucuya-giriş-özellikleri)
- [SQL Tablo Yapısı](#sql-tablo-yapısı)
- [Ses Engelleme Sistemi](#ses-engelleme-sistemi)
- [Log ve Ses Dosyaları](#log-ve-ses-dosyaları)
- [Güvenlik Önerileri](#güvenlik-önerileri)
- [Derleme](#derleme)
- [Sorun Giderme](#sorun-giderme)
- [Teknik Notlar](#teknik-notlar)
- [Geliştirici](#geliştirici)

---

## Proje Hakkında

**CSArea SQL GAG Sistemi**, Counter-Strike 1.6 sunucularında oyuncuların yazılı sohbetini, mikrofon kullanımını veya her ikisini birden süreli ya da kalıcı olarak engellemek için geliştirilmiş bir AMX Mod X eklentisidir.

Gag kayıtları MySQL veya MariaDB veritabanında saklanır. Oyuncu sunucudan ayrılıp yeniden bağlansa bile SteamID/AuthID veya IP adresi üzerinden aktif gag kaydı tekrar yüklenir.

Eklenti ayrıca oyun içi menüler, özelleştirilebilir gag sebepleri ve süreleri, otomatik kötü kelime denetimi, sunucuya girişte otomatik gag, HUD duyuruları, ses efektleri ve ayrıntılı log sistemi içerir.

Bu sürümde proje bilgileri SQL Ban sistemiyle eşitlenmiştir:

```pawn
#define PLUGIN  "[SQL GAG] Sistemi"
#define VERSION "3.1"
#define AUTHOR  "Onur MrStipFan MASALCI"
```

## Öne Çıkan Özellikler

- MySQL/MariaDB tabanlı kalıcı gag kayıtları
- SteamID/AuthID ve IP üzerinden gag kontrolü
- Sadece chat gag
- Sadece mikrofon gag
- Chat ve mikrofonu aynı anda engelleme
- Süreli gag desteği
- Kalıcı gag desteği
- Oyun içi gag ve ungag menüsü
- Konsoldan doğrudan gag uygulama
- Aktif gag kayıtlarını listeleme
- Bütün gag kayıtlarını temizleme
- Özelleştirilebilir gag sebepleri
- Özelleştirilebilir gag süreleri
- Özelleştirilebilir menü başlıkları
- Özelleştirilebilir yönetici yetkileri
- Otomatik kötü kelime algılama
- Kötü kelime kullanımında otomatik gag
- Sunucuya girişte otomatik gag seçeneği
- Gaglı oyuncu bağlandığında genel duyuru
- Gaglı oyuncuya bağlantı bilgilendirmesi
- Yönetici muafiyeti seçeneği
- Her haritada bir defa otomatik gag seçeneği
- Chat renk kodu desteği
- HUD bilgilendirmesi
- Gag, ungag ve süre dolma sesleri
- Dosya tabanlı işlem logları
- Süresi dolan kayıtları periyodik temizleme
- Yeni round başlangıcında isteğe bağlı yeniden kontrol
- Bot ve HLTV istemcilerini hariç tutma
- SQL tablosunu otomatik oluşturma

---

## Gag Türleri

Eklenti üç farklı gag türünü destekler:

| Değer | Tür | Davranış |
|---:|---|---|
| `0` | Chat Gag | Oyuncunun `say` ve `say_team` mesajlarını engeller |
| `1` | Mikrofon Gag | Oyuncunun sesli iletişimini engeller |
| `2` | Chat + Mikrofon Gag | Yazılı ve sesli iletişimi birlikte engeller |

Kaynak kodda kullanılan sabitler:

```pawn
enum _:GagTypeEnum
{
    TYPE_CHAT = 0,
    TYPE_VOICE,
    TYPE_BOTH
};
```

SQL kayıtlarında ayrıca okunabilir gag türü metni saklanır:

```text
Chat Gag
Mikrofon Gag
Chat + Mikrofon Gag
```

---

## Çalışma Mantığı

Eklentinin temel çalışma akışı:

1. `panel_sqlgagsistemi.ini` yapılandırma dosyası okunur.
2. Dosya bulunamazsa varsayılan yapılandırma otomatik oluşturulur.
3. Menü, sebep, süre, erişim, HUD, log, ses ve bağlantı ayarları belleğe alınır.
4. Eklenti SQL sunucusuna bağlanır.
5. `gag_sistemi` tablosu yoksa otomatik oluşturulur.
6. Oyuncu sunucuya girdiğinde yerel gag durumu sıfırlanır.
7. Belirlenen gecikme sonrasında SteamID/AuthID ve IP ile SQL sorgusu yapılır.
8. Aktif gag bulunursa oyuncunun gag türü, sebebi, yöneticisi ve bitiş zamanı yüklenir.
9. Mikrofon gag türlerinde `set_speak(..., SPEAK_MUTED)` uygulanır.
10. Yazılı gag türlerinde `say` ve `say_team` mesajları engellenir.
11. Süresi dolan gag kayıtları periyodik görevle SQL tablosundan silinir.
12. Oyuncunun yerel durumu temizlenir ve iletişim hakkı geri açılır.

Kalıcı gag kayıtlarında:

```text
expire_time = 0
```

Süreli gag kayıtlarında:

```text
expire_time = mevcut Unix zamanı + dakika × 60
```

---

## Gereksinimler

- Counter-Strike 1.6 HLDS veya ReHLDS
- AMX Mod X
- AMX Mod X MySQL/SQLX modülü
- `sqlx.inc`
- `engine.inc`
- MySQL veya MariaDB sunucusu
- Oyun sunucusundan veritabanına ağ erişimi
- Veritabanında tablo oluşturma ve kayıt yönetme izinleri

Kaynak kod aşağıdaki include dosyalarını kullanır:

```pawn
#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <engine>
```

`modules.ini` içinde gerekli modüllerin etkin olduğundan emin olun:

```ini
mysql
engine
```

Sunucunuzdaki modül dosya adları AMX Mod X sürümüne ve işletim sistemine göre değişebilir.

---

## Dosya Yapısı

Önerilen kurulum:

```text
cstrike/
└── addons/
    └── amxmodx/
        ├── configs/
        │   ├── panel_sqlgagsistemi.ini
        │   ├── plugins.ini
        │   └── modules.ini
        ├── plugins/
        │   └── panel_sqlgagsistemi.amxx
        ├── scripting/
        │   └── panel_sqlgagsistemi.sma
        └── logs/
            └── gagsystem.log
```

Özel ses dosyaları kullanılacaksa:

```text
cstrike/
└── sound/
    └── csarea/
        ├── gag.wav
        ├── ungag.wav
        └── gag_expired.wav
```

---

## Kurulum

### 1. Kaynak kodu derleyin

```bash
cd addons/amxmodx/scripting
./amxxpc panel_sqlgagsistemi.sma
```

Derlenen dosya:

```text
compiled/panel_sqlgagsistemi.amxx
```

### 2. AMXX dosyasını yükleyin

```text
addons/amxmodx/plugins/panel_sqlgagsistemi.amxx
```

### 3. plugins.ini dosyasına ekleyin

```ini
panel_sqlgagsistemi.amxx
```

### 4. Modülleri kontrol edin

```text
amxx modules
```

MySQL/SQLX ve Engine modüllerinin çalıştığını doğrulayın.

### 5. Sunucuyu başlatın

İlk çalıştırmada şu dosya otomatik oluşturulur:

```text
addons/amxmodx/configs/panel_sqlgagsistemi.ini
```

### 6. SQL bilgilerini düzenleyin

```ini
[Database]
DB_HOST = sql.csarea.net
DB_USER = kullanici_adi
DB_PASS = guclu_parola
DB_NAME = veritabani_adi
```

### 7. Sunucuyu yeniden başlatın

Bu eklentide ayrı bir config reload komutu bulunmadığı için yapılandırma değişikliklerinden sonra harita değiştirmeniz veya sunucuyu yeniden başlatmanız önerilir.

---

## Veritabanı Kullanıcısı Oluşturma

Aşağıdaki örneği kendi sisteminize göre değiştirin:

```sql
CREATE DATABASE csarea_gags
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER 'csarea_gag'@'OYUN_SUNUCUSU_IP'
  IDENTIFIED BY 'GUCLU_BIR_PAROLA';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE
  ON csarea_gags.*
  TO 'csarea_gag'@'OYUN_SUNUCUSU_IP';

FLUSH PRIVILEGES;
```

Eklentinin mevcut işlemleri `UPDATE` sorgusu kullanmasa da ilerideki genişletmeler ve yönetim paneli uyumluluğu için veritabanı seviyesinde sınırlı `UPDATE` yetkisi verilebilir.

> [!WARNING]
> Oyun sunucusunda MySQL `root` hesabını kullanmayın. SQL portunu bütün internete açmayın.

---

## Yapılandırma

Yapılandırma dosyası:

```text
addons/amxmodx/configs/panel_sqlgagsistemi.ini
```

### Database

```ini
[Database]
DB_HOST = sql.csarea.net
DB_USER = srv212_100_185_
DB_PASS =
DB_NAME = srv212_100_185_
```

| Ayar | Açıklama |
|---|---|
| `DB_HOST` | MySQL/MariaDB sunucusu |
| `DB_USER` | SQL kullanıcı adı |
| `DB_PASS` | SQL parolası |
| `DB_NAME` | Kullanılacak veritabanı |

Tablo adı kaynak kodda sabittir:

```pawn
new const g_szTableName[] = "gag_sistemi";
```

### Menu

```ini
[Menu]
MENU_PREFIX = \r[\ySQL GAG SISTEMI\r]
MENU_GAGS_TITLE = Oyuncu Sec:
MENU_REASONS_TITLE = Sebep Sec:
MENU_TIMES_TITLE = Sure Sec:
MENU_TYPES_TITLE = Gag Turu Sec:
```

Bu alanlar oyun içi menü başlıklarını belirler.

AMX Mod X menü renkleri:

```text
\r = kırmızı
\y = sarı
\w = beyaz
\d = gri
```

### Chat

```ini
[Chat]
CHAT_PREFIX = &x04[SQL-GAG]&x01
```

Desteklenen renk kodları:

```text
&x04 = yeşil
&x03 = takım rengi
&x01 = normal renk
```

### Reasons

```ini
[Reasons]
REASON_1 = \r*\w Ozel Sebep...|Ozel Sebep
REASON_2 = \y*\w Spam|Spam
REASON_3 = \y*\w Hakaret/Asagilama|Hakaret/Asagilama
REASON_4 = \y*\w Reklam|Reklam
```

Her satır iki parçadan oluşur:

```text
Menüde görünen metin|SQL ve duyurularda kullanılacak temiz metin
```

İlk sebep özel sebep girişi için kullanılmaktadır. Yönetici bu seçeneği seçtiğinde:

```text
messagemode gag_custom_reason
```

açılır.

### Sureler

```ini
[Sureler]
TIME_1 = \r5 \wdakika|5
TIME_2 = \y15 \wdakika|15
TIME_3 = \y30 \wdakika|30
TIME_4 = \w1 \ysaat|60
TIME_10 = \rKalici|0
```

Biçim:

```text
Menüde görünen metin|dakika
```

`0` değeri kalıcı gag anlamına gelir.

### GagTypes

```ini
[GagTypes]
TYPE_1 = \w*\y Sadece Chat|Chat
TYPE_2 = \w*\r Sadece Ses|Voice
TYPE_3 = \w*\g Chat + Ses|Chat + Voice
```

Kaynak kodda en fazla üç gag türü bulunur.

> [!NOTE]
> Gag türlerinin işlem değeri menü sırasına göre belirlenir. Sıralamayı değiştirmek davranışı da değiştirebilir.

### HUD

```ini
[HUD]
HUD_X = -1.0
HUD_Y = 0.25
HUD_HOLDTIME = 5.0
HUD_FADEIN = 0.1
HUD_FADEOUT = 0.2
HUD_EFFECT = 2
```

| Ayar | Açıklama |
|---|---|
| `HUD_X` | Yatay konum. `-1.0` merkezleme sağlar. |
| `HUD_Y` | Dikey konum |
| `HUD_HOLDTIME` | Mesajın ekranda kalma süresi |
| `HUD_FADEIN` | Giriş animasyonu |
| `HUD_FADEOUT` | Çıkış animasyonu |
| `HUD_EFFECT` | HUD efekti |

HUD rengi kaynak kodda kırmızı tonlu olarak tanımlıdır:

```pawn
set_hudmessage(255, 50, 50, ...);
```

### Gorevler

```ini
[Gorevler]
CHECK_EXPIRED_INTERVAL = 30.0
DOUBLE_CHECK_DELAY = 1.0
VOICE_BLOCKING_DELAY = 2.0
```

| Ayar | Açıklama |
|---|---|
| `CHECK_EXPIRED_INTERVAL` | Süresi dolan gagları kontrol etme aralığı |
| `DOUBLE_CHECK_DELAY` | Oyuncu bağlandıktan sonra SQL gag kontrol gecikmesi |
| `VOICE_BLOCKING_DELAY` | Mikrofon engelini ikinci kez uygulama gecikmesi |

### Erisim

```ini
[Erisim]
GAG_ACCESS = ADMIN_SLAY
UNGAG_ACCESS = ADMIN_SLAY
CLEAN_ACCESS = ADMIN_RCON
LIST_ACCESS = ADMIN_SLAY
```

| Ayar | Açıklama |
|---|---|
| `GAG_ACCESS` | Gag uygulama ve gag menüsü |
| `UNGAG_ACCESS` | Ungag menüsü |
| `CLEAN_ACCESS` | Bütün gag kayıtlarını temizleme |
| `LIST_ACCESS` | Aktif gag listesini görüntüleme |

Desteklenen sabit isimlere örnekler:

```text
ADMIN_IMMUNITY
ADMIN_KICK
ADMIN_BAN
ADMIN_SLAY
ADMIN_MAP
ADMIN_CVAR
ADMIN_CFG
ADMIN_CHAT
ADMIN_VOTE
ADMIN_RCON
ADMIN_LEVEL_A - ADMIN_LEVEL_H
ADMIN_MENU
ADMIN_ADMIN
ADMIN_USER
```

Doğrudan AMXX bayrağı da kullanılabilir:

```ini
GAG_ACCESS = e
```

### Kotu Kelimeler

```ini
[Kotu Kelimeler]
ENABLED = 1
GAG_TIME = 20
GAG_TYPE = 2
WORD_1 = gay
WORD_2 = idiot
WORD_3 = stupid
```

| Ayar | Açıklama |
|---|---|
| `ENABLED` | Kötü kelime denetimini açar veya kapatır |
| `GAG_TIME` | Otomatik gag süresi, dakika |
| `GAG_TYPE` | `0`, `1` veya `2` gag türü |
| `WORD_N` | Engellenecek kelime veya ifade |

Kötü kelime kontrolü büyük/küçük harfe duyarsızdır ve mesaj içinde parça eşleşmesi kullanır.

### Limitler

```ini
[Limitler]
MAX_REASONS = 50
MAX_TIMES = 50
MAX_BAD_WORDS = 50
```

Kaynak kod üst sınırları:

| İçerik | Kaynak kod üst sınırı |
|---|---:|
| Sebep | `50` |
| Süre | `50` |
| Gag türü | `3` |
| Kötü kelime | `100` |

### Logs

```ini
[Logs]
LOGS_ENABLED = 1
LOGS_FILE = gagsystem.log
```

Log dosyası AMX Mod X log klasörüne yazılır:

```text
addons/amxmodx/logs/gagsystem.log
```

### Sounds

```ini
[Sounds]
GAG_SOUND =
UNGAG_SOUND =
EXPIRE_GAG_SOUND =
```

Örnek:

```ini
GAG_SOUND = csarea/gag.wav
UNGAG_SOUND = csarea/ungag.wav
EXPIRE_GAG_SOUND = csarea/gag_expired.wav
```

Dosyalar `sound/` dizinine göre belirtilmelidir:

```text
sound/csarea/gag.wav
```

### Kontroller

```ini
[Kontroller]
ENABLE_CHECKS = 1
```

Etkin olduğunda her yeni round başlangıcında bağlı oyuncuların aktif gag kayıtları yeniden kontrol edilir.

### Baglanti

```ini
[Baglanti]
ANNOUNCE_EXISTING_GAG_ON_JOIN = 1
SHOW_JOIN_INFO_TO_PLAYER = 1
JOIN_INFO_SECONDS = 120
AUTO_GAG_ON_JOIN_ENABLED = 0
AUTO_GAG_ON_JOIN_MINUTES = 2
AUTO_GAG_ON_JOIN_TYPE = 0
AUTO_GAG_ON_JOIN_REASON = Ilk giris susturma
AUTO_GAG_ON_JOIN_ANNOUNCE_ALL = 0
AUTO_GAG_ONLY_ONCE_PER_MAP = 1
AUTO_GAG_SKIP_ADMINS = 1
```

Bu bölüm ayrıntılı olarak [Sunucuya Giriş Özellikleri](#sunucuya-giriş-özellikleri) başlığında açıklanmıştır.

---

## Komutlar

### Konsol komutları

| Komut | Yetki | Açıklama |
|---|---|---|
| `csa_gag <nick> <dakika> <tür> <sebep>` | `GAG_ACCESS` | Oyuncuya doğrudan gag uygular |
| `csa_gagmenu` | `GAG_ACCESS` | Gag menüsünü açar |
| `csa_ungagmenu` | `UNGAG_ACCESS` | Gag kaldırma menüsünü açar |
| `csa_cleangags` | `CLEAN_ACCESS` | SQL tablosundaki bütün gagları temizler |
| `csa_gaglist` | `LIST_ACCESS` | Aktif gag kayıtlarını sohbette listeler |

### Gag komutu kullanımı

```text
csa_gag <nick> <dakika> <tür> <sebep>
```

Türler:

```text
0 = Chat Gag
1 = Mikrofon Gag
2 = Chat + Mikrofon Gag
```

Örnekler:

```text
csa_gag Player 30 0 Spam
csa_gag Player 60 1 Mikrofon spam
csa_gag Player 120 2 Kufur ve hakaret
csa_gag Player 0 2 Kalici iletisim yasagi
```

`0` dakika kalıcı gag oluşturur.

Sebep en az üç karakter olmalıdır.

### Sohbet komutları

Gag menüsü:

```text
/gagmenu
!gagmenu
.gagmenu
```

Ungag menüsü:

```text
/ungagmenu
!ungagmenu
.ungagmenu
```

Bu komutlar hem `say` hem de `say_team` üzerinden kayıtlıdır.

---

## Yetki Sistemi

Eklenti hem sembolik AMX Mod X erişim adlarını hem de doğrudan harf bayraklarını destekler.

Varsayılanlar:

| İşlem | Varsayılan erişim |
|---|---|
| Gag uygulama | `ADMIN_SLAY` |
| Ungag | `ADMIN_SLAY` |
| Bütün gagları temizleme | `ADMIN_RCON` |
| Aktif gag listesi | `ADMIN_SLAY` |

Örnek:

```ini
[Erisim]
GAG_ACCESS = ADMIN_BAN
UNGAG_ACCESS = ADMIN_BAN
CLEAN_ACCESS = ADMIN_RCON
LIST_ACCESS = ADMIN_CHAT
```

`csa_cleangags` bütün SQL gag tablosunu temizlediği için bu yetki yalnızca üst düzey yöneticilerde bulunmalıdır.

---

## Menü Sistemi

Gag menüsü şu sırayla ilerler:

```text
Oyuncu seç
   ↓
Sebep seç
   ↓
Gag türü seç
   ↓
Süre seç
   ↓
Gag uygula
```

### Oyuncu menüsü

- Bağlı gerçek oyuncuları listeler.
- Bot ve HLTV kullanıcılarını göstermez.
- Halihazırda gaglı oyuncuları `[GAGLI]` etiketiyle gösterir.

### Sebep menüsü

- INI dosyasındaki `REASON_N` satırlarını kullanır.
- İlk madde özel sebep girişini açabilir.
- Özel sebep `gag_custom_reason` komutuyla alınır.

### Tür menüsü

- Chat
- Mikrofon
- Chat + Mikrofon

### Süre menüsü

- INI dosyasındaki `TIME_N` değerlerini kullanır.
- `0` kalıcı gagdır.

### Ungag menüsü

- Yalnızca o anda sunucuda bulunan ve yerel olarak gaglı görünen oyuncuları listeler.
- Oyuncunun SQL kaydını SteamID/AuthID veya IP üzerinden siler.
- Ses engeli varsa kaldırır.
- Genel sohbet ve HUD duyurusu gösterir.

---

## Kötü Kelime Sistemi

Kötü kelime denetimi `say` ve `say_team` mesajlarında çalışır.

İşlem sırası:

1. Mesaj okunur.
2. Büyük/küçük harf farkı kaldırılır.
3. INI dosyasındaki her `WORD_N` değeri kontrol edilir.
4. Kelime mesaj içinde bulunursa mesaj engellenir.
5. Oyuncuya sistem tarafından gag uygulanır.
6. SQL kaydı `SYSTEM` yöneticisiyle oluşturulur.
7. Gag bütün oyunculara duyurulur.

Otomatik sebep örneği:

```text
Kotu Kelime (yasakli_kelime)
```

> [!WARNING]
> Mevcut sistem parça eşleşmesi kullanır. Örneğin kısa bir kelime başka bir normal kelimenin içinde geçiyorsa yanlış eşleşme oluşabilir. Kötü kelime listesini mümkün olduğunca belirgin ifadelerden oluşturun.

Kötü kelime sistemi yalnızca henüz gaglı olmayan oyunculara yeni gag uygular.

---

## Sunucuya Giriş Özellikleri

### Mevcut gagı duyurma

```ini
ANNOUNCE_EXISTING_GAG_ON_JOIN = 1
```

Oyuncu aktif gag kaydıyla bağlandığında bütün oyunculara şu bilgiler duyurulabilir:

- Oyuncu adı
- Gag türü
- Kalıcı veya kalan süre
- Gag sebebi

### Oyuncuya bağlantı bilgisi gösterme

```ini
SHOW_JOIN_INFO_TO_PLAYER = 1
JOIN_INFO_SECONDS = 120
```

Gaglı oyuncuya bağlantı sonrasında gag türü ve sebebi bildirilir.

### Sunucuya girişte otomatik gag

```ini
AUTO_GAG_ON_JOIN_ENABLED = 1
AUTO_GAG_ON_JOIN_MINUTES = 2
AUTO_GAG_ON_JOIN_TYPE = 0
AUTO_GAG_ON_JOIN_REASON = Ilk giris susturma
```

Bu seçenek, aktif gag kaydı bulunmayan oyuncuya sunucuya girişte otomatik gag uygular.

Tür değerleri:

```text
0 = Chat
1 = Mikrofon
2 = Chat + Mikrofon
```

### Otomatik gag duyurusu

```ini
AUTO_GAG_ON_JOIN_ANNOUNCE_ALL = 1
```

Etkin olduğunda sistem gagı bütün oyunculara duyurulur.

### Haritada bir defa uygulama

```ini
AUTO_GAG_ONLY_ONCE_PER_MAP = 1
```

Oyuncu için otomatik gagın aynı harita süresince yeniden uygulanmasını önlemeyi amaçlar.

### Yöneticileri hariç tutma

```ini
AUTO_GAG_SKIP_ADMINS = 1
```

Kaynak kodda `ADMIN_KICK` bayrağına sahip oyuncular otomatik giriş gagından muaf tutulur.

---

## SQL Tablo Yapısı

Eklenti aşağıdaki tabloyu otomatik oluşturur:

```text
gag_sistemi
```

| Alan | Tür | Açıklama |
|---|---|---|
| `id` | `INT` | Otomatik artan kayıt numarası |
| `authid` | `VARCHAR(35)` | Oyuncunun SteamID/AuthID değeri |
| `player_ip` | `VARCHAR(32)` | Oyuncunun IP adresi |
| `player_name` | `VARCHAR(32)` | Oyuncu adı |
| `admin_name` | `VARCHAR(32)` | Gag uygulayan yönetici veya `SYSTEM` |
| `reason` | `VARCHAR(128)` | Gag sebebi |
| `gag_minutes` | `INT` | Uygulanan toplam dakika |
| `expire_time` | `INT` | Unix bitiş zamanı, `0` kalıcı |
| `gag_type` | `INT` | `0`, `1` veya `2` |
| `gag_type_text` | `VARCHAR(64)` | Okunabilir gag türü |
| `created_at` | `INT` | Unix oluşturulma zamanı |

İndeksler:

```text
PRIMARY KEY (id)
KEY authid
KEY player_ip
KEY expire_time
```

### Aktif gag sorgusu

Aktif kayıt koşulu:

```sql
expire_time = 0 OR expire_time > mevcut_zaman
```

Oyuncu eşleşmesi:

```sql
authid = oyuncu_authid OR player_ip = oyuncu_ip
```

En yeni kayıt:

```sql
ORDER BY id DESC LIMIT 1
```

### Yeni gag uygulanırken

Aynı SteamID/AuthID veya IP için eski kayıtlar önce silinir:

```sql
DELETE FROM gag_sistemi
WHERE authid = ? OR player_ip = ?;
```

Ardından yeni kayıt eklenir.

### Süresi dolan kayıtlar

Periyodik görev şu mantıkla kayıtları siler:

```sql
DELETE FROM gag_sistemi
WHERE expire_time > 0
  AND expire_time <= mevcut_zaman;
```

---

## Ses Engelleme Sistemi

Mikrofon gag için AMX Mod X Engine modülünün `set_speak` işlevi kullanılır.

Engelleme:

```pawn
set_speak(id, SPEAK_MUTED);
```

Kaldırma:

```pawn
set_speak(id, SPEAK_NORMAL);
```

Ses gagı uygulandığında ilk engellemeden sonra `VOICE_BLOCKING_DELAY` kadar gecikmeyle ikinci kez kontrol uygulanır. Bu yöntem bazı bağlantı ve istemci durumlarında ses engelinin daha kararlı kalmasına yardımcı olur.

Oyuncu sunucudan ayrıldığında veya gagı kaldırıldığında gecikmeli görev temizlenir.

---

## Log ve Ses Dosyaları

### Log sistemi

Etkinleştirme:

```ini
[Logs]
LOGS_ENABLED = 1
LOGS_FILE = gagsystem.log
```

Örnek loglar:

```text
Admin Yönetici oyuncu Player için 30 dakika süreyle 'Spam' sebebiyle gag uyguladı
Admin Yönetici oyuncu Player üzerindeki gag'i kaldırdı
Oyuncu Player için gag süresi doldu
SYSTEM oyuncu Player için girişte otomatik gag uyguladı
```

Log satırları tarih ve saat bilgisiyle yazılır.

### Ses sistemi

```ini
[Sounds]
GAG_SOUND = csarea/gag.wav
UNGAG_SOUND = csarea/ungag.wav
EXPIRE_GAG_SOUND = csarea/gag_expired.wav
```

Boş bırakılan ses ayarı devre dışıdır.

Sesler `plugin_precache()` aşamasında yüklenir. Dosya yolu yanlışsa harita yüklenirken hata oluşabilir.

> [!IMPORTANT]
> Ses ayarını değiştirdikten sonra yalnızca config yeniden okumak yeterli değildir. Precache işlemi harita başlangıcında yapıldığı için harita değişimi veya sunucu yeniden başlatma gerekir.

---

## Güvenlik Önerileri

### SQL parolasını depoya eklemeyin

`.gitignore`:

```gitignore
panel_sqlgagsistemi.ini
addons/amxmodx/configs/panel_sqlgagsistemi.ini
```

Örnek dosya:

```text
panel_sqlgagsistemi.example.ini
```

### Kısıtlı SQL kullanıcısı kullanın

- MySQL `root` hesabını kullanmayın.
- Kullanıcıyı yalnızca ilgili veritabanıyla sınırlandırın.
- Kaynak IP kısıtlaması uygulayın.
- MySQL portunu güvenlik duvarında yalnızca oyun sunucularına açın.
- Her fiziksel sunucu veya müşteri grubu için ayrı hesap kullanmayı değerlendirin.

### Toplu temizleme yetkisini koruyun

```ini
CLEAN_ACCESS = ADMIN_RCON
```

`csa_cleangags` komutu bütün gag kayıtlarını fiziksel olarak siler. İşlem için ikinci onay ekranı bulunmaz.

### INI dosyası izinleri

Linux örneği:

```bash
chown oyunuser:oyunuser addons/amxmodx/configs/panel_sqlgagsistemi.ini
chmod 600 addons/amxmodx/configs/panel_sqlgagsistemi.ini
```

Kullanıcı ve grup adını sisteminize göre değiştirin.

### Kötü kelime listesini kontrollü oluşturun

Çok kısa parçalar yanlış pozitif sonuçlara neden olabilir. Listeyi test sunucusunda doğrulamadan canlı sisteme uygulamayın.

---

## Derleme

### Linux

```bash
cd addons/amxmodx/scripting
./amxxpc panel_sqlgagsistemi.sma
```

### Windows

```bat
amxxpc.exe panel_sqlgagsistemi.sma
```

Başarılı derleme çıktısı:

```text
panel_sqlgagsistemi.amxx
```

Gerekli include dosyaları:

```text
amxmodx.inc
amxmisc.inc
sqlx.inc
engine.inc
```

Derlenmiş dosyayı yükleyin:

```text
addons/amxmodx/plugins/panel_sqlgagsistemi.amxx
```

---

## Sorun Giderme

### Eklenti `bad load` veriyor

Kontrol edin:

```text
amxx plugins
amxx modules
```

Muhtemel nedenler:

- MySQL modülü kapalı
- Engine modülü kapalı
- AMXX dosyası yanlış klasörde
- Derleme sürümü sunucuyla uyumsuz

### SQL bağlantısı kurulamıyor

Log örneği:

```text
[SQL-GAG] SQL baglanti hatasi: ...
```

Kontrol listesi:

- `DB_HOST` doğru mu?
- `DB_USER` doğru mu?
- `DB_PASS` doğru mu?
- `DB_NAME` mevcut mu?
- Oyun sunucusu SQL portuna ulaşabiliyor mu?
- SQL kullanıcısının kaynak IP izni var mı?
- MySQL/MariaDB dış bağlantıları kabul ediyor mu?
- Güvenlik duvarı erişime izin veriyor mu?

### Tablo oluşmuyor

SQL kullanıcısında `CREATE` yetkisi bulunmalıdır.

Tablo adı:

```text
gag_sistemi
```

### Oyuncu yeniden bağlanınca gag yüklenmiyor

Kontrol edin:

- SQL kaydı mevcut mu?
- `expire_time` geçmiş mi?
- SteamID/AuthID doğru mu?
- IP değişmiş mi?
- `DOUBLE_CHECK_DELAY` çok düşük mü?
- SQL bağlantısı kurulmuş mu?
- Oyuncu bot veya HLTV olarak mı algılanıyor?

### Chat gag çalışıyor ama ses gag çalışmıyor

Kontrol edin:

- Engine modülü etkin mi?
- Gag türü gerçekten `1` veya `2` mi?
- Oyuncunun SQL kaydındaki `gag_type` doğru mu?
- Başka bir eklenti `set_speak` durumunu değiştiriyor mu?
- `VOICE_BLOCKING_DELAY` değerini test edin.

### Gag süresi dolduğu halde devam ediyor

Kontrol edin:

- Oyun sunucusu sistem saati doğru mu?
- SQL kaydındaki `expire_time` doğru mu?
- `CHECK_EXPIRED_INTERVAL` aşırı yüksek mi?
- Periyodik görev çalışıyor mu?
- Yeni round kontrolü kapalı mı?

### Kötü kelime sistemi normal kelimeleri engelliyor

Mevcut sürüm parça eşleşmesi kullanır. Çok kısa veya başka kelimelerin içinde geçen yasaklı ifadeleri listeden kaldırın.

### Ses dosyası hatası alıyorum

- Dosya gerçekten `cstrike/sound/` altında mı?
- INI içinde `sound/` öneki yazılmamalıdır.
- Dosya yolu ve büyük/küçük harf aynı mı?
- Dosya harita başlamadan önce mevcut mu?

Doğru örnek:

```ini
GAG_SOUND = csarea/gag.wav
```

Dosya:

```text
cstrike/sound/csarea/gag.wav
```

---

## Teknik Notlar

- Eklenti sürümü: `3.1`
- Yapımcı: `Onur MrStipFan MASALCI`
- Yapılandırma dosyası: `panel_sqlgagsistemi.ini`
- SQL tablosu: `gag_sistemi`
- Azami sebep sayısı: `50`
- Azami süre seçeneği: `50`
- Gag türü sayısı: `3`
- Azami kötü kelime sayısı: `100`
- Özel sebep asgari uzunluğu: `3`
- Oyuncu slot dizileri: `33`
- Kalıcı gag değeri: `expire_time = 0`
- Chat engelleme: `say` ve `say_team`
- Ses engelleme: `set_speak`
- Gag eşleşmesi: SteamID/AuthID veya IP
- Aktif gag kaydı: en yeni eşleşen kayıt
- Süresi dolan kayıtlar SQL tablosundan fiziksel olarak silinir
- Ungag işlemi SQL kaydını fiziksel olarak siler
- SQL bağlantısı mevcut kaynakta senkron `SQL_Connect` ile açılır
- SQL işlemleri mevcut kaynakta `SQL_PrepareQuery` ve `SQL_Execute` ile yürütülür
- SQL hata detayları AMX Mod X loglarına yazılır
- Ses dosyaları `plugin_precache` aşamasında yüklenir
- Otomatik sistem gaglarında yönetici adı `SYSTEM` olarak kaydedilir
- Bot ve HLTV oyuncuları bağlantı gag kontrolünün dışında tutulur

---

## Örnek Kullanım Senaryoları

### 30 dakika chat gag

```text
csa_gag Player 30 0 Spam
```

### 60 dakika mikrofon gag

```text
csa_gag Player 60 1 Mikrofon spam
```

### 2 saat chat ve mikrofon gag

```text
csa_gag Player 120 2 Kufur ve hakaret
```

### Kalıcı iletişim engeli

```text
csa_gag Player 0 2 Tekrarli agir ihlal
```

### Aktif gag listesini görüntüleme

```text
csa_gaglist
```

### Bütün gag kayıtlarını temizleme

```text
csa_cleangags
```

### Oyun içinden gag menüsü

```text
!gagmenu
```

### Oyun içinden ungag menüsü

```text
!ungagmenu
```

---

## Önerilen Depo Yapısı

```text
csarea-sql-gag/
├── README.md
├── LICENSE
├── .gitignore
├── panel_sqlgagsistemi.sma
└── panel_sqlgagsistemi.example.ini
```

Derlenmiş dosyayı doğrudan kaynak deposunda tutmak yerine GitHub Releases üzerinden yayımlayabilirsiniz.

---

## Geliştirici

**Onur “MrStipFan” MASALCI**

- Proje: CSArea SQL GAG Sistemi
- Sürüm: 3.1
- Platform: AMX Mod X / Counter-Strike 1.6
- Web: [CSArea.org](https://csarea.org)

---

<p align="center">
  <strong>CSArea</strong><br>
  Counter-Strike topluluğu ve oyun sunucusu çözümleri
</p>
