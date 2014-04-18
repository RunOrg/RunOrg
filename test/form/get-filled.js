// GET /db/{db}/forms/{id}/filled/{owner}
// Forms / Get the data from a filled form.
// 
// Alpha @ 0.1.43
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Contact [`{as}`](/docs/#/concept/as.md) retrieves returns the data entered into
// an instance of form `{id}` bound to entity `{owner}`. 
//
// ### Response format
//     { "data": { <key> : <value> },
//       "owner": <id> }
//
// - `data` contains a dictionary mapping field names to arbitrary JSON values, 
//   as they were provided when [filling the form](/docs/#/form/fill.js). 
// - `owner` contains the owner identifier provied in the URL: it identifies the
//   entity to which the filled form instance is bound.  
//
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

    var data = { "data": { "color" : "Red" } };

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,token).result('id');

    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",token.id],data,token).response().then(function(){

	var response = Test.query("GET",["db/",db,"/forms/",id,"/filled/",token.id],token).response();
	response.map(function(r) {
	    Assert.areEqual(200, r.status).then();
	    Assert.isTrue(r.responseJSON, "Response type is JSON").then();
	}).then(next);
	
    });
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms/0SNQe0032JZ/filled/0SNxd0002JZ?as=0SNxd0002JZ
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     { "data" : {
//         "color" : "orange",
//         "born"  : "1985-04-18" },
//       "owner" : "0SNxd0002JZ" }

TEST("Returns correct data.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": {},
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "color" : "Red" };

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,token).result('id');

    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",token.id],{"data":data},token).response().then(function(){

	var result = Test.query("GET",["db/",db,"/forms/",id,"/filled/",token.id],token).result();

	var expected = {
	    "owner" : token.id,
	    "data" : data
	};

	Assert.areEqual(expected, result).then(next);

    });

});


// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {

    Test.query("GET",["db/00000000000/forms/00000000001/filled/00000000002"])
	.error(404).then(next);

});

// - ... if form `{id}` does not exist in database `{db}`

TEST("Returns 404 when form does not exist.", function(next) {

    var db = Query.mkdb();

    Test.query("GET",["db/",db,"/forms/00000000001/filled/00000000002"])
	.error(404).then(next);

});

// - ... if form `{id}` has not been filled for entity `{owner}`.

TEST("Returns 404 when form is not filled.", function(next) {

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

    Test.query("GET",["db/",db,"/forms/",id,"/filled/",token.id],token)
	.error(404).then(next);

});


// - ... if contact `{as}` is not allowed to view form `{id}, to ensure 
// [absence equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form not viewable.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": {},
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "data": { "color" : "Red" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,auth).result("id");

    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],data,auth).response().then(function(){
    
	var peon = Query.auth(db,false,"peon@runorg.com");
	Test.query("GET",["db/",db,"/forms/",id,"/filled/",auth.id],peon)
	    .error(404).then(next);

    });
});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access as the named 
//   contact, or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {

    var example = {
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],example,auth).result("id");

    Test.query("GET",["db/",db,"/forms/",id,"/filled/",auth.id],{tok:"0123456789a",id:"0123456789a"})
	.error(401).then(next);    

});


// ## Returns `403 Forbidden`
// - ... if contact `{as}` is can view the form, but not the requested 
//   instance. For instance, without **admin** access, a contact may only
//   view the instance bound to himself (`{owner} == {as}`), and not to 
//   other contacts. Access restrictions are defined for each type of 
//   owner.

TEST("Returns 403 when form instance not viewable.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": { "fill" : "anyone" },
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "data": { "color" : "Red" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],form,auth).result("id");

    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],data,auth).response().then(function(){
    
	var peon = Query.auth(db,false,"peon@runorg.com");
	Test.query("GET",["db/",db,"/forms/",id,"/filled/",auth.id],peon)
	    .error(403).then(next);

    });
});


// # Access restrictions
//
// Contact must have `fill` [audience](/docs/#/form/audience.md) access to 
// the form, and be able to view the instance.
