# The lives of RunOrg requests

This short document describes the behaviour of two consecutive
requests to the RunOrg API: one request to create a new form, and one
request to view the newly created form.

## A creation request

The client creates a new form. The HTTPS request looks somewhat like this: 

    POST /db/01234567890/forms/create?as=09876543210
    Content-type: application/json
    Authorizaton: RUNORG token=WZmu32ivB25

    {...}

### HTTPS protocol

On the RunOrg side, everything starts in the **HTTPD** layer: a
background thread, created by
[`Httpd.start`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/httpdLib/listen.ml#L8),
waits for new connections on port 443. When a new connection is
received, the corresponding socket is wrapped in a _[respond to this
request]_ task and added to the task scheduler.

The scheduler itself runs in the main thread of the program. It is an
implementation of coöperative threads not unlike Lwt or Node.js, found
in module `Run`.

The new task **performs a TLS handshake** (in
[`HttpdLib.Https.parse`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/httpdLib/https.ml#L61))
in order to establish the HTTPS channel.

It then **parses the HTTP request** (in
[`HttpdLib.Request.read_request`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/httpdLib/request.ml#L96))
using asynchronous primitives when reading from the socket in order to
avoid blocking the main thread. As part of parsing the request, a few
elementary invariants are checked:

 - Is the authorization token `RUNORG token=WZmu32ivB25` formatted
   properly, if present ?
 - Are the standard query parameters `as`, `at`, `limit` and `offset`
   formatted properly, if present ? 
 - Is the `Host:` header present ? 

If a body is present (either as `application/json` or
`application/x-msgpack`), it is parsed as well. 

### API dispatch 

The parsed request leaves module `Httpd` and enters module `Api`: it
is **dispatched to the corresponding API endpoint** (in
[`ApiLib.Endpoint.dispatch`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/apiLib/endpoint.ml#L176)).
RunOrg keeps a list of all available endpoints and the HTTP verbs they
support. If no endpoint is found, a `404 Not Found` response is
generated.

The endpoint for our creation request is: 

    POST /db/{db}/forms/create

Once the endpoint is found, RunOrg will **parse the API request** 
based on the specifications of that endpoint. Among the operations 
performed: 

 - All expected variables in the path are parsed accordingly. Here,
   `db` is set to `01234567890`. 
 - For database-level requests (like this one), the existence of the
   database is checked (using 
   [`Db.ctx`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/db.ml#L71)) 
   and a brand new execution context is formed (returned by `Db.ctx`) to
   reference that database.  This helps ensure that queries for
   database A do not accidentally touch queries from database B.
 - If an `at` parameter was found, it is added to the context as well,
   so that all database reads know they have to synchronize with that 
   clock. 

RunOrg also performs **authentication** at this stage: if an `?as=` 
parameter is found, the token should correspond to that account.. 

In the case of `PUT` or `POST` requests, **the request body is parsed**
and turned from a blob of JSON data into the OCaml data type expected 
by the endpoint implementation.

### Endpoint processing

The endpoints are all defined in module `Api`, and the one used for
this request can be found in
[`ApiLib.FormAPI.Create`](https://github.com/RunOrg/RunOrg/blob/ef221c32e252ab8207597c93dbbb66a7663a691a/server/apiLib/formAPI.ml#L8).

It first performs some **request-specific data validation** that is
too specific to be handled by the API dispatcher.

Then, it performs a **model command** (a request to alter the model) 
with the correct data, and waits for a result. The commands are 
asynchronous, so the endpoint does not block the the main thread while
waiting for the model to finish.

### Model commands

The RunOrg model follows a CQRS architecture: requests may perform either
a _command_ (updating the model state, but returning nothing) or a
_query_ (reading data but not changing anything). 

In practice, most API requests will perform a series of preliminary queries
(does the database exist ? is the user allowed to do this ? is the model
synchronized with this clock ?) followed by the actual query or command.  

In this example, the model will execute the "create form" command (in
[`FormLib.Commands.create`](https://github.com/RunOrg/RunOrg/blob/ef221c32e252ab8207597c93dbbb66a7663a691a/server/formLib/commands.ml#L8))
by **checking that the requester is allowed to run the command**, and
then **adding an event to the corresponding event store**.

### Back to the client

Model commands usually return a variety of errors, from "this object
does not exist" to "you are not allowed to do that". The endpoint 
will **translate the response** to the expected output format (usually
a combination of an HTTP status code and an endpoint-specific OCaml 
data type) and return them. 

The dispatcher then builds the converts the OCaml data type to its 
JSON representation.

This representation is then **sent back to the client** by the HTTPD
server, which then **writes a log line** in the standard web server 
log format, and terminates the connection. 

## The model

The RunOrg model is implemented with Event Sourcing : every single
thing that happens is turned into an event, and appended to an event
stream. To determine the current state of an object, RunOrg reads all
the events that have ever occured in the system and applies them in
turn.

### Event Streams

Everything starts with **adding an event to a stream** (in
[`CqrsLib.EventStream.append`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/cqrsLib/eventStream.ml#L96)).
Each stream is a table in the underlying PostgreSQL database: the one
for form-related events is `stream:form`. Events are strongly typed,
represented as OCaml data types in the OCaml code and as compact
[msgpack](http://msgpack.org/) in the database.

Adding events to the stream will **increment the stream clock**, which
is just a fancy representation of how many events are in that stream.

### Projections

It would be quite a bad idea to read the entire event history for
every read request. To improve performance, the current state is 
cached in the database, and updated every time a new event happens. 

Each individual cache is called a projection. Each projection keeps
track of its vector clock, which says "my contents represent the state
when stream X contained clock[X] events, and stream Y contained
clock[Y] events". It then becomes easy to check for new events in any
of the streams.

A background coöperative thread **polls the event streams for new
events**. These events are then unserialized and passed to the
projections that have registered to receive them (with
[`CqrsLib.EventStream.track`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/cqrsLib/eventStream.ml#L159)).

As part of unserialization, the model will read the time when the
event occurred, and the database in which it happened. These are then
added to the context, so that any code processing the events will not
mistakenly access the wrong database or use the wrong timestamp.

### Views

A projection will usually store its data in several views. Each
individual view represents a facet of the cached data. Map-views (in
[`CqrsLib.MapView`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/cqrsLib/mapView.ml))
serve to map the current state of a resource to its identifier,
many-to-many-views (in
[`CqrsLib.ManyToManyView`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/cqrsLib/manyToManyView.ml))
represent many-to-many relationships, and son on.

It is even possible to create raw views using SQL. 

When it receives a batch of events to process, a projection will: 

 - **Start a new SQL transaction** to avoid having multiple RunOrg 
   processes clobber the projection's contents. 
 - **Read the current vector clock** and discard any events before
   that vector clock, to avoid race conditions causing an event to 
   be processed twice. 
 - **Ask the model to handle the events**, which consists in 
   updating the individual views (as in [`FormLib.View.info`](https://github.com/RunOrg/RunOrg/blob/ef221c32e252ab8207597c93dbbb66a7663a691a/server/formLib/view.ml#L18)). This
   will cause the views to run SQL queries against the database. 
   The events are provided in order of creation.
 - **Update the vector clock** to encompass all processed events.
 - **Commit the transaction**. 

Due to the polling approach, there may be a two-second delay between
the creation of an event and its processing. However, despite its 
latency, the event processing pipeline has a high throughput (several
thousands of events per second, on typical hardware). 

## A read request

Because of the event processing latency, it is possible for a read 
request to return `404 Not Found` if it was sent right after the 
creation request. This is a very annoying race condition. 

Traditional APIs (and most models based on SQL) will prevent this 
race condition by having the creation request block until the state
has been updated. For performance reasons (not all clients need to
wait), RunOrg uses a different approach. 

As with all command requests, the creation request will have returned
the vector clock representing the event that was appended. It will 
look like: `[[5,355]]`, or the 355th event in the 5th stream. This can
be used to avoid the race condition by forcing the synchronization. 

In effect, this causes the read request to block until the state has
been updated. 

So, the client sends a request that looks like: 

    GET /db/01234567890/forms/12312312312?as=09876543210&at=[[5,355]]
    Authorizaton: RUNORG token=WZmu32ivB25

Everything, from the HTTPD layer down to the endpoint, happens exactly
as before. The only difference is that the endpoint will **perform a 
model query**.

### Model queries

Queries are read-only operations, which access only the views
maintained by the projections. In effect, a model query just **reads
data from one or more views**. In this example, the executed query is
[`FormLib.Queries.get`](https://github.com/RunOrg/RunOrg/blob/ef221c32e252ab8207597c93dbbb66a7663a691a/server/formLib/queries.ml#L26),
and it is a thin wrapper around
[`Cqrs.MapView.get`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/cqrsLib/mapView.ml#L71)
over the correct view.

Remember the `at` parameter used for synchronization ? The
corresponding vector clock was added to the context when the request
was parsed. All views will read the vector clock from the context, and
**wait for the projection to reach that clock** (using
[`CqrsLib.Projection.wait`](https://github.com/RunOrg/RunOrg/blob/v0.1.34/server/cqrsLib/projection.ml#L254)).

RunOrg will only wait for a short while (about 30 seconds) before
giving up: if the projection has not caught up with the event streams
by then, something must have gone terribly wrong (such as the
projection being drowned in too many events, or a critical issue
preventing events from being processed). In either case, an aptly
named [LeftBehind] exception is raised, causing an HTTP `500 Internal
Server Error` and releasing any resources allocated for the request.

Once the synchronization has ended, the view **performs an SQL
request** to retrieve the data, unserializes it to the expected OCaml
data type, and returns it to the model.
