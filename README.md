# eNet App

<p align="center">
  <img src="assets/enet_logo.jpg" width="112" alt="eNet logo">
</p>

<p align="center"><strong>Одно пространство. Основа для будущих продуктов eNet.</strong></p>

<p align="center">
  <a href="https://github.com/enet-debug/enet-app/actions/workflows/ci.yml"><img src="https://github.com/enet-debug/enet-app/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/enet-debug/enet-app/actions/workflows/build-windows.yml"><img src="https://github.com/enet-debug/enet-app/actions/workflows/build-windows.yml/badge.svg" alt="Windows build"></a>
  <a href="https://github.com/enet-debug/enet-app/actions/workflows/build-ios.yml"><img src="https://github.com/enet-debug/enet-app/actions/workflows/build-ios.yml/badge.svg" alt="iOS build"></a>
</p>

**eNet App** — кроссплатформенная основа на Flutter для Windows и iPhone. Сейчас проект намеренно не привязан к конкретному каталогу, игре, модификациям или сервису: сначала закладываем качественный интерфейс и базовую архитектуру, а назначение приложения определим отдельно.

## Что уже есть

- Адаптивные экраны входа, регистрации и восстановления пароля.
- Главное меню: главная, уведомления, профиль и настройки.
- Боковая навигация на широком экране и нижняя панель на телефоне.
- Тёмная тема eNet, голубые акценты, мягкие свечения и анимированный орбитальный фон.
- Поддержка системной настройки уменьшения анимаций.
- Отдельный контракт `AuthRepository`, чтобы подключить реальную авторизацию без переписывания интерфейса.

## Важно: авторизация пока демонстрационная

Сейчас используется `DemoAuthRepository`: он принимает введённые данные для проверки интерфейса, не создаёт реальные аккаунты, не сохраняет пароли и не отправляет письма. Перед публичным выпуском необходимо подключить серверную авторизацию, подтверждение email, восстановление пароля и защищённое хранение сессий.

## Запуск локально

Требуется Flutter stable и Dart 3.6 или новее.

```bash
flutter create --platforms=windows,ios .
flutter pub get
flutter run -d windows
```

Для запуска на iPhone нужен Mac с Xcode:

```bash
flutter run -d ios
```

## Автоматические сборки

В репозитории настроены GitHub Actions:

| Workflow | Результат | Запуск |
|---|---|---|
| CI | Анализ Dart и widget-тесты | Push и Pull Request в `main` |
| Windows Build | ZIP с EXE, DLL и папкой данных | Вручную или по тегу `v*` |
| iOS Build | Не подписанный IPA | Вручную или по тегу `v*` |

Чтобы запустить сборку вручную: открой вкладку **Actions**, выбери нужный workflow и нажми **Run workflow**. Готовый файл появится в разделе **Artifacts** соответствующего запуска.

### Windows

Архив `eNet-Windows-x64.zip` содержит EXE и все файлы Flutter Runner, необходимые для запуска. Распакуй архив целиком и запускай `enet_app.exe`. Один EXE без DLL и папки `data` не является полной сборкой.

### iOS

Workflow собирает `eNet-iOS-unsigned.ipa` без подписи. Это технический пакет для дальнейшей подписи, а не готовый к обычной установке на iPhone файл. Для установки потребуется Apple Developer signing: Bundle ID, сертификат и provisioning profile. Секреты Apple нельзя коммитить в репозиторий.

## Структура

- `lib/core` — тема, логотип и фоновые эффекты.
- `lib/features/auth` — экран и слой авторизации.
- `lib/features/shell` — основная оболочка приложения.
- `assets` — графика бренда eNet.
- `.github/workflows` — CI и сборки Windows/iOS.

## План

1. Утвердить назначение и структуру будущего приложения.
2. Выбрать backend для аккаунтов eNet ID.
3. Подключить настоящую авторизацию и безопасное хранение сессии.
4. Развивать функциональные разделы, не ломая общую дизайн-систему.

---

© eNet Developer
