// POST /db/{db}/forms/create
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

TEST("The response has valid return code and content type.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb(),
        token = Query.auth(db),
        response = Test.query("POST",["db/",db,"/forms/create"],example,token).response();

    response.map(function(r) {
	Assert.areEqual(202, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);
});

// 
// The behaviour of the request depends on whether an identifier was provided: 
// **force-id** mode or **generate-id** mode. 
//
// In force-id mode, RunOrg will attempt to create a form with that identifier,
// and do nothing if such form already exists ([idempotent](/docs/#/concept/idempotent.md)
// request), even if it is different. In other words, these are _create if not exists_
// semantics rather than _create or replace_. 

TEST("Form with forced id appears.", function(next) {
    Assert.fail();
});

TEST("Form with forced id is not overwritten.", function(next) {
    Assert.fail();
});


TEST("New form with forced id created after deletion.", function(next) {
    Assert.fail();
});

//
// In generate-id mode, a new form identifier is generated so that no collisions may
// occur, and a brand new form is created. Repeating the request will generate a new
// form. 

TEST("Multiple creations create multiple forms.", function(next) {
    Assert.fail();
});

//
// ### Example request
//     POST /db/0SNQc00211H/groups/create
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

TEST("Returns 404 when database does not exist.", function(next) {
    Assert.fail();
});

// ## Returns `403 Forbidden`
// - ... if contact `{as}` cannot create a form.

TEST("Returns 403 when contact cannot create a form.", function(next) {
    Assert.fail();
});

// ## Returns `400 Bad Request`
// - ... if the provided identifier is not a valid [custom 
//   identifier](/docs/#/types/custom-id.js)

TEST("Returns 400 when custom id is invalid.", function(next) {
    Assert.fail();
});

// ## Returns `409 Conflict`
// - ... if a form already exists with the provided identifier.

TEST("Returns 409 when the form exists.", function(next) {
    Assert.fail();
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match contact `{as}`,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});

// # Access restrictions
//
// Contact `{as}` must be an [administrator](/docs/#/group/admin.md). 