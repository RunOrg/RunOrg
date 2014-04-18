// GET /db/{db}/forms/{id}/filled
// Forms / List all filled instances of a form.
// 
// Alpha @ 0.1.44
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the filled instances of form `{id}`.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ { 
//          "owner": <id>,
//          "data": { <key> : <value> }
//        }, ... ],
//       "count": <int> }
// - `list` is a list of form instances on the requested page.
// - `list[].owner` is the identifier of the entity that owns the filled
//   form instance, such as a contact.
// - `list[].data` is the data used to [fill the form](/docs/#/form/fill.js),
//   returned as-is.
// - `count` is the number of form instances available. 

TEST("The response has valid return code and content type.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": {},
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,token).result('id');

    var response = Test.query("GET",["db/",db,"/forms/",id,"/filled"],token).response();

    response.map(function(r) {
	Assert.areEqual(200, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms/0SNQc00711H/filled?as=0Sd7003511H&limit=3&offset=213
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "list" : [ { 
//         "owner" : "0SNQe00311H",
//         "data": { "color" : "Orange", "birth" : "1985-04-19" } 
//       }, { 
//         "owner" :  "0SNQe00311H",
//         "data": { "birth" : "2013-10-08" }
//       } ],
//       "count": 215 }

TEST("Returns correct items and count.", function(next) {

    var form = {
	"owner": "contact",	
	"audience": { "fill": "anyone" },
	"label": "Join form",
	"fields": [ {
	    "id": "1",
	    "label": "Why did you join our group ?",
	    "kind": "text",
	    "required": true
	} ]
    };

    var data1 = {"data":{"1":"Networking"}};
    var data2 = {"data":{"1":"Recommendation"}};

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,auth).result("id");
    var peon = Query.auth(db,false,"peon@runorg.com");

    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],data1,auth).result().then(function() {
	Test.query("PUT",["db/",db,"/forms/",id,"/filled/",peon.id],data2,auth).result().then(function() {
	
	    var item1 = { "owner" : auth.id, "data" : data1.data };
	    var item2 = { "owner" : peon.id, "data" : data2.data };
	    
	    var expected1 = { "list" : [ item2, item1 ], "count" : 2 };
	    var expected2 = { "list" : [ item2 ], "count" : 2 };
	    var expected3 = { "list" : [ item1 ], "count" : 2 };
					 
	    var list1 = Test.query("GET",["db/",db,"/forms/",id,"/filled"],auth).result();
	    var list2 = Test.query("GET",["db/",db,"/forms/",id,"/filled?limit=1"],auth).result();
	    var list3 = Test.query("GET",["db/",db,"/forms/",id,"/filled?offset=1"],auth).result();

	    [
		Assert.areEqual(expected1, list1),
		Assert.areEqual(expected2, list2),
		Assert.areEqual(expected3, list3)
	    ].then(next);

	});
    });

});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Test.query("GET",["db/00000000000/forms/00000000001/filled"]).error(404).then(next);
});

// - ... if form `{id}` does not exist in database `{db}` 

TEST("Returns 404 when form does not exist.", function(next) {
    var db = Query.mkdb();
    Test.query("GET",["db/",db,"/forms/00000000001/filled"]).error(404).then(next);
});

// - ... if contact `{as}` cannot view form `{id}`

TEST("Returns 404 when form cannot be viewed.", function(next) {

    var form = {
	"owner": "contact",	
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,auth).result("id");
    
    Test.query("GET",["db/",db,"/forms/",id,"/filled"]).error(404).then(next);

});

// ## Returns `403 Forbidden`
// - ... if contact `as` does not have **admin** access to the form.

TEST("Returns 404 when form cannot be viewed.", function(next) {

    var form = {
	"owner": "contact",	
	"audience": { "fill": "anyone" },
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,auth).result("id");
    var peon = Query.auth(db,false,"peon@runorg.com");

    Test.query("GET",["db/",db,"/forms/",id,"/filled"],peon).error(403).then(next);

});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant mathch contact `{as}`.

TEST("Returns 401 when token is not valid.", function(next) {

    var form = {
	"owner": "contact",	
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,auth).result("id");
 
    Test.query("GET",["db/",db,"/forms/",id,"/filled"],{token:"012345789a",id:"0123456789a"})
	.error(401).then(next);
});
 
// # Access restrictions
//
// [**Admin** access](/docs/#/form/audience.js) is required to view all filled form instances. 
