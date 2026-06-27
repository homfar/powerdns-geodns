-- =============================================================
-- PowerDNS GeoDNS Global Lua Policy
-- Routes IR (Iranian) and EXT (international) users to their
-- respective servers using a 6-layer decision hierarchy.
--
-- Decision priority:
--   1) Resolver manual override (IR_RESOLVERS / EXT_RESOLVERS)
--   2) Trusted ECS (TRUSTED_ECS_RESOLVERS allowlist)
--   3) IR resolver + foreign/bad ECS -> force IR
--   4) Resolver country (GeoIP on resolver IP)
--   5) bestwho country (PowerDNS ECS fallback object)
--   6) Per-domain default fallback
--
-- Public API:
--   geo_pick(ir_ip, ext_ip [, default_side])  -> IP string
--   geo_trace()                                -> debug string
-- =============================================================

GEOPOLICY_DEBUG = false

-- Add known Iranian resolver prefixes here.
-- Only add prefixes you have verified from logs and testing.
IR_RESOLVERS = newNMG({
  -- "2.188.21.0/24",
  -- "2.189.44.0/24",
})

-- Add known international resolver prefixes here.
-- Resolvers in this list are forced to EXT regardless of ECS.
EXT_RESOLVERS = newNMG({
  -- "8.8.8.0/24",
  -- "1.1.1.0/24",
})

-- Resolvers whose ECS is fully trusted for country determination.
-- If empty, ECS is only accepted in limited IR-bias scenarios.
TRUSTED_ECS_RESOLVERS = newNMG({
  -- "8.8.8.0/24",
  -- "1.1.1.0/24",
})

-- Minimum acceptable ECS prefix length.
-- Prefixes shorter than these are considered too broad and rejected.
ECS_MIN_V4_BITS = 24
ECS_MIN_V6_BITS = 48

-- When true: if a foreign resolver sends ECS that resolves to IR,
-- accept it even if that resolver is not in TRUSTED_ECS_RESOLVERS.
-- This allows Iranian users behind foreign CDN resolvers to be
-- correctly routed to IR servers.
ALLOW_IR_FROM_UNLISTED_FOREIGN_ECS = true

-- =============================================================
-- Internal helpers
-- =============================================================

local function dbg(msg)
  if GEOPOLICY_DEBUG then
    pdnslog("[geo-global] " .. msg, pdns.loglevels.Warning)
  end
end

local function safe_tostring(v)
  local ok, s = pcall(function() return tostring(v) end)
  if ok and s ~= nil then return s end
  return "<nil>"
end

-- Convert a PowerDNS ComboAddress or Netmask object to an IP string.
local function combo_to_ip(addr)
  if addr == nil then return nil end

  local ok, s = pcall(function() return addr:toString() end)
  if ok and s ~= nil and s ~= "" then return s end

  ok, s = pcall(function() return tostring(addr) end)
  if ok and s ~= nil and s ~= "" then return s end

  return nil
end

-- Serialize ecswho (a Netmask) to a string for logging.
local function ecs_mask_to_string()
  if ecswho == nil then return nil end

  local ok, s = pcall(function() return ecswho:toString() end)
  if ok and s ~= nil and s ~= "" then return s end

  ok, s = pcall(function() return tostring(ecswho) end)
  if ok and s ~= nil and s ~= "" then return s end

  return nil
end

-- Returns true if addr matches any prefix in group (NetmaskGroup).
local function addr_in_group(addr, group)
  if addr == nil or group == nil then return false end
  local ok, matched = pcall(function() return group:match(addr) end)
  return ok and matched == true
end

local function is_ipv6_text(ip)
  if ip == nil then return false end
  return string.find(ip, ":", 1, true) ~= nil
end

-- Returns true for RFC 1918 IPv4 private addresses.
local function is_rfc1918_v4(ip)
  if ip == nil then return false end
  if string.match(ip, "^10%.") then return true end
  if string.match(ip, "^192%.168%.") then return true end
  local b = string.match(ip, "^172%.(%d+)%.")
  if b ~= nil then
    local bn = tonumber(b)
    if bn ~= nil and bn >= 16 and bn <= 31 then return true end
  end
  return false
end

-- Returns true for any address that should not be used for GeoIP lookup:
-- RFC1918, loopback, link-local, unspecified, IPv6 ULA/loopback/link-local.
local function is_special_ip(ip)
  if ip == nil or ip == "" or ip == "<nil>" then return true end

  if not is_ipv6_text(ip) then
    if is_rfc1918_v4(ip) then return true end
    if string.match(ip, "^127%.") then return true end
    if string.match(ip, "^169%.254%.") then return true end
    if string.match(ip, "^0%.") then return true end
  end

  if ip == "::" or ip == "::1" then return true end
  if string.match(ip, "^fe80:") then return true end
  if string.match(ip, "^fc") or string.match(ip, "^fd") then return true end

  return false
end

-- Returns "IR", "EXT", or nil based on IR_RESOLVERS / EXT_RESOLVERS.
local function resolver_override()
  if addr_in_group(who, IR_RESOLVERS) then return "IR" end
  if addr_in_group(who, EXT_RESOLVERS) then return "EXT" end
  return nil
end

-- GeoIP lookup on a plain IP string. Returns ISO 3166-1 alpha-2 or "--".
local function geo_country_of_ip(ip)
  if is_special_ip(ip) then return "--" end

  local ok, val = pcall(function()
    return geoiplookup(ip, GeoIPQueryAttribute.Country2)
  end)

  if (not ok) or val == nil or val == "" then
    ok, val = pcall(function()
      return geoiplookup(ip, GeoIPQueryAttribute.Country)
    end)
  end

  if (not ok) or val == nil or val == "" then return "--" end
  return string.upper(tostring(val))
end

local function resolver_country()
  return geo_country_of_ip(combo_to_ip(who))
end

-- Country of the ECS client prefix, resolved via bestwho.
-- ecswho is a Netmask object; bestwho is a ComboAddress usable for GeoIP.
local function effective_ecs_country()
  if ecswho == nil then return "--" end
  return geo_country_of_ip(combo_to_ip(bestwho))
end

-- Country via PowerDNS countryCode() built-in (uses bestwho internally).
local function best_country()
  local ip = combo_to_ip(bestwho)
  if is_special_ip(ip) then return "--" end

  local ok, val = pcall(function() return countryCode() end)
  if (not ok) or val == nil or val == "" then return "--" end
  return string.upper(tostring(val))
end

local function has_ecs()
  return ecswho ~= nil
end

-- Extract the prefix length from ecswho. Tries getBits() then .bits field.
local function ecs_prefix_bits()
  if ecswho == nil then return nil end

  local ok, bits = pcall(function() return ecswho:getBits() end)
  if ok and bits ~= nil then return tonumber(bits) end

  ok, bits = pcall(function() return ecswho.bits end)
  if ok and bits ~= nil then return tonumber(bits) end

  return nil
end

local function ecs_min_bits_for_ip(ip)
  if ip == nil then return nil end
  if is_ipv6_text(ip) then return ECS_MIN_V6_BITS end
  return ECS_MIN_V4_BITS
end

-- Evaluate ECS signal quality and return a structured result table.
-- Fields: present, usable, trusted, reason, ip, mask, bits, cc, policy_ir_bias
local function ecs_quality()
  if not has_ecs() then
    return {
      present = false, usable = false, trusted = false,
      reason = "no_ecs", ip = nil, mask = nil, bits = nil,
      cc = "--", policy_ir_bias = false,
    }
  end

  local ip   = combo_to_ip(bestwho)
  local mask = ecs_mask_to_string()
  local bits = ecs_prefix_bits()
  local cc   = effective_ecs_country()

  local function reject(reason)
    return {
      present = true, usable = false, trusted = false,
      reason = reason, ip = ip, mask = mask, bits = bits,
      cc = cc, policy_ir_bias = false,
    }
  end

  if ip == nil or ip == "" then return reject("ecs_no_ip") end
  if is_special_ip(ip)     then return reject("ecs_special_ip") end
  if cc == "--"             then return reject("ecs_country_unknown") end

  local min_bits = ecs_min_bits_for_ip(ip)
  if bits ~= nil and min_bits ~= nil and bits < min_bits then
    return reject("ecs_too_broad")
  end

  if addr_in_group(who, TRUSTED_ECS_RESOLVERS) then
    return {
      present = true, usable = true, trusted = true,
      reason = "trusted_resolver_allowlist",
      ip = ip, mask = mask, bits = bits, cc = cc,
      policy_ir_bias = false,
    }
  end

  local who_cc = resolver_country()

  -- IR ECS from a foreign resolver: accept with IR bias (ALLOW_IR_FROM_UNLISTED_FOREIGN_ECS).
  if ALLOW_IR_FROM_UNLISTED_FOREIGN_ECS and who_cc ~= "IR" and cc == "IR" then
    return {
      present = true, usable = true, trusted = false,
      reason = "foreign_resolver_ir_ecs_bias",
      ip = ip, mask = mask, bits = bits, cc = cc,
      policy_ir_bias = true,
    }
  end

  return {
    present = true, usable = true, trusted = false,
    reason = "ecs_not_trusted",
    ip = ip, mask = mask, bits = bits, cc = cc,
    policy_ir_bias = false,
  }
end

-- =============================================================
-- Public: geo_trace() — call from a Lua record for diagnostics
-- =============================================================

function geo_trace()
  local who_ip  = combo_to_ip(who) or "<nil>"
  local ecs_ip  = combo_to_ip(bestwho) or "<nil>"
  local ecs_mask = ecs_mask_to_string() or "<nil>"
  local who_cc  = resolver_country()
  local ecs_cc  = effective_ecs_country()
  local best_cc = best_country()
  local ov      = resolver_override()
  local eq      = ecs_quality()

  return string.format(
    "who=%s; ecs=%s; ecs_mask=%s; resolver_cc=%s; ecs_cc=%s; best_cc=%s; "
    .. "override=%s; ecs_present=%s; ecs_bits=%s; ecs_usable=%s; "
    .. "ecs_trusted=%s; ecs_reason=%s; ecs_ir_bias=%s",
    who_ip, ecs_ip, ecs_mask,
    who_cc, ecs_cc, best_cc,
    safe_tostring(ov),
    safe_tostring(eq.present),
    safe_tostring(eq.bits),
    safe_tostring(eq.usable),
    safe_tostring(eq.trusted),
    safe_tostring(eq.reason),
    safe_tostring(eq.policy_ir_bias)
  )
end

-- =============================================================
-- Internal: log decision and return the chosen IP.
-- =============================================================

local function choose(ir_ip, ext_ip, side, source, who_cc, best_cc, eq, extra)
  dbg(
    "who="          .. safe_tostring(combo_to_ip(who))    ..
    " ecs="         .. safe_tostring(combo_to_ip(bestwho)) ..
    " ecs_mask="    .. safe_tostring(eq.mask)             ..
    " resolver_cc=" .. safe_tostring(who_cc)              ..
    " ecs_cc="      .. safe_tostring(eq.cc)               ..
    " best_cc="     .. safe_tostring(best_cc)             ..
    " ecs_bits="    .. safe_tostring(eq.bits)             ..
    " ecs_trusted=" .. safe_tostring(eq.trusted)          ..
    " ecs_reason="  .. safe_tostring(eq.reason)           ..
    " ecs_ir_bias=" .. safe_tostring(eq.policy_ir_bias)   ..
    " decision="    .. safe_tostring(side)                ..
    " source="      .. safe_tostring(source)              ..
    " extra="       .. safe_tostring(extra)
  )
  return side == "IR" and ir_ip or ext_ip
end

local function normalize_side(side)
  local v = string.upper(tostring(side or "EXT"))
  if v ~= "IR" and v ~= "EXT" then
    error("geo_pick: default_side must be 'IR' or 'EXT', got: " .. v)
  end
  return v
end

-- =============================================================
-- Public: geo_pick(ir_ip, ext_ip [, default_side]) -> IP string
--
-- Use in zone files:
--   lua A ";return geo_pick('IR_IP', 'EXT_IP')"
--   lua A ";return geo_pick('IR_IP', 'EXT_IP', 'IR')"
-- =============================================================

function geo_pick(ir_ip, ext_ip, default_side)
  if ir_ip == nil or ir_ip == "" then
    error("geo_pick: ir_ip is required")
  end
  if ext_ip == nil or ext_ip == "" then
    error("geo_pick: ext_ip is required")
  end

  local fallback = normalize_side(default_side or "EXT")
  local who_cc   = resolver_country()
  local best_cc  = best_country()
  local ov       = resolver_override()
  local eq       = ecs_quality()

  -- 1) Resolver manual override
  if ov == "IR" then
    return choose(ir_ip, ext_ip, "IR", "resolver_override", who_cc, best_cc, eq, "override=IR")
  end
  if ov == "EXT" then
    return choose(ir_ip, ext_ip, "EXT", "resolver_override", who_cc, best_cc, eq, "override=EXT")
  end

  -- 2) ECS present and usable
  if eq.present and eq.usable then

    -- IR resolver + foreign ECS: protect Iranian users from misrouting.
    -- A domestic resolver sending foreign ECS is more likely a CDN artefact
    -- than a genuine international client; trust the resolver location.
    if who_cc == "IR" and eq.cc ~= "IR" and eq.cc ~= "--" then
      return choose(
        ir_ip, ext_ip, "IR", "local_resolver_with_foreign_ecs", who_cc, best_cc, eq,
        "ecs_reason=" .. safe_tostring(eq.reason) .. ",ecs_cc=" .. safe_tostring(eq.cc)
      )
    end

    -- Trusted ECS: resolver is allowlisted, ECS country is authoritative.
    if eq.trusted and eq.cc == "IR" then
      return choose(
        ir_ip, ext_ip, "IR", "trusted_ecs", who_cc, best_cc, eq,
        "ecs_reason=" .. safe_tostring(eq.reason) .. ",ecs_bits=" .. safe_tostring(eq.bits)
      )
    end
    if eq.trusted and eq.cc ~= "IR" and eq.cc ~= "--" then
      return choose(
        ir_ip, ext_ip, "EXT", "trusted_ecs", who_cc, best_cc, eq,
        "ecs_reason=" .. safe_tostring(eq.reason) .. ",ecs_bits=" .. safe_tostring(eq.bits)
      )
    end

    -- Untrusted ECS: only use it to route toward IR (safe direction).
    -- Never use untrusted ECS to route an unknown user away from IR.
    if eq.cc == "IR" then
      return choose(
        ir_ip, ext_ip, "IR", "untrusted_but_ir_ecs_bias", who_cc, best_cc, eq,
        "ecs_reason=" .. safe_tostring(eq.reason) .. ",ecs_bits=" .. safe_tostring(eq.bits)
      )
    end
  end

  -- 3) ECS present but unusable/rejected + IR resolver -> route IR.
  if eq.present and (not eq.usable) and who_cc == "IR" then
    return choose(
      ir_ip, ext_ip, "IR", "ir_resolver_with_bad_ecs", who_cc, best_cc, eq,
      "ecs_reason=" .. safe_tostring(eq.reason)
    )
  end

  -- 4) Resolver country (no ECS or ECS exhausted above).
  if who_cc == "IR" then
    return choose(ir_ip, ext_ip, "IR", "resolver_country", who_cc, best_cc, eq, "who_cc=IR")
  end
  if who_cc ~= "--" then
    return choose(ir_ip, ext_ip, "EXT", "resolver_country", who_cc, best_cc, eq, "who_cc=" .. who_cc)
  end

  -- 5) bestwho country via PowerDNS countryCode().
  if best_cc == "IR" then
    return choose(ir_ip, ext_ip, "IR", "bestwho_country", who_cc, best_cc, eq, "best_cc=IR")
  end
  if best_cc ~= "--" then
    return choose(ir_ip, ext_ip, "EXT", "bestwho_country", who_cc, best_cc, eq, "best_cc=" .. best_cc)
  end

  -- 6) Domain-level default fallback.
  return choose(ir_ip, ext_ip, fallback, "default", who_cc, best_cc, eq, "fallback=" .. fallback)
end
