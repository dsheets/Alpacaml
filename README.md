Alpacaml
========
Alpacaml is a type-safe, Monadic, fully asynchronous and encrypted SOCKS5 proxy
written in OCaml.

###Build
Alpacaml consists of two parts: client and server.

The following command will build both parts:

    make all

Note: one may need to set correct dynamic link path for libsodium on Ubuntu before running the program:

    export LD_LIBRARY_PATH=/usr/local/lib

###Depends on
* Jane Street's [Core](https://github.com/janestreet/core) and [Async](https://github.com/janestreet/async)
* [Cryptokit](https://forge.ocamlcore.org/projects/cryptokit/)
* [ocaml-sodium](https://github.com/dsheets/ocaml-sodium)
* The *sine qua non* [9gag.com](http://9gag.com), without which I would have finished months earlier

###TO-DO
* Support for libsodium, AES-256-CFB, AES-256-OFB and ARCFour encryptions
* UDP relay

###FAQ
**Q**: How asynchrony is achieved?

**A**: In a Monadic way. Specifically, through Async.Deferred.

**Q**: Why encryption? Encryption is not enforced in [RFC 1928](http://tools.ietf.org/html/rfc1928).

**A**: Because f*ck GFW. That's why.

**Q**: Why not Node.js?

**A**: Because f*ck Node.js. Alpaca also shows its indifference to Node.js:

![pic](https://lh6.googleusercontent.com/-XlW6F95vMBU/U_w8rjY7trI/AAAAAAAABOw/WPfHuVuxQxQ/w852-h764/alpaca_loop_nodejs.gif)

### License
GPL V3

### Alpaca

> The habits of spitting and trampling are probably defence mechanisms of the 
> animals against outside aggression, real or potential.

[UN FAO Manual for ALPACA RAISING IN THE HIGH ANDES, Behavioural characteristics](http://www.fao.org/docrep/004/x6500e/x6500e21.htm)
