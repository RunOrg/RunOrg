// POST /db/{db}/forms
// Forms / Create a form
//
// Alpha @ 0.1.38
//
// `202 Accepted`, [Delayed](/docs/#/concept/delayed.md), 
//  sometimes [Idempotent](/docs/#/concept/idempotent.md).
//
// Contact [`{as}`](/docs/#/concept/as.md) creates a new form, initially unfilled.
//
// ### Request format
//     { "id" : <customid> | null,
//       "label" : <label> | null,
//       "custom": <json>,
//       "owner": "contact",
//       "fields": [ <field>, ... ],
//       "audience": <audience> }
// - `id` is an optional [custom identifier](/docs/#/types/custom-id.js).
// - `label` is an optional [human-readable name](/docs/#/types/label.js).
// - `custom` is an arbitrary block of JSON that will be stored as-is by 
//   RunOrg and returned as such by the API.
// - `owner` is the nature of the owners associated with each filled instance
//   of the form. In the current version of the API, this is always `"contact"`
//   (each instance is owned by a contact). 
// - `fields` is an ordered list of [fields](/docs/#/form/field.js) to be 
//   filled.
// - `audience` is the [audience](/docs/#/form/audience.js) of the form.
// 
// ### Response format
//     { "id" : <id>,
//       "at" : <clock> }

TEST("The response has valid return code and content type.", function(Query) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var response = Query.post(["db/",db,"/forms"],example,auth);

    return response.then(function(d,s,r) {
	return $.when(
	    Assert.areEqual(202, r.status),
	    Assert.isTrue(r.responseJSON, "Response type is JSON")
	);
    });

});

// 
// The behaviour of the request depends on whether an identifier was provided: 
// **force-id** mode or **generate-id** mode. 
//
// In force-id mode, RunOrg will attempt to create a form with that identifier,
// and do nothing if such form already exists ([idempotent](/docs/#/concept/idempotent.md)
// request), even if it is different. In other words, these are _create if not exists_
// semantics rather than _create or replace_. 

TEST("Form with forced id appears.", function(Query) {

    var example = {
	"id": "personal",
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],example,auth).then(function(r) { return r.id; });
    var owner = Query.get(["db/",db,"/forms/",id],auth).then(function(r) { return r.owner; });
    
    return $.when(
	Assert.areEqual(example.id,id),
	Assert.areEqual(example.owner,owner)
    );

});

//
// In generate-id mode, a new form identifier is generated so that no collisions may
// occur, and a brand new form is created. Repeating the request will generate a new
// form. 

TEST("Multiple creations create multiple forms.", function(Query) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id1 = Query.post(["db/",db,"/forms"],example,auth).then(function(r) { return r.id; });
    var id2 = Query.post(["db/",db,"/forms"],example,auth).then(function(r) { return r.id; });

    return Assert.notEqual(id1, id2);

});

//
// ### Example request
//     POST /db/0SNQc00211H/forms
//     Content-Type: application/json
// 
//     { "label" : "Personal information", 
//       "owner" : "contact",
//       "audience" : {
//         "admin": {},
//         "fill": { groups: [ "0SNQe0032JZ" ] } },
//       "fields" : [ {
//         "id" : "1",
//         "label" : "Why did you join our group ?",
//         "kind" : "text",
//         "required" : true
//       }, {
//         "id" : "2", 
//         "label" : "How often do you log in ?",
//         "kind" : "single",
//         "choices" : [
//           "Every day",
//           "Once a week",
//           "Once a month",
//           "Less than once a month" ],
//         "required" : false
//       } ] }
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
// 
//     { "id" : "0SNQe0032JZ",
//       "at" : [[2,219]] }
  
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    return Query.post(["db/00000000000/forms"],example).then(function(d,s,r) {
	return Assert.areEqual(404, r.status);
    });
        
});

// ## Returns `403 Forbidden`
// - ... if contact `{as}` cannot create a form.

TEST("Returns 403 when contact cannot create a form.", function(Query) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db,false);
    
    return Query.post(["db/",db,"/forms"],example,auth).then(function(d,s,r) {
	return Assert.areEqual(403, r.status);
    });
    
});

// ## Returns `400 Bad Request`
// - ... if the provided identifier is not a valid [custom 
//   identifier](/docs/#/types/custom-id.js)

TEST("Returns 400 when custom id is invalid.", function(Query) {   

    var ex1 = { "id": "a-b", "fields": [], "audience": {}, "owner": "contact" };
    var ex2 = { "id": "0123456789a",  "fields": [], "audience": {}, "owner": "contact" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var r1 = Query.post(["db/",db,"/forms"],ex1,auth).then(function(d,s,r) { return r.status; });
    var r2 = Query.post(["db/",db,"/forms"],ex2,auth).then(function(d,s,r) { return r.status; });
    
    return $.when(
	Assert.areEqual(400, r1),
	Assert.areEqual(400, r2)
    );

});

// ## Returns `409 Conflict`
// - ... if a form already exists with the provided identifier.

TEST("Returns 409 when the form exists.", function(Query) {

    var example = {
	"id": "personal",
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],example,auth).then(function(d) { return d.id; });

    var example2 = {
	"id": id,
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    return Query.post(["db/",db,"/forms"],example2,auth).then(function(d,s,r) {
	return Assert.areEqual(409, r.status);
    });
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match contact `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {

    var example = {
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    return Query.post(["db/",db,"/forms"],example,{token:"0123456789a",id:"0123456789a"}).then(function(d,s,r) {
	return Assert.areEqual(401, r.status);
    });
});

// # Access restrictions
//
// Contact `{as}` must be a [database administrator](/docs/#/group/admin.md). 