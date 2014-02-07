Concepts / Sync Idempotent

A kind of request.

An API request is **Sync idempotent** if performing it twice in a row
(with no intervening requests), with a
[synchronization](/docs/#/concept/synchronization.md) in-between, is
no different than running it once.

If a network or client-side failure prevented the client from
receiving the response, the request can be tried again without risk
after a synchronization step.

Multiple sync idempotent requests will still cause changes to the
_server_: they will be appended to the HTTP logs and count towards
any applicable quotas.

Most `PUT` requests are sync idempotent, rather than outright
[Idempotent](/docs/#/concept/idempotent.md). The difference lies not
in the final state of the resource (in that regard, all `PUT` requests
are truly idempotent, as mandated by HTTP) ; however, a write request
may generate a history line (such as "User X updated object Y"), and
two consecutive requests _may_ in some cases create two such lines. 
A synchronization prevents this from happening.

**Sync idempotent** is the weakest idempotence requirement. 


