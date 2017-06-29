# dnsbl

Create A- and TXT-records for a block list used by postfix to ban spam sending mail-servers.

Web-App for PowerDNS with MySQL Backend. You should have an existing PowerDNS MySQL-Database to use this app.

## Installation

```
git clone https://github.com/jfqd/dnsbl.git
cd dnsbl
mkdir log
bundle
cp env.sample .env
```

## Configuration

Edit ```.env``` file.

## Usage

Block an ip-address:

```curl -i 127.0.0.1:9292/block/85.158.183.86```

Release an ip-address:

```curl -i 127.0.0.1:9292/release/85.158.183.86```

## Hosting

We use Phusion Passenger, but you can use thin, puma, unicorn or any other rack server as well. For testing just use:

```rackup```

Copyright (c) 2017 Stefan Husch, qutic development.