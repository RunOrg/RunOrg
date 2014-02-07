Concepts / Idempotent

A kind of request.

An API request is **Idempotent** if performing it twice in a row (with
no intervening requests) is no different than performing it exactly
once.

Note that while the effect of the request will be the same, the API
may provide different responses. For instance, sending an initial 
`DELETE` request will return a `202 Accepted`, but subsequent `DELETE`
requests on the same resource may return either `202 Accepted` or 
`404 Not Found`. 

Multiple idempotent requests will still cause changes to the _server_ : 
they will be appended to the HTTP logs and count towards any applicable 
quotas.

Several `GET` requests are idempotent : they will mark the resource
(e.g.  a new message) as _seen_, but only if the resource had not been
seen yet. 

With a few exceptions, all `DELETE` requests are idempotent. 

**Idempotent** is a stronger requirement than [Sync
idempotent](/docs/#/concept/sync-idempotent.md), and most `PUT`
requests are sync idempotent rather than just idempotent.
