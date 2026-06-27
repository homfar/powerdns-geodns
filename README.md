# PowerDNS GeoDNS

A production-ready GeoDNS policy for PowerDNS Authoritative Server, built with Lua, MaxMind GeoLite2, and EDNS Client Subnet-aware routing logic.

It returns different DNS answers based on the geographic signal available at query time:

```text
regional clients/resolvers  -> regional endpoint
external clients/resolvers  -> external endpoint
```

The default policy is configured for Iran as the regional country:

```text
IR      -> regional endpoint
non-IR  -> external endpoint
```

The implementation uses neutral `regional` and `external` naming so the same pattern can be adapted to other countries or private regional-routing designs.

---

## Overview

This repository provides a reusable PowerDNS GeoDNS policy layer for two-endpoint traffic steering. It is intended for authoritative DNS deployments where a domain should resolve to one endpoint for a target region and another endpoint for the rest of the world.

The policy combines:

- PowerDNS Lua records
- MaxMind GeoLite2 country lookup
- EDNS Client Subnet-aware routing
- Resolver GeoIP fallback
- Manual resolver override rules
- Safe fallback behavior for unknown or incomplete signals

---

## Routing Model

The main function is:

```lua
geo_pick(regional_ip, external_ip [, default_side])
```

Example:

```lua
geo_pick("192.0.2.10", "198.51.100.10")
```

With the default regional country set to `IR`, the expected behavior is:

```text
Iranian client or resolver      -> 192.0.2.10
Non-Iranian client or resolver  -> 198.51.100.10
Unknown signal                  -> fallback side
```

The example IP addresses are documentation ranges. Replace them with your own endpoints in your deployment configuration.

---

## How the Policy Decides

The policy evaluates multiple signals in a predictable order:

1. Manual resolver override
2. Trusted EDNS Client Subnet signal
3. Resolver GeoIP country
4. PowerDNS `bestwho` fallback
5. Configured default side

This helps avoid relying on a single signal. For example, if ECS is unavailable or not trusted, the policy can still fall back to resolver GeoIP or the configured default side.

---

## Repository Structure

```text
.
├── lua-global/
│   └── 10-geo-policy.lua
├── zones/
│   └── examples/
│       └── example.com.yaml
├── docs/
│   ├── INSTALL.md
│   ├── TESTING.md
│   ├── DEPLOYMENT_CHECKLIST.md
│   ├── RELEASE_NOTES_v1.0.0.md
│   ├── pdns.conf.example
│   └── geoip-backend.yaml.example
├── scripts/
│   └── validate.sh
├── .github/
│   └── workflows/
│       └── validate.yml
├── Makefile
├── SECURITY.md
├── LICENSE
└── README.md
```

---

## Requirements

- Linux server
- PowerDNS Authoritative Server
- PowerDNS GeoIP backend
- Lua records enabled
- MaxMind GeoLite2 Country database
- `dig` for DNS validation

---

## Quick Start

Clone the repository:

```bash
git clone https://github.com/homfar/powerdns-geodns.git
cd powerdns-geodns
```

Run validation:

```bash
bash scripts/validate.sh
```

Or:

```bash
make validate
```

Review the example configuration files:

```bash
cat docs/pdns.conf.example
cat docs/geoip-backend.yaml.example
cat zones/examples/example.com.yaml
```

---

## Example Zone Record

A Lua-backed A record can be defined like this:

```yaml
records:
  - name: "www"
    type: "A"
    ttl: 60
    content: "geo_pick('192.0.2.10', '198.51.100.10')"
```

Meaning:

```text
192.0.2.10     -> regional endpoint
198.51.100.10  -> external endpoint
```

Recommended rollout approach:

1. Start with a low TTL.
2. Test from regional and external networks.
3. Confirm resolver behavior.
4. Increase TTL after verification.

---

## Production Deployment

A typical production deployment flow:

1. Install PowerDNS Authoritative Server.
2. Enable the GeoIP backend.
3. Install the MaxMind GeoLite2 Country database.
4. Add the Lua policy file to the PowerDNS Lua include path.
5. Configure PowerDNS to load Lua records.
6. Configure GeoIP backend zones.
7. Add Lua-backed records to the zone file.
8. Validate the PowerDNS configuration.
9. Restart PowerDNS.
10. Test DNS answers from multiple networks and resolvers.
11. Monitor DNS responses after rollout.

Detailed guides:

- [Installation Guide](docs/INSTALL.md)
- [Testing Guide](docs/TESTING.md)
- [Deployment Checklist](docs/DEPLOYMENT_CHECKLIST.md)

---

## Configuration Notes

The default regional country is currently `IR`.

A future version can move this into a single configurable value, for example:

```lua
REGIONAL_COUNTRY_CODE = "IR"
```

This would make the policy easier to reuse for other countries without changing the decision logic.

---

## Testing

Basic local query:

```bash
dig @127.0.0.1 www.example.com A
```

Query an authoritative DNS server:

```bash
dig @YOUR_AUTH_DNS_IP www.example.com A +short
```

Test with EDNS Client Subnet:

```bash
dig @YOUR_AUTH_DNS_IP www.example.com A +subnet=5.0.0.0/24
```

Use the full testing guide for a complete validation flow:

```text
docs/TESTING.md
```

---

## Operational Notes

- Keep `GEOPOLICY_DEBUG=false` in production.
- Keep deployment-specific values in your private operational configuration.
- Use documentation ranges in examples and public templates.
- Start rollout with low TTL values.
- Test with multiple resolvers and networks.
- Keep the GeoLite2 database updated.
- Review resolver override lists periodically.
- Monitor DNS answers after every policy or zone change.
- Validate GeoDNS behavior before enabling DNSSEC for affected zones.

---

## Validation

Run:

```bash
bash scripts/validate.sh
```

Or:

```bash
make validate
```

The validation script checks the repository layout, required files, example configuration, and common packaging issues.

GitHub Actions runs validation on push and pull request.

---

## Security

This repository includes a basic [Security Policy](SECURITY.md).

For public examples and templates, use documentation-only domains and IP ranges:

```text
example.com
192.0.2.0/24
198.51.100.0/24
203.0.113.0/24
```

Keep environment-specific configuration, operational resolver lists, database files, and deployment secrets outside the repository.

---

## Release

Recommended first stable tag:

```text
v1.0.0
```

Release notes:

```text
docs/RELEASE_NOTES_v1.0.0.md
```

---

## Roadmap

Possible improvements:

- Configurable regional country code
- Multi-region country-to-endpoint mapping
- Containerized PowerDNS integration tests
- Automated resolver classification helper
- DNS answer monitoring script
- Ansible role for repeatable deployment

---

## References

- [PowerDNS Lua Records](https://doc.powerdns.com/authoritative/lua-records/)
- [PowerDNS GeoIP Backend](https://doc.powerdns.com/authoritative/backends/geoip.html)
- [PowerDNS Lua Record Variables](https://doc.powerdns.com/authoritative/lua-records/functions.html)

---

# فارسی

## معرفی

این پروژه یک سیاست GeoDNS برای PowerDNS Authoritative Server است. منطق آن با Lua نوشته شده و برای تصمیم‌گیری از MaxMind GeoLite2، اطلاعات resolver و EDNS Client Subnet استفاده می‌کند.

هدف پروژه انتخاب پاسخ DNS بین دو مسیر است:

```text
کاربر یا resolver منطقه‌ای  -> endpoint منطقه‌ای
کاربر یا resolver خارجی     -> endpoint خارجی
```

در تنظیم پیش‌فرض، کشور منطقه‌ای ایران (`IR`) است:

```text
IR      -> مسیر منطقه‌ای
غیر IR  -> مسیر خارجی
```

نام‌گذاری پروژه به‌صورت `regional` و `external` انجام شده تا بتوان از همین مدل برای سناریوهای مشابه نیز استفاده کرد.

---

## قابلیت‌ها

- مسیریابی GeoDNS روی PowerDNS
- سیاست DNS مبتنی بر Lua
- تشخیص کشور با MaxMind GeoLite2
- پشتیبانی از EDNS Client Subnet
- override دستی برای resolverها
- fallback برای سیگنال‌های ناقص یا نامشخص
- نمونه تنظیمات PowerDNS
- نمونه zone برای GeoIP backend
- مستندات نصب، تست و deployment

---

## منطق اصلی

تابع اصلی:

```lua
geo_pick(regional_ip, external_ip [, default_side])
```

نمونه:

```lua
geo_pick("192.0.2.10", "198.51.100.10")
```

در حالت پیش‌فرض:

```text
کاربر یا resolver ایرانی      -> 192.0.2.10
کاربر یا resolver غیرایرانی   -> 198.51.100.10
سیگنال نامشخص                 -> مسیر fallback
```

---

## ترتیب تصمیم‌گیری

پروژه برای انتخاب پاسخ DNS این موارد را بررسی می‌کند:

1. override دستی resolver
2. EDNS Client Subnet در صورت قابل اعتماد بودن
3. کشور resolver بر اساس GeoIP
4. fallback مبتنی بر `bestwho`
5. مسیر پیش‌فرض

این مدل باعث می‌شود تصمیم‌گیری فقط به یک سیگنال وابسته نباشد.

---

## شروع سریع

```bash
git clone https://github.com/homfar/powerdns-geodns.git
cd powerdns-geodns
bash scripts/validate.sh
```

تست ساده:

```bash
dig @127.0.0.1 www.example.com A
```

تست با EDNS Client Subnet:

```bash
dig @YOUR_AUTH_DNS_IP www.example.com A +subnet=5.0.0.0/24
```

مستندات کامل‌تر:

```text
docs/INSTALL.md
docs/TESTING.md
docs/DEPLOYMENT_CHECKLIST.md
```

---

## نکات عملیاتی

- مقدار `GEOPOLICY_DEBUG` در production برابر `false` باشد.
- مقدارهای مخصوص deployment را در تنظیمات عملیاتی خصوصی نگه دارید.
- برای مثال‌های عمومی از IPهای مستنداتی استفاده کنید.
- rollout اولیه را با TTL پایین انجام دهید.
- رفتار DNS را از چند resolver و چند شبکه تست کنید.
- دیتابیس GeoLite2 را منظم به‌روزرسانی کنید.
- بعد از هر تغییر، پاسخ‌های DNS و لاگ‌های PowerDNS را بررسی کنید.

---

## License

MIT License
