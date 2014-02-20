// GET /db/{db}/contacts/search
// Contacts / Search for contacts by name
//
// Alpha @ 0.1.28
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Returns a set of contacts from the database that match the search query. 
// Follows the rules for [search relevance](/docs/#/concept/search.md).
// 
// ### Response format
//     { "list": [ <shortcontact>, ... ] }
// - `list` is a list of contacts matching the query, in order of 
//   decreasing relevance. 

TEST("The response has valid return code and content type.", function(next) {

    var db = Query.mkdb(),
        token = Query.auth(db),
    response = Test.query("GET",["db/",db,"/contacts"],{q:""},token).response();

    response.map(function(r) {
	Assert.areEqual(200, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
	Assert.areEqual([],r.responseJSON).then();
    }).then(next);

});

//
// The search query is provided as GET parameter `q`.
//
// # Examples
//
// ### Example request
//     GET /db/0SNQc00211H/contacts?limit=3&q=vic
//
// ### Example response
//     200 OK
//     Content-Type: application/json
// 
//     { "list" : [ 
//       { "id" : "0SNQg00511H",
//         "name" : "Victor Nicollet",
//         "gender" : "M",
//         "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" } ] }

TEST("Returns data for matching contacts.", function(next) {

    var example = [ { "email": "test@runorg.com" },
		    { "email" : "vnicollet@runorg.com",
		      "fullname" : "Victor Nicollet",
		      "gender" : "M" } ];

    var db = Query.mkdb(), token = Query.auth(db);
    Test.query("POST",["db/",db,"/contacts/import"],example,token).result('created').map(function(ids){ 
	    
	var list = Test.query("GET",["db/",db,"/contacts/search"],{q:"vic"},token).result("list");

	var expected = [ 
	    { "id" : ids[1], 
	      "name" : "Victor Nicollet",
	      "gender" : "M", 
	      "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" } ];
	
	Assert.areEqual(expected, list).then(next);

    }).then();
});

//
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
