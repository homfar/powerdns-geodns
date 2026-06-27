# Installation Guide

This guide describes a production-oriented PowerDNS Authoritative + GeoIP backend deployment using the Lua policy included in this repository.

## 1. Install packages

Debian / Ubuntu:

```bash
sudo apt update
sudo apt install -y pdns-server pdns-backend-geoip dnsutils
```

RHEL / Rocky / AlmaLinux:

```bash
sudo dnf install -y pdns pdns-backend-geoip bind-utils
```

## 2. Prepare directories

```bash
sudo mkdir -p /etc/powerdns/lua-global
sudo mkdir -p /etc/powerdns/geoip/zones
sudo mkdir -p /etc/powerdns/geoip/maxmind
```

## 3. Copy repository files

```bash
sudo cp lua-global/10-geo-policy.lua /etc/powerdns/lua-global/
sudo cp docs/pdns.conf.example /etc/powerdns/pdns.conf
sudo cp docs/geoip-backend.yaml.example /etc/powerdns/geoip/geoip-backend.yaml
sudo cp zones/examples/example.com.yaml /etc/powerdns/geoip/zones/example.com.yaml
```

Recommended permissions:

```bash
sudo chown root:root /etc/powerdns/lua-global/10-geo-policy.lua
sudo chmod 0644 /etc/powerdns/lua-global/10-geo-policy.lua
sudo chown -R root:pdns /etc/powerdns/geoip
sudo find /etc/powerdns/geoip -type d -exec chmod 0750 {} \;
sudo find /etc/powerdns/geoip -type f -exec chmod 0640 {} \;
```

If your distribution runs PowerDNS under a different group, adjust `root:pdns` accordingly.

## 4. Add MaxMind database

Download `GeoLite2-Country.mmdb` from MaxMind and copy it to:

```bash
sudo cp GeoLite2-Country.mmdb /etc/powerdns/geoip/maxmind/
sudo chown root:pdns /etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb
sudo chmod 0640 /etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb
```

The `.mmdb` file is licensed data and must not be committed to GitHub.

## 5. Edit configuration

Edit `/etc/powerdns/pdns.conf` and verify:

```text
launch=geoip
enable-lua-records=yes
edns-subnet-processing=yes
geoip-database-files=mmdb:/etc/powerdns/geoip/maxmind/GeoLite2-Country.mmdb
geoip-zones-file=/etc/powerdns/geoip/geoip-backend.yaml
lua-global-include-dir=/etc/powerdns/lua-global
version-string=anonymous
api=no
webserver=no
disable-axfr=yes
```

Edit `/etc/powerdns/geoip/geoip-backend.yaml` and include only the domains served by this authoritative DNS instance.

Edit zone YAML files and replace placeholders such as:

```text
example.com
REGIONAL_SERVER_IP
EXTERNAL_SERVER_IP
NS1_IP
NS2_IP
```

## 6. Validate before restart

Repository-level validation:

```bash
make validate
```

Lua syntax validation:

```bash
luac -p lua-global/10-geo-policy.lua
```

PowerDNS config validation:

```bash
sudo pdns_server --config-check
```

If your build does not support `--config-check`, restart PowerDNS and immediately inspect logs.

## 7. Restart PowerDNS

```bash
sudo systemctl restart pdns
sudo systemctl status pdns --no-pager
sudo journalctl -u pdns -n 100 --no-pager
```

## 8. Validate DNS responses

```bash
dig @127.0.0.1 example.com SOA +short
dig @127.0.0.1 example.com NS +short
dig @127.0.0.1 example.com A +short
dig @127.0.0.1 www.example.com A +short
```

ECS simulation example:

```bash
dig @127.0.0.1 example.com A +subnet=8.8.8.0/24 +short
```

See `docs/TESTING.md` for deeper validation scenarios.

## 9. Production rollout notes

- Keep TTLs low during initial rollout, for example `60` seconds for GeoDNS records.
- Test from multiple networks before changing public NS records.
- Keep a rollback zone file and previous PowerDNS config backup.
- Keep `GEOPOLICY_DEBUG=false` in production unless troubleshooting.
- Do not expose PowerDNS API or webserver publicly.
- Automate MaxMind database updates in a controlled process.
