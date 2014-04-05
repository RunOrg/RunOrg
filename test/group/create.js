// POST /db/{db}/groups/create
// Groups / Create a group
// 
// Alpha @ 0.1.37
//
// `202 Accepted`, 
// [Delayed](/docs/#/concept/delayed.md).
// sometimes [Idempotent](/docs/#/concept/idempotent.md).
//
// Creates a new group. Initially empty. 
// 
// ### Request format
//     { "id" : <customid> | null,
//       "label" : <label> | null }
//  - `id` is an optional [custom identifier](/docs/#/types/custom-id.js).
//  - `label` is an optional [human-readable name](/docs/#/types/label.js).
//
// ### Response format
//     { "id" : <id>,
//       "at" : <clock> }

TEST("The response has valid return code and content type.", function(next) {

    var example = { "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var response = Test.query("POST",["db/",db,"/groups/create"],example,auth).response();

    [
	Assert.areEqual(202, response.map('status')),
	Assert.isTrue(response.map('responseJSON'), "Response type is JSON")
    ].then(next);

});

// 
// The behaviour of the request depends on whether an identifier was provided: 
// **force-id** mode or **generate-id** mode. 
//
// # Force-id mode
// 
// RunOrg will attempt to create a group with that identifier, and do nothing if 
// the group already exists ([idempotent](/docs/#/concept/idempotent.md)
// request). 
//
// ### Example request
//     POST /db/0SNQc00211H/groups/create
//     Content-Type: application/json
// 
//     { "id": "board", 
//       "label": "Board members" }
//
// ### Example request
//     202 Accepted
//     Content-Type: application/json
// 
//     { "id" : "board",
//       "at" : [[2,218]] }

TEST("Group with forced id appears.", function(next) {

    var id = "board";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    Test.query("POST",["db/",db,"/groups/create"],example,auth).response().then(function(){

	var get = Test.query("GET",["db/",db,"/groups/",id,"/info"],auth).result();
	
	[
	    Assert.areEqual({"id":id,"label":"Board members",count:0}, get)
	].then(next);

    });

});

TEST("New group with forced id created after deletion.", function(next) {

    var id = "board";
    var example = { "id" : id, "label" : "Broad members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    Test.query("POST",["db/",db,"/groups/create"],example,auth).response().then(function(){

	Test.query("DELETE",["db/",db,"/groups/",id],auth).response().then(function(){

	    example.label = "Board members";

	    Test.query("POST",["db/",db,"/groups/create"],example,auth).response().then(function(){

		var get = Test.query("GET",["db/",db,"/groups/",id,"/info"],auth).result();
		
		[
		    Assert.areEqual({"id":id,"label":"Board members",count:0}, get)
		].then(next);
	    });
	});
    });
});

// # Generate-id mode
// 
// RunOrg will create brand new group, with a brand new identifier. Running the
// request twice will create two groups.
// 
// ### Example request
//     POST /db/0SNQc00211H/groups/create
//     Content-Type: application/json
// 
//     { "label": "Members imported on Nov 1, 2013" }
//
// ### Example request
//     202 Accepted
//     Content-Type: application/json
// 
//     { "id" : "0SNQe0032JZ",
//       "at" : [[2,219]] }

TEST("Multiple creations create multiple groups.", function(next) {

    var example = { "label" : "Sample group" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id1 = Test.query("POST",["db/",db,"/groups/create"],example,auth).result("id");
    var id2 = Test.query("POST",["db/",db,"/groups/create"],example,auth).result("id");

    var get1 = Test.query("GET",["db/",db,"/groups/",id1,"/info"],auth).result();
    var get2 = Test.query("GET",["db/",db,"/groups/",id2,"/info"],auth).result();
    
    
    [
	Assert.notEqual(id1, id2),
	Assert.areEqual({"id":id1,"label":"Sample group",count:0}, get1),
	Assert.areEqual({"id":id2,"label":"Sample group",count:0}, get2)
    ].then(next);
	    
});

// # Errors
//
// ## Returns `400 Bad Request`
// - ... if the provided identifier is not a valid [custom 
//   identifier](/docs/#/types/custom-id.js)

TEST("Returns 400 when custom id is invalid.", function(next) {

    var ex1 = { "id": "a-b", "label" : "Invalid character" };
    var ex2 = { "id": "0123456789a", "label" : "Too long" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var r1 = Test.query("POST",["db/",db,"/groups/create"],ex1,auth).response();
    var r2 = Test.query("POST",["db/",db,"/groups/create"],ex2,auth).response();
    
    [
	Assert.areEqual(400, r1.map('status')),
	Assert.areEqual(400, r2.map('status'))
    ].then(next);

});
 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    var response = Test.query("POST",["db/01234567890/groups/create"],{},"00000000000").response();
    Assert.areEqual(404, response.map('status')).then(next);
});

// ## Returns `400 Conflict`
// - ... if a group already exists with the provided identifier.

TEST("Returns 409 when the group exists.", function(next) {

    var id = "board";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    Test.query("POST",["db/",db,"/groups/create"],example,auth).response().then(function(){
	var response = Test.query("POST",["db/",db,"/groups/create"],example,auth).response();
	Assert.areEqual(409, response.map('status')).then(next);
    });
});

TEST("Returns 409 when re-creating the admin group.", function(next) {

    var id = "admin";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var response = Test.query("POST",["db/",db,"/groups/create"],example,auth.tok).response();
    Assert.areEqual(409, response.map('status')).then(next);
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match the `as` contact.

TEST("Returns 401 when token is not valid.", function(next) {
    var db = Query.mkdb();
    Test.query("POST",["db/",db,"/groups/create"],{},{tok:"0123456789a",id:"0123456789a"})
	.error(401).then(next);    
});

// # Access restrictions
//
// Currently, anyone can create a group with a token for the corresponding database. 
// This is subject to change in future versions.
