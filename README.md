# PowerDNS GeoDNS — ECS-Aware GeoIP Routing Policy

[![PowerDNS](https://img.shields.io/badge/PowerDNS-Authoritative-blue)](https://www.powerdns.com/)
[![Lua](https://img.shields.io/badge/Lua-Policy%20Engine-orange)](https://www.lua.org/)
[![MaxMind](https://img.shields.io/badge/MaxMind-GeoLite2-green)](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data)
[![GeoDNS](https://img.shields.io/badge/GeoDNS-ECS%20Aware-purple)](#)
[![License](https://img.shields.io/badge/License-MIT-brightgreen)](LICENSE)

**PowerDNS GeoDNS** is a self-hosted, production-oriented **GeoDNS routing policy** for **PowerDNS Authoritative Server**. It uses **PowerDNS Lua records**, **MaxMind GeoLite2-Country**, and **EDNS Client Subnet (ECS)** to return different DNS answers based on resolver/client geography and trusted routing signals.

It is designed for infrastructure, DevOps and SRE teams that need deterministic, auditable and self-hosted DNS traffic steering without depending on a managed GeoDNS provider.

---

## Language / زبان

- [English Documentation](#english-documentation)
- [مستندات فارسی](#مستندات-فارسی)

---

# English Documentation

## What This Project Does

This repository provides a reusable **GeoDNS policy layer** for PowerDNS Authoritative Server. A DNS record can return a domestic/regional endpoint for one audience and an external/global endpoint for another audience.

Typical routing model:

```text
Regional users      → regional / local endpoint
International users → external / global endpoint
```

The main Lua function exposed to zone files is:

```lua
geo_pick(regional_ip, external_ip [, default_side])
```

Example zone usage:

```yaml
- lua:
    ttl: 60
    content: A ";return geo_pick('REGIONAL_SERVER_IP', 'EXTERNAL_SERVER_IP')"
```

The policy can be adapted for Iran/international routing, domestic/global routing, CDN origin selection, private infrastructure steering or multi-region failover patterns where DNS-level geography matters.

## Why It Matters

GeoDNS looks simple, but production DNS routing is noisy. Users may query through public resolvers, ISP resolvers, CDN resolvers, VPNs, mobile networks or resolvers that include ECS data. Blindly trusting one signal can cause misrouting.

This project provides a layered policy engine with clear decision priority:

- manual resolver override lists
- trusted ECS handling
- untrusted ECS protection rules
- resolver country lookup through MaxMind
- PowerDNS `bestwho` fallback
- explicit per-record fallback behavior
- optional debug tracing for operational analysis

## Architecture

```text
DNS Query
   │
   ▼
PowerDNS Authoritative Server
   │
   ├── GeoIP Backend
   │     └── MaxMind GeoLite2-Country lookup
   │
   └── Lua Global Policy
         └── geo_pick(regional_ip, external_ip, default_side)
               │
               ├── 1. Resolver manual override
               ├── 2. Trusted ECS decision
               ├── 3. Regional resolver + foreign/bad ECS guard
               ├── 4. Resolver country decision
               ├── 5. PowerDNS bestwho fallback
               └── 6. Record-level default fallback
```

## Decision Priority

| Priority | Signal | Decision Logic |
|---:|---|---|
| 1 | Resolver manual override | Resolver prefixes can be forced to `IR` or `EXT` |
| 2 | Trusted ECS | ECS from allowlisted resolvers is treated as authoritative |
| 3 | Regional resolver + foreign/bad ECS | Prevents domestic users from being misrouted to external IPs |
| 4 | Resolver country | Uses MaxMind country lookup for the resolver IP |
| 5 | `bestwho` country | Uses the PowerDNS-selected client address as a fallback signal |
| 6 | Default fallback | Uses `EXT` by default or explicit `IR`/`EXT` passed to `geo_pick()` |

> The current policy uses `IR` and `EXT` as route labels because it was designed for Iran/international traffic steering. You can keep those labels or adapt the lists and comments for another regional routing model.

## ECS Trust Model

ECS improves routing accuracy only when it is handled carefully. This policy validates ECS using these rules:

- IPv4 ECS prefixes must be at least `/24`.
- IPv6 ECS prefixes must be at least `/48`.
- Private, loopback, link-local and unspecified addresses are rejected.
- ECS from trusted resolvers can route to either `IR` or `EXT`.
- ECS from untrusted resolvers is only allowed to route toward `IR` when ECS resolves to Iran.
- If the resolver itself is known as regional/domestic and ECS points abroad, the resolver signal wins to reduce domestic-user misrouting.

## Features

- Self-hosted GeoDNS for PowerDNS Authoritative Server
- Lua-based policy engine with a simple `geo_pick()` API
- MaxMind GeoLite2-Country integration through the PowerDNS GeoIP backend
- EDNS Client Subnet aware routing
- IPv4 and IPv6 ECS prefix validation
- Manual resolver override lists
- Safe production defaults
- Optional debug trace support with `geo_trace()`
- Example PowerDNS Authoritative configuration
- Example GeoIP backend domain list
- Example YAML zone file
- Deployment, testing and security documentation
- GitHub Actions validation workflow
- Bilingual English/Persian documentation

## Repository Structure

```text
powerdns-geodns/
├── lua-global/
│   └── 10-geo-policy.lua              # PowerDNS global Lua GeoDNS policy
├── zones/
│   └── examples/
│       └── example.com.yaml           # Example GeoIP backend zone
├── docs/
│   ├── INSTALL.md                     # Deployment guide
│   ├── TESTING.md                     # dig/ECS validation examples
│   ├── DEPLOYMENT_CHECKLIST.md        # Production checklist
│   ├── pdns.conf.example              # PowerDNS authoritative config example
│   └── geoip-backend.yaml.example     # GeoIP backend domain list example
├── scripts/
│   └── validate.sh                    # Repository safety and formatting checks
├── .github/workflows/
│   └── validate.yml                   # CI validation
├── Makefile
├── SECURITY.md
├── LICENSE
└── README.md
```

## Production Quick Start

### 1. Install prerequisites

Debian / Ubuntu:

```bash
sudo apt update
sudo apt install -y pdns-server pdns-backend-geoip dnsutils
```

RHEL / Rocky / AlmaLinux:

```bash
sudo dnf install -y pdns pdns-backend-geoip bind-utils
```

### 2. Prepare directories

```bash
sudo mkdir -p /etc/powerdns/lua-global
sudo mkdir -p /etc/powerdns/geoip/zones
sudo mkdir -p /etc/powerdns/geoip/maxmind
```

### 3. Download MaxMind GeoLite2-Country

Create a free MaxMind account and download `GeoLite2-Country.mmdb` from MaxMind.

Place the database here:

```bash
sudo cp GeoLite2-Country.mmdb /etc/powerdns/geoip/maxmind/
sudo chown root:root /etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb
sudo chmod 0644 /etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb
```

Do **not** commit `.mmdb` files to GitHub.

### 4. Install the Lua policy

```bash
sudo cp lua-global/10-geo-policy.lua /etc/powerdns/lua-global/
sudo chown root:root /etc/powerdns/lua-global/10-geo-policy.lua
sudo chmod 0644 /etc/powerdns/lua-global/10-geo-policy.lua
```

### 5. Install example config files

```bash
sudo cp docs/pdns.conf.example /etc/powerdns/pdns.conf
sudo cp docs/geoip-backend.yaml.example /etc/powerdns/geoip/geoip-backend.yaml
sudo cp zones/examples/example.com.yaml /etc/powerdns/geoip/zones/example.com.yaml
```

Then edit placeholders such as:

```text
example.com
REGIONAL_SERVER_IP
EXTERNAL_SERVER_IP
NS1_IP
NS2_IP
```

### 6. Validate PowerDNS configuration

```bash
sudo pdns_server --config-check
```

If your distribution does not support `--config-check`, restart and inspect logs immediately:

```bash
sudo systemctl restart pdns
sudo journalctl -u pdns -n 100 --no-pager
```

### 7. Restart PowerDNS

```bash
sudo systemctl restart pdns
sudo systemctl status pdns --no-pager
```

### 8. Test with dig

```bash
dig @127.0.0.1 example.com SOA +short
dig @127.0.0.1 example.com A +short
dig @127.0.0.1 www.example.com A +short
```

More test scenarios are available in [docs/TESTING.md](docs/TESTING.md).

## Lua Configuration Reference

| Variable | Default | Description |
|---|---:|---|
| `GEOPOLICY_DEBUG` | `false` | Enables structured debug logs with `pdnslog()` |
| `IR_RESOLVERS` | empty | Verified regional/domestic resolver prefixes that should be forced to `IR` |
| `EXT_RESOLVERS` | empty | Verified external/international resolver prefixes that should be forced to `EXT` |
| `TRUSTED_ECS_RESOLVERS` | empty | Resolvers whose ECS data is fully trusted |
| `ECS_MIN_V4_BITS` | `24` | Minimum acceptable IPv4 ECS prefix length |
| `ECS_MIN_V6_BITS` | `48` | Minimum acceptable IPv6 ECS prefix length |
| `ALLOW_IR_FROM_UNLISTED_FOREIGN_ECS` | `true` | Allows untrusted ECS to route to `IR` when ECS country is Iran |

## Zone File Usage

Basic A record routing:

```yaml
- lua:
    ttl: 60
    content: A ";return geo_pick('REGIONAL_IP', 'EXTERNAL_IP')"
```

Explicit fallback to the external side when country cannot be determined:

```yaml
- lua:
    ttl: 60
    content: A ";return geo_pick('REGIONAL_IP', 'EXTERNAL_IP', 'EXT')"
```

Explicit fallback to the regional side when country cannot be determined:

```yaml
- lua:
    ttl: 60
    content: A ";return geo_pick('REGIONAL_IP', 'EXTERNAL_IP', 'IR')"
```

Debug trace record:

```yaml
trace.example.com:
  - lua:
      ttl: 30
      content: TXT ";return geo_trace()"
```

Then query:

```bash
dig @127.0.0.1 trace.example.com TXT
```

## Production Hardening

### DNS exposure

Expose only DNS ports unless you intentionally operate administrative APIs:

```bash
sudo ufw allow 53/udp
sudo ufw allow 53/tcp
```

For firewalld:

```bash
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload
```

### PowerDNS hardening

Recommended defaults are included in [docs/pdns.conf.example](docs/pdns.conf.example):

```text
version-string=anonymous
disable-axfr=yes
api=no
webserver=no
query-logging=no
log-dns-queries=no
enable-lua-records=yes
edns-subnet-processing=yes
```

### Operational rules

- Keep `GEOPOLICY_DEBUG = false` in production.
- Do not commit real production zone files.
- Do not commit real server IPs, DKIM values, private keys or MaxMind databases.
- Keep resolver override lists small, verified and documented.
- Test routing from domestic and international networks before switching NS records.
- Keep TTLs low during rollout; increase them after stable routing is confirmed.
- Maintain a documented MaxMind database update process.

See [SECURITY.md](SECURITY.md) and [docs/DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md).

## Local Repository Validation

```bash
make validate
```

or:

```bash
bash scripts/validate.sh
luac -p lua-global/10-geo-policy.lua
```

## Recommended GitHub Topics

```text
powerdns geodns geoip dns authoritative-dns lua ecs edns-client-subnet maxmind geolite2 dns-routing traffic-steering devops sre infrastructure self-hosted
```

## Roadmap

- [ ] Optional Docker Compose lab for local testing
- [ ] Automated GeoLite2 update helper
- [ ] Route decision metrics exporter
- [ ] CIDR/city/ISP-level routing profiles
- [ ] Lua unit-test harness with mocked PowerDNS globals

## License

MIT License — see [LICENSE](LICENSE).

---

# مستندات فارسی

## این پروژه دقیقاً چه می‌کند؟

این پروژه یک سیستم **GeoDNS اختصاصی و self-hosted** برای **PowerDNS Authoritative Server** است. با استفاده از Lua، دیتابیس MaxMind GeoLite2-Country و پردازش EDNS Client Subnet، می‌تواند پاسخ DNS را بر اساس موقعیت resolver یا client subnet تغییر دهد.

مدل رایج استفاده:

```text
کاربر منطقه‌ای / داخلی      → IP سرور داخلی یا نزدیک‌تر
کاربر بین‌المللی / خارجی   → IP سرور خارجی یا جهانی
```

تابع اصلی پروژه داخل zone file این است:

```lua
geo_pick(regional_ip, external_ip [, default_side])
```

نمونه استفاده:

```yaml
- lua:
    ttl: 60
    content: A ";return geo_pick('REGIONAL_SERVER_IP', 'EXTERNAL_SERVER_IP')"
```

این پروژه برای سناریوهای DevOps/SRE، زیرساخت DNS، Authoritative DNS، ترافیک‌استیرینگ، سرویس‌های چندمنطقه‌ای، routing منطقه‌ای و مدیریت پاسخ DNS در سطح production مناسب است.

## چرا پروژه ارزشمند است؟

GeoDNS فقط تشخیص کشور نیست. در دنیای واقعی درخواست DNS ممکن است از resolverهای عمومی، resolverهای ISP، CDN، VPN، شبکه موبایل یا resolverهایی با ECS برسد. اگر فقط به یک سیگنال اعتماد شود، احتمال misroute وجود دارد.

این پروژه یک لایه policy قابل کنترل ایجاد می‌کند که تصمیم DNS را بر اساس چند سطح انجام می‌دهد:

- لیست override دستی resolverها
- ECS معتبر از resolverهای trusted
- محافظت در برابر ECS نامعتبر یا گمراه‌کننده
- تشخیص کشور resolver با MaxMind
- fallback داخلی PowerDNS با `bestwho`
- fallback صریح در سطح رکورد

## معماری

```text
درخواست DNS
   │
   ▼
PowerDNS Authoritative Server
   │
   ├── GeoIP Backend
   │     └── تشخیص کشور با MaxMind GeoLite2-Country
   │
   └── Lua Global Policy
         └── geo_pick(regional_ip, external_ip, default_side)
               │
               ├── ۱. Override دستی resolver
               ├── ۲. تصمیم‌گیری با ECS معتبر
               ├── ۳. محافظت در برابر ECS خارجی/نامعتبر برای resolver داخلی
               ├── ۴. تشخیص کشور resolver
               ├── ۵. fallback با bestwho در PowerDNS
               └── ۶. fallback پیش‌فرض رکورد
```

## منطق تصمیم‌گیری

| اولویت | سیگنال | منطق |
|---:|---|---|
| ۱ | Override دستی resolver | prefixهای مشخص می‌توانند اجباراً `IR` یا `EXT` شوند |
| ۲ | ECS معتبر | ECS از resolverهای allowlist‌شده معتبر محسوب می‌شود |
| ۳ | resolver داخلی + ECS خارجی/نامعتبر | برای کاهش misroute، سیگنال resolver داخلی اولویت می‌گیرد |
| ۴ | کشور resolver | کشور IP resolver با MaxMind بررسی می‌شود |
| ۵ | کشور `bestwho` | fallback داخلی PowerDNS استفاده می‌شود |
| ۶ | fallback پیش‌فرض | پیش‌فرض `EXT` است، مگر در `geo_pick()` چیز دیگری بدهید |

## ویژگی‌ها

- GeoDNS اختصاصی و self-hosted
- مناسب برای PowerDNS Authoritative Server
- سیاست‌گذاری Lua با API ساده `geo_pick()`
- تشخیص کشور با MaxMind GeoLite2-Country
- پشتیبانی از EDNS Client Subnet
- اعتبارسنجی prefix برای IPv4 و IPv6
- override دستی resolverها
- پیش‌فرض‌های امن برای production
- قابلیت trace با `geo_trace()`
- کانفیگ نمونه PowerDNS
- zone نمونه برای GeoIP backend
- چک‌لیست production deployment
- مستندات انگلیسی و فارسی
- GitHub Actions برای اعتبارسنجی اولیه

## نصب production

Debian / Ubuntu:

```bash
sudo apt update
sudo apt install -y pdns-server pdns-backend-geoip dnsutils
```

Rocky / AlmaLinux:

```bash
sudo dnf install -y pdns pdns-backend-geoip bind-utils
```

ساخت مسیرها:

```bash
sudo mkdir -p /etc/powerdns/lua-global
sudo mkdir -p /etc/powerdns/geoip/zones
sudo mkdir -p /etc/powerdns/geoip/maxmind
```

نصب Lua policy:

```bash
sudo cp lua-global/10-geo-policy.lua /etc/powerdns/lua-global/
sudo chown root:root /etc/powerdns/lua-global/10-geo-policy.lua
sudo chmod 0644 /etc/powerdns/lua-global/10-geo-policy.lua
```

کپی کانفیگ‌ها:

```bash
sudo cp docs/pdns.conf.example /etc/powerdns/pdns.conf
sudo cp docs/geoip-backend.yaml.example /etc/powerdns/geoip/geoip-backend.yaml
sudo cp zones/examples/example.com.yaml /etc/powerdns/geoip/zones/example.com.yaml
```

دیتابیس MaxMind را جداگانه دانلود کنید و اینجا بگذارید:

```bash
sudo cp GeoLite2-Country.mmdb /etc/powerdns/geoip/maxmind/
sudo chown root:root /etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb
sudo chmod 0644 /etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb
```

سپس placeholderها مثل موارد زیر را با مقدار واقعی خودتان جایگزین کنید:

```text
example.com
REGIONAL_SERVER_IP
EXTERNAL_SERVER_IP
NS1_IP
NS2_IP
```

بررسی کانفیگ:

```bash
sudo pdns_server --config-check
```

Restart:

```bash
sudo systemctl restart pdns
sudo systemctl status pdns --no-pager
```

تست:

```bash
dig @127.0.0.1 example.com SOA +short
dig @127.0.0.1 example.com A +short
dig @127.0.0.1 www.example.com A +short
```

## تنظیمات مهم Lua

| متغیر | پیش‌فرض | توضیح |
|---|---:|---|
| `GEOPOLICY_DEBUG` | `false` | فعال‌سازی لاگ debug |
| `IR_RESOLVERS` | خالی | prefixهای resolver داخلی/منطقه‌ای که با تست واقعی تأیید شده‌اند |
| `EXT_RESOLVERS` | خالی | prefixهای resolver خارجی/بین‌المللی که با تست واقعی تأیید شده‌اند |
| `TRUSTED_ECS_RESOLVERS` | خالی | resolverهایی که ECS آن‌ها کاملاً trusted است |
| `ECS_MIN_V4_BITS` | `24` | حداقل طول prefix برای ECS IPv4 |
| `ECS_MIN_V6_BITS` | `48` | حداقل طول prefix برای ECS IPv6 |
| `ALLOW_IR_FROM_UNLISTED_FOREIGN_ECS` | `true` | اگر ECS غیر trusted کشور ایران را نشان دهد، اجازه route به IR داده می‌شود |

## سخت‌سازی production

- فقط UDP/TCP 53 را در فایروال عمومی باز کنید.
- API و webserver داخلی PowerDNS را عمومی نکنید.
- `version-string=anonymous` فعال باشد.
- AXFR غیرفعال باشد یا فقط با allowlist انجام شود.
- Dynamic DNS update غیرفعال باشد مگر واقعاً لازم باشد.
- در production مقدار `GEOPOLICY_DEBUG` باید `false` باشد.
- فایل‌های zone واقعی، IPهای حساس، DKIM، secret، کلید خصوصی و فایل‌های `.mmdb` را در GitHub نگذارید.
- TTL را در زمان rollout پایین نگه دارید و بعد از پایداری افزایش دهید.
- MaxMind database update process داشته باشید.

## اعتبارسنجی repository

```bash
make validate
```

یا:

```bash
bash scripts/validate.sh
luac -p lua-global/10-geo-policy.lua
```

## License

MIT License — see [LICENSE](LICENSE).
