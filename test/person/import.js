// POST /db/{db}/contacts/import
// People / Import people by e-mail
//
// Alpha @ 0.1.22
//
// `202 Accepted`, 
// [Delayed](/docs/#/concept/delayed.md), 
// [Sync Idempotent](/docs/#/concept/sync-idempotent.md).

TEST("The response has valid return code and content type.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/people/import"],[example],auth)
	.assertStatus(202).assertIsJson();

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
//     { "imported": [ <id>, ... ], 
//       "at": <clock> }
// - `imported` is a list of all identifiers associated to the imported people, 
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
//     { "imported": [ "0Et9j0026rO", "0SMXP00G0ON" ],
//       "at": [[2,87]] }

TEST("Single import works.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });
    
    var created = Query.get(["db/",db,"/people/",id],auth)
	.then(function(d) { return d; });

    var expected = { 
	"id": id, 
	"label": "Victor Nicollet",
	"gender": "M", 
	"pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" 
    };
    
    return Assert.areEqual(expected, created);

});

//
// # Duplicate entries
// 
// Duplicate entries (that is, entries for which a person already exists with
// the same email address) will be silently ignored, and the identifier for the 
// old person will be returned. 
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
//
// ## Returns `401 Unauthorized`
// - ... if the provided token does not allow importing new people, or no token
//   was provided

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/people/import"],[],{id:"0123456789a",token:"01234567890"})
	.assertStatus(401);
});

// ## Returns `403 Forbidden`
// - ... if person `{as}` is not allowed to import people.

TEST("Returns 403 when not allowed to import contacts.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db,false);
    return Query.post(["/db/",db,"/people/import"],[],auth).assertStatus(403);
});

// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post("/db/00000000001/people/import",[]).assertStatus(404);
});


// # Access restrictions
//
// Only [database administrators](/docs/#/group/admin.md) are allowed to import
// people into the database.