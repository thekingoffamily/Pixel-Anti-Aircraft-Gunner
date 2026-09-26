# Публикация в RuStore

Пошаговая инструкция для «Пиксельного Зенитчика». Всё, что нужно сделать до загрузки, — собрать подписанный APK/AAB и подготовить материалы карточки.

## 1. Что загружать

RuStore принимает APK и AAB. Для первой версии удобнее APK:

```powershell
pwsh -File build_apk.ps1 -InitAndroid
```

Файл появится в `build/app/outputs/flutter-apk/app-release.apk`.

Для AAB: `pwsh -File build_apk.ps1 -Bundle`.

Важно: Flutter по умолчанию подписывает release-сборку debug-ключом. Для публикации сделайте свой ключ (шаг 2) — иначе вы не сможете выпустить обновление с той же подписью.

## 2. Ключ подписи

Создание ключа и `android/key.properties`:

```powershell
pwsh -File build_apk.ps1 -NewKeystore -StorePass "ваш_пароль" -KeyPass "ваш_пароль"
```

Файлы `android/app/upload-keystore.jks` и `android/key.properties` попадают в `.gitignore` — их нельзя терять: без них нельзя обновить приложение в магазине. Сохраните копию в надёжном месте.

Дальше подключите подпись в Gradle один раз.

### Если шаблон Groovy (`android/app/build.gradle`)

Добавьте перед блоком `android {`:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Внутри блока `android {` добавьте:

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### Если шаблон Kotlin DSL (`android/app/build.gradle.kts`)

В начале файла:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Внутри `android {`:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}
buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

Проверить подпись готового APK:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

## 3. Иконка

Иконка приложения уже лежит в корне проекта — `logo-app.png` (2048x2048). Сгенерировать launcher-иконки:

```powershell
pwsh -File build_apk.ps1 -Icons
```

Ручной вариант:

```bash
flutter pub add --dev flutter_launcher_icons
```

Затем добавьте в `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "logo-app.png"
  min_sdk_android: 21
```

и выполните `dart run flutter_launcher_icons`.

Совет: в карточке RuStore требуется отдельная иконка 512x512 в PNG. Для неё лучше взять центральную часть логотипа (турель) без крупных надписей — так иконка читается на маленьком размере. Если позже понадобится adaptive icon, делайте foreground отдельным файлом с отступами (safe zone — центральные ~66%) и укажите `adaptive_icon_background` и `adaptive_icon_foreground`.

## 4. Материалы карточки

| Что нужно | Значение для этой игры |
|---|---|
| Название | Пиксельный Зенитчик |
| Короткое описание | `store/github_about.md` (вариант до 160 символов) |
| Полное описание | `store/rustore_description.txt` |
| Категория | Игры → Аркады |
| Возрастной рейтинг | 6+ (стилизованные взрывы, воздушные дроны; нет крови и людей) |
| Цена | Бесплатно |
| Реклама | Нет |
| Встроенные покупки | Нет |
| Интернет | Не требуется, разрешения на сеть нет |
| Данные пользователя | Не собираются; хранятся только рекорд и настройки на устройстве |
| Политика конфиденциальности | Не требуется, если данные не собираются; при желании можно приложить короткий текст |

Скриншоты нужно снять с работающего приложения (4–8 штук, вертикальные, например 1080x1920): главное меню, бой с волной дронов, экран улучшений, бой с боссом, экран финала с рекордом.

## 5. Технические требования

- `versionCode` и `versionName` берутся из `pubspec.yaml` (`version: 0.1.0+1`). Для каждой загрузки в RuStore увеличивайте обе части, например `0.1.1+2`.
- `targetSdkVersion` в новых версиях Flutter уже соответствует требованиям магазинов. Если RuStore попросит поднять его, задайте значение в `android/app/build.gradle(.kts)`.
- APK не должен быть debuggable — release-сборка Flutter таким не является.
- Проверьте на устройстве: сворачивание ставит игру на паузу, звук и вибрация переключаются в меню.

## 6. Куда положить описание

- `store/rustore_description.txt` — текст для карточки RuStore;
- `store/github_about.md` — короткие описания и теги для GitHub (`About`, topics).

## 7. Бесплатная версия и платные функции

В 0.1.0 весь контент бесплатный: рекламы, покупок и ограничений нет. Когда появится платная часть, безопасные точки расширения:

- `lib/engine/upgrades.dart` — добавить платные улучшения отдельным списком;
- `lib/ui/overlays.dart` — экран магазина;
- `lib/services/storage.dart` — флаги приобретённого состояния.

Код движка от биллинга не зависит, так что подключать покупки можно отдельным этапом.
