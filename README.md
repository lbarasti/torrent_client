# torrent_client

TODO: Write a description here

## Installation
```
shards install # install dependencies
crystal build -Dpreview_mt src/torrent_client.cr # compile with multi-threading support
```

## Usage
```
CRYSTAL_WORKERS=<n-workers>  ./torrent_client <torrent> [<destination>]
```

#### Examples
```
CRYSTAL_WORKERS=8  ./torrent_client ./spec/testdata/debian.iso.torrent ./data/debian.iso
CRYSTAL_WORKERS=8  ./torrent_client ./spec/testdata/debian-10.2.0-amd64-netinst.iso.torrent
```

## Development
#### Compile and run
```
crystal src/torrent_client.cr ./spec/testdata/debian.iso.torrent ./data/debian.iso
```

#### Messages
Handshake:  Bytes[0, 0, 0, 169]
Unchoke:    Bytes[0, 0, 0,   1, 1]
Bitfield:   Bytes[0, 0, 0,   5, 5, ...]
Keep-Alive: Bytes[0, 0, 0,   0]
Piece:      Bytes[0, 0, 64,  9, 7, ...]

#### Running the specs
```
crystal specs
```

## Contributing

1. Fork it (<https://github.com/lbarasti/torrent_client/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [lbarasti](https://github.com/lbarasti) - creator and maintainer
