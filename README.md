# campfire.cr

[Campfire](http://campfirenow.com/) command line client and library witten in [Crystal](http://crystal-lang.org)

A one evening hack, awful, buggy and incomplete.

## Building

Building the command line client:

```
crystal build ccc.cr
```

## Usage

Configure your Campfire credentials adding the following to `~/.campfire/auth.yml`:

```
---
subdomain: campfire-subdomain
token: my-token-here
```

Replace `subdomain` with your Campfire subdomain (i.e. without the `campfirenow.com`) and `my-token-here` with your own token.

```
Usage: ccc <command> <args>

AVAILABLE COMMANDS:

say          <room> <text>      Send a message to a room.
stalk        <room>             Join a room and listen.
transcript   <room> [date]      Get today's transcript.
                                (date is optional, format YYYY/MM/DD).
```

## Contributing

1. Fork it ( https://github.com/[your-github-name]/campfire.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request
