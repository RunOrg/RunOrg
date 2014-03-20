// POST /db/{db}/keys/create
// Keys / Create new API key
//
// Alpha @ 0.1.34
// 
// `202 Accepted`,
// [Delayed](/docs/#/concept/delayed.md).

TEST("The response has valid return code and content type.", function(next) {
    Assert.fail();
});

//
// Create a new key in this database. It can immediately be used to 
// authenticate requests.
//
// The IP address of the client will be logged by this request.
//
// ### Key creation format
//     { "hash": <string>,
//       "key": <string>,
//       "encoding": <string> }
// - `hash` is the hash function used for the HMAC algorithm. Currently, 
//   the only supported value is `"SHA-1"`.
// - `key` is the raw key data. 
// - `encoding` is the encoding used for the `key` field. Currently,
//   the only supported value is `"hex"`. 
//
// For SHA-1, the recommended key length is 64 bytes, or 128 hex characters. 
// You may use shorter keys (they will be padded with zeros). 
// Longer keys are not currently supported.
//
// ### Response format
//     { "id": <id>, 
//       "at": <clock> }
// - `id` is the key-id under which the key will be available.
// - `at` indicates the [clock position](/docs/#/types/clock.js) when 
//   the key will be available for use.
//
// # Example
// 
// ### Example request
//     POST /db/0Et4X0016om/keys/create
//     Content-Type: application/json 
//    
//     { "hash": "SHA-1",
//       "key": "74e6f7298a9c2d168935f58c001bad88",
//       "encoding": "hex" }
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
//
//     { "created": "0Et9j0026rO",
//       "at": [[2,87]] }

TEST("Creation works.", function(next) {
    Assert.fail();
});

// # Errors
//
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Test.query("POST","/db/00000000001/keys/create",{}).error(404).then(next);
});

//
// ## Returns `401 Unauthorized`
// - ... if the provided token does not allow the creation of keys, or no token
//   was provided

TEST("Returns 401 when token is not valid.", function(next) {
    var db = Query.mkdb();
    Test.query("POST",["db/",db,"/keys/create"],[]).error(401).then(function() {
	Test.query("POST",["db/",db,"/keys/create"],[],"0123456789a").error(401).then(next);
    });
});

//
// # Access restrictions
//
// Only database administrators can create new keys. 