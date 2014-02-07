Concepts / Synchronization

RunOrg keeps an internal queue of commands that remain to be
processed. Depending on current server load and the complexity of the
command, it may take a few seconds before a command you issued is
reflected in the state of the database. This may lead to inconsistent
data being returned.

A concrete example: you post a new message to a conversation, then
query the list of all messages in that conversation, and observe that
your message does not appear (because it has not been processed yet).

**Synchronization** is a process the client uses to wait until their
previous command has been processed (but not a millisecond longer).

# Delayed response structure

A [delayed](/docs/#/concept/delayed.md) request will return a `202
Accepted` status (indicating that RunOrg will process it later) and a
JSON object with an `at` field containing a
[clock](/docs/#/types/clock.js) representing the moment when the
request will be fully processed.

### Example delayed request
    POST /db/0Et4X0016om/contacts/import
    Content-Type: application/json 
   
    [ {"email":"vnicollet@runorg.com","fullname":"Victor Nicollet","gender":"M"}, 
      {"email":"test@example.com"} ]

### Example delayed response
    202 Accepted
    Content-Type: application/json

    { "created": [ "0Et9j0026rO", "0SMXP00G0ON" ],
      "at": [[2,87]] }

Here, the clock is `[[2,87]]`. 

**If you lost the clock value**, perhaps because the response was lost
due to network or client failure, and you need to wait until that
request is processed, your only hope is to [wait for **all**
requests](/docs/#/db/sync.js) currently in the processing queue to
be finished.

# Without synchronization

If you send a request before RunOrg could actually perform the import, then the
imported contacts will be missing. 

### Example request, no synchronization
    GET /db/0Et4X0016om/contacts/0Et9j0026rO
    
### Example response, no synchronization
    404 Not Found
    COntent-Type: application/json

    {"error":"Contact '0Et9j0026rO' does not exist","path":"/db/{db}/contacts/{cid}"}

# Waiting for a clock value

Every single API request supports an additional query parameter
`at=<clock>` which tells RunOrg to wait until processing has reached
that clock value before performing the request.

If the clock value has already been reached, the request is treated as
if no `at` was provided. Otherwise, RunOrg will wait until processing
catches up with that value.

### Example request
    GET /db/0Et4X0016om/contacts/0Et9j0026rO?at=[[2,87]]
    
The server will wait until the import has finished, then respond: 

### Example response
    200 OK
    COntent-Type: application/json

    { "id" : "0Et9j0026rO",
      "name" : "Victor Nicollet",
      "gender" : "M",
      "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" }

If, after a few seconds of waiting, the processing has still not caught up with the
requested clock value, RunOrg will respond with a `503 Service Unavailable`.

### Example timeout response
    503 Service Unavailable
    Retry-After: 1

# Waiting on multiple clock values

If you perform several delayed requests in a row (thus obtaining
several clock values), and need to have the next request wait for
_all_ those requests to be processed, you will need to merge the clock
values together. Read more about this in the
[clock](/docs/#/types/clock.js) documentation.