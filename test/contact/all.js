// GET /db/{db}/contacts
// Contacts / List all contacts in the database
//
// Alpha @ 0.1.22
// 
// `200 OK`, 
// [Invariant](/docs/#/concept/invariant.js)
// [Paginated](/docs/#/concept/paginated.js).
//
// Returns all the contacts in the database, in arbitrary order.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <shortcontact>, ... ],
//       "count": <int> }
// - `list` is a list of contacts on the requested page, in 
//   [short format](/docs/#/contact/short-contact.js)
// - `count` is the total number of contacts in the database.

TEST("The response has valid return code and content type.", function(next) {

    var db = Query.mkdb(),
        token = Query.auth(db),
        response = Test.query("GET",["db/",db,"/contacts"],{},token).response();

    response.map(function(r) {
	Assert.areEqual(200, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/contacts?limit=3?offset=213
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "list" : [ 
//       { "id" : "0SNQe00311H",
//         "name" : "test@runorg.com",
//         "gender" : null,
//         "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70" },
//       { "id" : "0SNQg00511H",
//         "name" : "vnicollet@runorg.com",
//         "gender" : null,
//         "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060"} ],
//       "count" : 215 }

TEST("Returns correct number of contacts in count.", function(next) {

    var example = { "email" : "vnicollet@runorg.com",
		    "fullname" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb(), token = Query.auth(db);
    
    Test.query("POST",["db/",db,"/contacts/import"],[example],token).always().then(function() {

	var count = Test.query("GET",["db/",db,"/contacts?limit=0"],{},token).result("count");
	Assert.areEqual(2, count).then(next);	

    });       

});

TEST("Returns data for all contacts.", function(next) {

    var example = [ { "email": "test@runorg.com" },
		    { "email" : "vnicollet@runorg.com",
		      "fullname" : "Victor Nicollet",
		      "gender" : "M" } ];

    var db = Query.mkdb(), token = Query.auth(db);
    Test.query("POST",["db/",db,"/contacts/import"],example,token).result('created').map(function(ids){ 
	    
	var list = Test.query("GET",["db/",db,"/contacts"],{},token).result("list");

	var expected = [ 
	    { "id" : ids[0],
	      "name" : "test@runorg.com",
	      "gender" : null,
	      "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70" },		
	    { "id" : ids[1], 
	      "name" : "Victor Nicollet",
	      "gender" : "M", 
	      "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" } ];
	
	Assert.areEqual(expected, list).then(next);

    }).then();
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Test.query("GET","/db/00000000001/contacts/00000000002/").error(404).then(next);
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access to all contacts,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
    var db = Query.mkdb();
    Test.query("GET",["db/",db,"/contacts"]).error(401).then(function() {
	Test.query("GET",["db/",db,"/contacts"],{},"0123456789a").error(401).then(next);
    });
});
 
// # Access restrictions
//
// Currently, anyone can list all contacts with a token for the corresponding database. 
// This is subject to change in future versions.
