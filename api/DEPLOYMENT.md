# Публичное развёртывание eNet API

Этот комплект подготавливает API для iOS, Windows и других клиентов через HTTPS. **Файлы не разворачивают сервер автоматически**: сначала нужен VPS с Ubuntu, доступ по SSH и DNS-доступ к домену.

## Предлагаемая схема

- API: `api.enet-dev.ru` (отдельная DNS-запись на IP VPS).
- Node.js API слушает только `127.0.0.1:8787`.
- Caddy принимает HTTPS на 443 и проксирует запросы на локальный API.
- SQLite хранится отдельно в `/var/lib/enet-api`, вне каталога исходников.
- Systemd перезапускает API после сбоя.

## Подготовка VPS

Установить Node.js 22.16+, Git и Caddy. Затем создать системного пользователя и каталоги:

```bash
sudo useradd --system --home /var/lib/enet-api --shell /usr/sbin/nologin enet-api
sudo install -d -o root -g root -m 0755 /opt/enet-app
sudo install -d -o root -g root -m 0750 /etc/enet-api
sudo install -d -o enet-api -g enet-api -m 0700 /var/lib/enet-api
```

Разместить исходники репозитория в `/opt/enet-app`. Каталог исходников должен быть доступен на чтение пользователю `enet-api`; запись разрешена только в `/var/lib/enet-api`.

Настроить переменные:

```bash
sudo cp /opt/enet-app/api/deploy/enet-api.env.example /etc/enet-api/enet-api.env
sudo chown root:enet-api /etc/enet-api/enet-api.env
sudo chmod 0640 /etc/enet-api/enet-api.env
```

Проверить путь к Node.js:

```bash
command -v node
node --version
```

Если Node.js находится не в `/usr/bin/node`, изменить `ExecStart` в `enet-api.service` на фактический путь.

Установить unit:

```bash
sudo cp /opt/enet-app/api/deploy/enet-api.service /etc/systemd/system/enet-api.service
sudo systemctl daemon-reload
sudo systemctl enable --now enet-api
sudo systemctl status enet-api
curl http://127.0.0.1:8787/ready
```

## Резервное копирование SQLite

Установить CLI и создать каталог резервных копий:

```bash
sudo apt install -y sqlite3
sudo install -d -o enet-api -g enet-api -m 0700 /var/backups/enet-api
sudo cp /opt/enet-app/api/deploy/enet-api-backup.service /etc/systemd/system/
sudo cp /opt/enet-app/api/deploy/enet-api-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now enet-api-backup.timer
sudo systemctl start enet-api-backup.service
sudo systemctl status enet-api-backup.service
```

Таймер запускает согласованную SQLite-копию раз в сутки, хранит локальные копии 14 дней. Проверять таймер: `systemctl list-timers enet-api-backup.timer`. Для защиты от потери самого VPS копии дополнительно следует выгружать в отдельное хранилище.

Восстановление из выбранной копии выполняется при остановленном API:

```bash
sudo systemctl stop enet-api
sudo cp /var/backups/enet-api/ИМЯ-КОПИИ.sqlite /var/lib/enet-api/enet.sqlite
sudo rm -f /var/lib/enet-api/enet.sqlite-wal /var/lib/enet-api/enet.sqlite-shm
sudo chown enet-api:enet-api /var/lib/enet-api/enet.sqlite
sudo chmod 0600 /var/lib/enet-api/enet.sqlite
sudo systemctl start enet-api
sudo systemctl status enet-api
curl http://127.0.0.1:8787/ready
```
```

## DNS и HTTPS

1. Создать DNS A-запись `api.enet-dev.ru` на публичный IPv4 VPS (и AAAA, только если IPv6 действительно настроен).
2. Разрешить входящие TCP 80 и 443 в firewall и панели VPS. Порт 8787 наружу **не открывать**.
3. Установить Caddy и скопировать `api/deploy/Caddyfile.example` в `/etc/caddy/Caddyfile`.
4. Проверить конфигурацию и перезапустить Caddy:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
curl https://api.enet-dev.ru/health
curl https://api.enet-dev.ru/ready
```

Caddy автоматически получает и обновляет сертификат при корректных DNS и доступных портах 80/443.

В API включён режим доверенного прокси только через `ENET_TRUST_PROXY=true`. В примере Caddy сам выставляет `X-Real-IP`; не включайте доверие к этому заголовку, если порт API доступен напрямую из интернета.

## Подключение приложений

После реального развёртывания указывать в eNet APP:

```
https://api.enet-dev.ru
```

На экране входа есть пункт «Настроить адрес API». Для удалённых адресов приложение разрешает только HTTPS. После смены сервера сохранённая сессия удаляется, чтобы токен не ушёл на другой API.

iOS-клиент не может использовать `127.0.0.1` компьютера с Linux. Ему нужен публичный HTTPS endpoint. Сам iOS build из GitHub Actions пока unsigned; для установки и App Store необходимы Apple signing credentials.

## Обслуживание и ограничения

- SQLite и WAL-файлы находятся в `/var/lib/enet-api`; включить ежедневные резервные копии и регулярно проверять восстановление.
- Счётчики rate limit хранятся в SQLite и переживают перезапуск одного экземпляра. Для нескольких экземпляров нужен Redis/совместимое общее хранилище.
- Перед публичной регистрацией нужны подтверждение email, реальное восстановление пароля, аудит, мониторинг и политика хранения данных.
- Сейчас каталог сервисов содержит Продайзер как внешний переход. Общая авторизация eNet ID с Продайзером **ещё не реализована**.
- Не добавлять в GitHub `enet-api.env`, приватные ключи, сертификаты, базу SQLite или резервные копии.

Развёртывание следует считать завершённым только после проверки HTTPS, `/ready`, регистрации тестового пользователя, входа и выхода на реальном клиенте.
