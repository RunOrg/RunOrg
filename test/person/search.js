// GET /db/{db}/people/search
// People / Search for people by name
//
// Alpha @ 0.1.28
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Returns a set of people from the database that match the search query. 
// Follows the rules for [search relevance](/docs/#/concept/search.md).
// 
// ### Response format
//     { "list": [ <short>, ... ] }
// - `list` is a list of people matching the query, in order of 
//   decreasing relevance. 

TODO("The response has valid return code and content type.", function(next) {

    var db = Query.mkdb(),
        token = Query.auth(db),
    response = Test.query("GET",["db/",db,"/people"],{q:""},token).response();

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
//     GET /db/0SNQc00211H/people?limit=3&q=vic
//
// ### Example response
//     200 OK
//     Content-Type: application/json
// 
//     { "list" : [ 
//       { "id" : "0SNQg00511H",
//         "label" : "Victor Nicollet",
//         "gender" : "M",
//         "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" } ] }

TODO("Returns data for matching people.", function(next) {

    var example = [ { "email": "test@runorg.com" },
		    { "email" : "vnicollet@runorg.com",
		      "fullname" : "Victor Nicollet",
		      "gender" : "M" } ];

    var db = Query.mkdb(), token = Query.auth(db);
    Test.query("POST",["db/",db,"/people/import"],example,token).result('created').map(function(ids){ 
	    
	var list = Test.query("GET",["db/",db,"/people/search"],{q:"vic"},token).result("list");

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

TODO("Returns 404 when database does not exist.", function(next) {
    Test.query("GET","/db/00000000001/people/00000000002/").error(404).then(next);
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access to all people,
//   or no token was provided

TODO("Returns 401 when token is not valid.", function(next) {
    var db = Query.mkdb();
    Test.query("GET",["db/",db,"/people"]).error(401).then(function() {
	Test.query("GET",["db/",db,"/people"],{},"0123456789a").error(401).then(next);
    });
});
 
// # Access restrictions
//
// Currently, anyone can list all people with a token for the corresponding database. 
// This is subject to change in future versions.
