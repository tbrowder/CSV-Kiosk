[![Actions Status](https://github.com/tbrowder/CSV-Kiosk/actions/workflows/linux.yml/badge.svg)](https://github.com/tbrowder/CSV-Kiosk/actions) [![Actions Status](https://github.com/tbrowder/CSV-Kiosk/actions/workflows/macos.yml/badge.svg)](https://github.com/tbrowder/CSV-Kiosk/actions) [![Actions Status](https://github.com/tbrowder/CSV-Kiosk/actions/workflows/windows.yml/badge.svg)](https://github.com/tbrowder/CSV-Kiosk/actions)

NAME
====

**CSV::Kiosk** - Provides a simple CSV file data entry system

SYNOPSIS
========

```raku
use CSV::Kiosk;
```

DESCRIPTION
===========

**CSV::Kiosk** is designed to aid in entering attendee data into a simple CSV file with the entry monitored and aided by one person. The example use case is for a upcoming reunion for the US Air Force Academy (USAFA) class of 1965 (the seventh class to graduate since its founding).

The CSV header line:

    last, first, middle, suffix, CS, email, phone, address1, address2, city, state, zip-code, guest, guest-relationship, other-information

AUTHOR
======

Tom Browder <tbrowder@acm.org>

COPYRIGHT AND LICENSE
=====================

© 2025 Tom Browder

This library is free software; you may redistribute it or modify it under the Artistic License 2.0.

