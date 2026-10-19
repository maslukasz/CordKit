# Security Policy

## Supported versions

The latest released minor version receives security fixes. Pre-release versions are not supported.

## Reporting a vulnerability

Please do not open a public issue for security problems.

Instead, report the issue privately to the maintainers using the contact method listed on the
repository profile or GitHub's private vulnerability reporting. Include:

- a description of the vulnerability,
- steps to reproduce it,
- the affected version(s),
- any suggested remediation.

You can expect an acknowledgement within a few days and a coordinated disclosure once a fix is
available.

## Scope

CordKit is a thin layer over discordrb. Vulnerabilities in discordrb itself should be reported to the
discordrb maintainers. CordKit-specific issues include, but are not limited to:

- unsafe parsing of custom IDs,
- state store leaks or unintended data exposure,
- command validation bypasses,
- permission checks that can be bypassed.
