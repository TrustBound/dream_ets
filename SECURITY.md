# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 3.x     | ✅ Active support  |
| < 3.0   | ❌ Not supported   |

## What dream_ets Is Responsible For

dream_ets is a library that provides:
- **Table creation** - A typed builder over `ets:new/2`
- **Typed operations** - Encoding and decoding of keys and values
- **Atomic helpers** - `insert_new()`, `take()` and the counter helpers
- **Persistence** - `save_to_file()` and `load_from_file()`

dream_ets is **not a framework**. You decide what goes in a table, who can read it, and where it is saved.

This means dream_ets's security surface is small:
- Type system bypasses in the encoders and decoders
- Errors that crash the calling process instead of returning `Error`
- Table options that are not applied as configured (for example access control)

## What You're Responsible For

Your application code handles:
- **Access control** - Choose `access_private()` or `access_protected()` when other processes must not write
- **Secrets** - ETS tables are in memory and readable by any process that may read them
- **File paths** - `save_to_file()` and `load_from_file()` use the path you give them
- **Loaded files** - Only load files that your application wrote
- **Memory limits** - ETS tables grow until you delete objects

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues.**

Email: **engineering@trustbound.ai**

### What to Include

- **Type of vulnerability** (e.g., decoder bypass, crash on bad input)
- **Location** in dream_ets's code (file/function)
- **Steps to reproduce** with minimal example
- **Impact** - What can an attacker do?
- **Proof-of-concept** if you have one

Focus on vulnerabilities in **dream_ets's code**, not in your application code.

### What to Expect

1. **Acknowledgment** within 48 hours
2. **Assessment** within 7 days
3. **Fix** coordinated with you on timing
4. **Release** with security advisory
5. **Credit** in the advisory (if desired)

## Security in dream_ets

### Type Safety

Gleam's type system prevents many vulnerabilities:
- ✅ No null pointer exceptions
- ✅ No buffer overflows
- ✅ Exhaustive pattern matching
- ✅ Immutable data structures

Each value read from a table goes through the decoder of the table. Data that does not decode is `Error(DecodeError(...))`, not a wrong value.

## Known Non-Issues

These are not dream_ets vulnerabilities (they're your application's responsibility):

- A public table that another process changes
- Sensitive data saved to a file with `save_to_file()`
- A file from an untrusted source loaded with `load_from_file()`
- Tables that grow without limit

## Dependencies

dream_ets's dependencies:
- **Gleam stdlib** - Type-safe, battle-tested
- **gleam_erlang** - Erlang atoms and processes
- **gleam_json** - JSON encoding
- **BEAM/OTP** - 30+ years of production use

We monitor dependencies and update promptly for security issues.

## Questions?

- **Security questions**: engineering@trustbound.ai
- **Non-security issues**: [GitHub Issues](https://github.com/TrustBound/dream_ets/issues)
- **General discussion**: [GitHub Discussions](https://github.com/TrustBound/dream/discussions)

---

**Remember:** dream_ets is a library. It provides tools. You write the application. You're responsible for your application's security.
