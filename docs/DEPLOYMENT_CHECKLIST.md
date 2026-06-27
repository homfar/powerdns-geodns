# Production Deployment Checklist

Use this checklist before publishing a real authoritative DNS deployment.

## DNS and PowerDNS

- [ ] PowerDNS Authoritative is installed and enabled.
- [ ] `launch=geoip` is set.
- [ ] Lua records are enabled with `enable-lua-records=yes`.
- [ ] EDNS Client Subnet processing is enabled with `edns-subnet-processing=yes`.
- [ ] GeoIP database path is correct.
- [ ] GeoIP zones file path is correct.
- [ ] Lua global include directory is correct.
- [ ] UDP/TCP 53 are allowed by firewall.
- [ ] Non-DNS administrative services are not exposed publicly.

## Security

- [ ] `version-string=anonymous` is set.
- [ ] AXFR is disabled or strictly allowlisted.
- [ ] Dynamic DNS updates are disabled unless required.
- [ ] PowerDNS API is disabled or bound to private management networks only.
- [ ] PowerDNS webserver is disabled or private only.
- [ ] `GEOPOLICY_DEBUG = false` in production.
- [ ] No real zone file, IP list, DKIM value, key or `.mmdb` file is committed to GitHub.
- [ ] Query logging is disabled unless explicitly required for short-term troubleshooting.

## Routing

- [ ] `REGIONAL_SERVER_IP` and `EXTERNAL_SERVER_IP` placeholders are replaced.
- [ ] Default side is intentionally selected per record.
- [ ] Resolver override lists are minimal and verified.
- [ ] Trusted ECS resolver list is intentionally configured.
- [ ] Route behavior is tested from domestic and international networks.
- [ ] Trace records are removed or protected before production.

## Operations

- [ ] PowerDNS restart tested.
- [ ] `dig` checks pass for SOA, NS and A records.
- [ ] Logs are monitored after deployment.
- [ ] MaxMind database update process is documented.
- [ ] Rollback plan exists.
- [ ] Previous working `pdns.conf` and zone files are backed up.
