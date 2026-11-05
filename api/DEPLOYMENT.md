# Публичное развёртывание eNet API 0.4

Этот комплект подготавливает API для iOS, Windows и других клиентов через HTTPS. **Файлы не разворачивают сервер автоматически**: нужен VPS с Ubuntu, доступ по SSH и управление DNS домена.

## Предлагаемая схема

- API: `api.enet-dev.ru` (отдельная DNS A-запись на IP VPS).
- Node.js API слушает только `127.0.0.1:8787`.
- Caddy принимает HTTPS на 443 и проксирует запросы на локальный API.
- SQLite хранится отдельно в `/var/lib/enet-api`, вне каталога исходников.
- Systemd перезапускает API и запускает ежедневное резервное копирование.

## Подготовка VPS

Установить Node.js 22.16+, Git, sqlite3 и Caddy. Затем создать системного пользователя и каталоги:

```bash
sudo useradd --system --home /var/lib/enet-api --shell /usr/sbin/nologin enet-api
sudo install -d -o root -g root -m 0755 /opt/enet-app
sudo install -d -o root -g root -m 0750 /etc/enet-api
sudo install -d -o enet-api -g enet-api -m 0700 /var/lib/enet-api
sudo install -d -o enet-api -g enet-api -m 0700 /var/backups/enet-api
```

Разместить исходники в `/opt/enet-app`. Пользователь `enet-api` должен иметь доступ на чтение к исходникам и запись только к данным/резервным копиям.

Настроить переменные окружения:

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

Если Node.js находится не в `/usr/bin/node`, изменить `ExecStart` в unit-файле на фактический путь.

Установить и запустить API:

```bash
sudo cp /opt/enet-app/api/deploy/enet-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now enet-api
sudo systemctl status enet-api
curl http://127.0.0.1:8787/ready
```

## DNS и HTTPS

1. Создать DNS A-запись `api.enet-dev.ru` на публичный IPv4 VPS (AAAA добавлять только при реально настроенном IPv6).
2. Разрешить входящие TCP 80 и 443 в firewall и панели VPS. Порт 8787 наружу **не открывать**.
3. Скопировать `api/deploy/Caddyfile.example` в `/etc/caddy/Caddyfile`.
4. Проверить конфигурацию и перезапустить Caddy:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
curl https://api.enet-dev.ru/health
curl https://api.enet-dev.ru/ready
```

Caddy автоматически получает и обновляет сертификат при корректных DNS и доступных портах 80/443.

API доверяет `X-Real-IP` только при `ENET_TRUST_PROXY=true`. В примере Caddy сам выставляет этот заголовок. Не включайте доверие к нему, если порт API доступен напрямую из интернета.

## Резервное копирование SQLite

Установить timer/service:

```bash
sudo cp /opt/enet-app/api/deploy/enet-api-backup.service /etc/systemd/system/
sudo cp /opt/enet-app/api/deploy/enet-api-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now enet-api-backup.timer
sudo systemctl start enet-api-backup.service
sudo systemctl status enet-api-backup.service
systemctl list-timers enet-api-backup.timer
```

Таймер делает согласованную SQLite-копию раз в сутки и хранит локальные копии 14 дней. Для защиты от потери самого VPS копии следует дополнительно выгружать в отдельное хранилище.

Восстановление выполняется при остановленном API:

```bash
sudo systemctl stop enet-api
sudo cp /var/backups/enet-api/ИМЯ-КОПИИ.sqlite /var/lib/enet-api/enet.sqlite
sudo rm -f /var/lib/enet-api/enet.sqlite-wal /var/lib/enet-api/enet.sqlite-shm
sudo chown enet-api:enet-api /var/lib/enet-api/enet.sqlite
sudo chmod 0600 /var/lib/enet-api/enet.sqlite
sudo systemctl start enet-api
curl http://127.0.0.1:8787/ready
```

## Подключение клиентов

После фактического развёртывания в eNet APP указывается:

```
https://api.enet-dev.ru
```

Адрес выбирается в приложении. Для удалённых серверов клиент разрешает только HTTPS. iPhone не может обращаться к `127.0.0.1` компьютера с Linux, поэтому нужен публичный HTTPS endpoint.

## Ограничения перед публичным запуском

- Счётчики rate limit пока хранятся в памяти одного процесса. Для нескольких экземпляров или строгой защиты нужен Redis/общее хранилище.
- Нужны подтверждение email, восстановление пароля, MFA/OIDC, аудит и мониторинг.
- SQLite рассчитана на один API instance; перед горизонтальным масштабированием нужен план миграции на PostgreSQL.
- eNet ID пока **не является единым входом в Продайзер**.
- Не добавлять в GitHub env-файлы с секретами, базу SQLite, резервные копии и приватные ключи.

Считать развёртывание завершённым только после проверки HTTPS, `/ready`, регистрации, входа и выхода на реальном клиенте.
