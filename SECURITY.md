# Security Policy

## Supported Use

This repository is intended as a public, reusable GeoDNS policy example for PowerDNS Authoritative Server. It should not contain production secrets, real private infrastructure data, customer zones, DKIM values, private keys or MaxMind database files.

## Do Not Commit

Never commit any of the following:

- Real production zone files
- Real customer domains unless intentionally public
- Real server IPs that should remain private
- DKIM private keys or private DNS records
- `.mmdb` MaxMind database files
- MaxMind license keys or account IDs
- SSH keys, API tokens, passwords or `.env` files
- Query logs containing resolver or client IP addresses

## Recommended Production Settings

- Keep `GEOPOLICY_DEBUG = false` in production.
- Keep PowerDNS `version-string=anonymous`.
- Disable AXFR unless required and restricted by source IP.
- Disable DNS update unless explicitly needed.
- Restrict exposed services to UDP/TCP 53 only.
- Keep resolver override lists reviewed and documented.
- Keep MaxMind database updates under controlled automation.

## Reporting a Security Issue

If you find a security issue, open a private report if available, or contact the repository maintainer directly. Do not publish exploit details before the issue is reviewed.
