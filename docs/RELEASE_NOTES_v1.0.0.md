# Release Notes — v1.0.0

## Initial ECS-Aware GeoDNS Release

This is the first stable release of **PowerDNS GeoDNS**, a self-hosted GeoDNS routing policy for PowerDNS Authoritative Server.

### Highlights

- ECS-aware GeoDNS routing policy
- PowerDNS Lua global policy
- MaxMind GeoLite2-Country integration
- Regional/external traffic steering
- Resolver country detection
- Trusted ECS resolver policy
- Manual resolver override support
- Safe defaults for production
- Example PowerDNS configuration
- Example GeoIP backend zone file
- Bilingual English/Persian README
- Security policy and deployment checklist
- GitHub Actions validation workflow

### Main Function

```lua
geo_pick(regional_ip, external_ip [, default_side])
```

### Notes

- Do not commit real production zone files.
- Do not commit MaxMind `.mmdb` files.
- Keep `GEOPOLICY_DEBUG=false` in production.
- Use this repository as a reusable infrastructure component for PowerDNS-based GeoDNS deployments.
