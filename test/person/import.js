// POST /db/{db}/contacts/import
// People / Import people by e-mail
//
// Alpha @ 0.1.22
//
// `202 Accepted`, 
// [Delayed](/docs/#/concept/delayed.md), 
// [Sync Idempotent](/docs/#/concept/sync-idempotent.md).

TODO("The response has valid return code and content type.", function(next) {

    var example = { "email" : "vnicollet@runorg.com" };

    var db = Query.mkdb(),
        token = Query.auth(db),
        response = Test.query("POST",["db/",db,"/people/import"],[example],token).response();

    response.map(function(r) {
	Assert.areEqual(202, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);

});

//
// Post a list of people to be imported, and receive the identifiers assigned to 
// every one of them. The format for the imported people is: 
// 
// ### Contact import format
//     [ { "email"      : <label>,
//         "name"       : <label>,
//         "givenName"  : <label>,
//         "familyName" : <label>,
//         "gender"     : "M" | "F" 
//     }, ... ]
// - `email` is the only **mandatory** field, and should contain a valid e-mail 
//   address for the contact being created. 
// - `name` is optional, but filling it is recommended nonetheless, 
//   as it will be used as the display name of the contact (that is, it will 
//   become field `label` of the [<short>](/docs/#/contact/short.js) 
//   values returned by the API).
// - `givenName` is optional.
// - `familyName` is optional.
// - `gender` is optional.
//
// You may skip the `givenName` and `familyName` fields safely. This will be the
// case for people in a culture that does not have such naming conventions, or simply 
// because the data is unavailable (it may be provided later).
//
// There is no limit on the number of people to be provided, though the request
// may bounce due to the [global limit on request body sizes](/docs/#/config/httpd.js). 
// 
// ### Response format
//     { "created": [ <id>, ... ], 
//       "at": <clock> }
// - `created` is a list of all identifiers associated to the imported people, 
//   in the same order as the array of people in the request. 
// - `at` indicates the [clock position](/docs/#/types/clock.js) when all the
//   imported people will be available. 
//
// # Example
// 
// ### Example request
//     POST /db/0Et4X0016om/people/import
//     Content-Type: application/json 
//    
//     [ {"email":"vnicollet@runorg.com","fullname":"Victor Nicollet","gender":"M"}, 
//       {"email":"test@example.com"} ]
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
//
//     { "created": [ "0Et9j0026rO", "0SMXP00G0ON" ],
//       "at": [[2,87]] }

TODO("Single import works.", function(next) {

    var example = { "email" : "vnicollet@runorg.com",
		    "fullname" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb(),
        token = Query.auth(db),
        id = Test.query("POST",["db/",db,"/people/import"],[example],token).result('created',0),
        created = Test.query("GET",["db/",db,"/people/",id],{},token).result();

    var expected = { "id": id, 
		     "name": "Victor Nicollet",
		     "gender": "M", 
		     "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" };

    Assert.areEqual(expected, created).then(next);

});

//
// # Duplicate entries
// 
// Duplicate entries (that is, entries for which a contact already exists with
// the same email address) will be silently ignored, and the identifier for the 
// old contact will be returned. 
//
// Please note that the `email` field is not a strict uniqueness constraint: 
// there are normal situations under which two or more people may share an
// email address. The import procedure will avoid creating such duplicates for 
// your convenience, but does not guarantee uniqueness. In particular, if two 
// imports run in parallel with duplicate data, then duplicate email addresses 
// may appear.
// 
// # Errors
//
// If you sent this request but did not receive a response (network timeouts, 
// internal server errors...), use the fact that it is 
// [Sync Idempotent](/docs/#/concepts/sync-idempotent.js). 
//
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TODO("Returns 404 when database does not exist.", function(next) {
    Test.query("POST","/db/00000000001/people/import",{}).error(404).then(next);
});

//
// ## Returns `401 Unauthorized`
// - ... if the provided token does not allow importing new people, or no token
//   was provided

TODO("Returns 401 when token is not valid.", function(next) {
    var db = Query.mkdb();
    Test.query("POST",["db/",db,"/people/import"],[]).error(401).then(function() {
	Test.query("POST",["db/",db,"/people/import"],[],"0123456789a").error(401).then(next);
    });
});

//
// # Access restrictions
//
// Currently, anyone can import people with a token for the corresponding 
// database. This is subject to change in future versions.
