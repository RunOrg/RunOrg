Concepts / Delayed

A kind of request.

For performance reasons, all write requests sent through the RunOrg
API will return as soon as possible, rather than wait for the write to
be processed. RunOrg will return a `202 Accepted` status instead,
indicating a **Delayed** request. For comparison, a non-delayed
request would return `200 OK` instead.

A `202 Accepted` guarantees that the request has been committed to
persistent storage, and will not be lost if the server crashes.

The response to all delayed requests will include an `at` field
containing the [clock position](/docs/#/types/clock.js) when the
request will have been processed.

If you wish to wait for the request to be processed, use
[synchronization](/docs/#/concept/synchronization.md) on your next
request using the provided clock position.

 