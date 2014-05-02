// POST /db/{db}/people/auth/persona
// People / Authenticate with Mozilla Persona
//
// Beta @ 0.9.0
//
// `202 Accepted`, [Sync idempotent](/docs/#/concept/sync-idempotent.md).
//
// Processes a [Mozilla Persona assertion](https://developer.mozilla.org/en-US/Persona/The_navigator.id_API)
// and authenticates the corresponding person based on the email address contained
// in the assertion. 
//
// If no such person exists, a new person is created using the email address. 
//
// ### Result format
//     { "token": <token>,
//       "self" : <shortperson>, 
//       "at"   : <clock> }
// - `token` is an [authentication token](/docs/#/types/token.js). 
// - `self ` is the [short profile](/docs/#/person/short-person.js) for the authenticated
//   person.
// - `at` is the time when the person (if it was created by this request) will be present
//   in the database. The authentication token is always available straight away, regardless
//   of this clock.
//
// The assertion validator expects the audience to be the [database persona audience](/docs/#/db/audience.js).
// If no audience was configured, this will be `https://api.runorg.com`. 
//
// ### Example request
//     POST /db/0Et4X0016om/people/auth/persona
//     Content-Type: application/json
//     { "assertion": "eyJhbGciOiJSUzI1NiJ9.eyJwdWJs..." }
//     
// ### Example response
//     202 Accepted 
//     Content-Type: application/json
//
//     { "token": "7Rq03AsR92W",
//       "self": { 
//         "id" : "0Et9j0026rO",
//         "label" : "Victor Nicollet",
//         "gender" : "M", 
//         "pic" : "https://www.gravatar.com/avatar/648e25e4372728b2d3e0c0b2b6e26f4e" },
//       "at": [[1,23]] }
//
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TODO("Returns 404 when database does not exist.", function(next) {
    Test.query("POST","/db/00000000001/people/auth/persona",{assertion:'x'}).error(404).then(next);
});

// 
// ## Returns `400 Bad Request` 
// - ... if the assertion is not valid.

TODO("Returns 400 when assertion is invalid.", function(next) {
    var db = Query.mkdb();    
    Test.query("GET",["/db/",db,"/people/auth/persona"],{assertion:'x'}).error(400).then(next);
});

// # Access restrictions
//
// None: anyone can attempt to authenticate. 