# Redmine Note Clone

Bir işin altındaki notları, görselleriyle birlikte, başka işlere kopyalar.

[English](README.md)

## Yenilikler

* 0.1.0: İlk sürüm. Ayrıntı için [CHANGELOG](CHANGELOG.md).

## Ne yapar

* Notu olan bir işte, işlem menüsünde iki bağlantı görünür:
  * **Notları kopyala** sağdan bir yan panel açar.
  * **Doğrudan kopyala** paneli açmadan gönderir.
* Panelde her notun metni düzenlenebilir. Görseller tek tek seçilir.
* İlişkili işler seçili gelir. Üst iş ve alt işler listede durur, seçili gelmez.
* Yetkiniz olan başka bir iş, numarası yazılarak eklenir.
* Notun içindeki görseller hedef işe de eklenir ve metindeki dosya adı yeni ekle eşleşir.
* Doğrudan kopya, metni ve görselleri değiştirmeden, not ekleyebildiğiniz ilişkili işlere yazar. Onay kutusunda bu işler görünür.
* Yeni notu siz yazmış olursunuz. İsterseniz ilk satırda eski yazar ve tarih durur.
* Panelde **İlgililere bildirim gönder** işaretlenmezse izleyicilere posta gitmez.
* Arayüz İngilizce ve Türkçedir.

## Redmine sürümü

* 4.2.x ~ 6.x

Veritabanı migration’ı ve ek gem gerekmez.

## Kurulum

1. Redmine `plugins` dizininde:

```bash
git clone https://github.com/oten52/Redmine.NoteClone.git redmine_note_clone
```

2. Asset’leri kopyalayıp Redmine’ı yeniden başlatın:

```bash
bundle exec rake redmine:plugins:assets RAILS_ENV=production
```

Bağlantılar, notu olan bir işin işlem menüsünde görünür.

## Kaldırma

1. `plugins/redmine_note_clone` klasörünü silin.
2. Redmine’ı yeniden başlatın.

## Yazar

Niltek Arge — https://github.com/oten52

## Lisans

GNU General Public License v3.0 veya sonrası. Bakınız [LICENSE](LICENSE).
