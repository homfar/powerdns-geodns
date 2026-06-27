# Testing Guide

This guide covers basic validation, ECS simulation and operational checks for the PowerDNS GeoDNS policy.

## 1. Repository validation

Run before publishing or deploying:

```bash
make validate
```

or:

```bash
bash scripts/validate.sh
```

Lua syntax check:

```bash
luac -p lua-global/10-geo-policy.lua
```

On Debian/Ubuntu, install Lua if needed:

```bash
sudo apt install -y lua5.4
luac5.4 -p lua-global/10-geo-policy.lua
```

## 2. PowerDNS configuration validation

```bash
sudo pdns_server --config-check
```

Then restart and inspect logs:

```bash
sudo systemctl restart pdns
sudo journalctl -u pdns -n 100 --no-pager
```

## 3. Basic DNS checks

```bash
dig @127.0.0.1 example.com SOA +short
dig @127.0.0.1 example.com NS +short
dig @127.0.0.1 example.com A +short
dig @127.0.0.1 www.example.com A +short
dig @127.0.0.1 api.example.com A +short
```

Expected result: every hostname should return a valid response from the GeoIP backend zone file.

## 4. ECS simulation

Simulate a foreign client subnet:

```bash
dig @127.0.0.1 example.com A +subnet=8.8.8.0/24 +short
```

Simulate another client subnet:

```bash
dig @127.0.0.1 example.com A +subnet=1.1.1.0/24 +short
```

Simulate IPv6 ECS:

```bash
dig @127.0.0.1 example.com A +subnet=2001:4860:4860::/48 +short
```

Use valid test prefixes for your target region when validating regional routing behavior.

## 5. Trace endpoint

The example zone includes a temporary trace record:

```bash
dig @127.0.0.1 trace.example.com TXT +short
```

This can help inspect the route decision while testing. Remove or protect trace records in production because they may expose routing details.

## 6. External validation

After public NS delegation, test from multiple locations:

```bash
dig @YOUR_AUTH_NS_IP example.com A +short
dig @YOUR_AUTH_NS_IP www.example.com A +short
dig @YOUR_AUTH_NS_IP example.com A +subnet=8.8.8.0/24 +short
```

Recommended checks:

- domestic ISP resolver
- public resolver with ECS support
- public resolver without ECS support
- mobile network
- foreign VPS
- monitoring node from another region

## 7. Failure checks

Check that PowerDNS is listening:

```bash
sudo ss -lntup | grep ':53'
```

Check logs:

```bash
sudo journalctl -u pdns -f
```

Check whether the MaxMind database is readable:

```bash
sudo test -r /etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb && echo OK
```

Check for YAML or zone path mistakes:

```bash
sudo ls -la /etc/powerdns/geoip/
sudo ls -la /etc/powerdns/geoip/zones/
```

## 8. Production acceptance checklist

Before switching live traffic:

- SOA, NS and A records resolve locally.
- GeoDNS records return expected endpoints from at least two network locations.
- ECS test behavior is understood and documented.
- TTL values are intentionally selected.
- PowerDNS logs show no Lua or backend errors.
- AXFR and API exposure are disabled or restricted.
- A rollback config and previous zone backup exist.
