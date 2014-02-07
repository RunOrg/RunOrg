Concepts / Read-only

A kind of request. 

An API request is **Read-only** if it does not cause any change to the
[database](/docs/#/concepts/database.md). In other words, there is no
observable difference between performing a read-only request or not.

Read-only requests will cause changes to the _server_ : they will be
appended to the HTTP logs and count towards any applicable quotas.

Obviously, only `GET` requests can be read-only. 

**Read-only** is a stronger requirement than
[Idempotent](/docs/#/concepts/idempotent.md), and many `GET` requests
are idempotent rather than read-only.
