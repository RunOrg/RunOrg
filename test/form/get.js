// GET /db/{db}/forms/{id}?as={as}
// Forms / Get the meta-data of a form.
// 
// Alpha @ 0.1.37
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Viewer-dependent](/docs/#/concept/viewer-dependent.md).
//
// For a given form, returns the meta-data that can be seen by contact `{as}`.
// Different fields have a different access level, and will be missing unless the
// contact has that access level. 
//
// ### Response format
//     { "id"       : <id>,
//       "owner"    : <owner>,
//       "label"    : <label> | null,
//       "fields"   : [ <field>, ... ],       
//       "custom"   : <json>,
//       "access"   : [ <access>, ... ],
//       "audience" : <form-audience>, }
// - `id` is the identifier of the form.
// - `owner` is the nature of the owners associated with each filled instance
//   of the form. In the current version of the API, this is always `"contact"`
//   (each instance is owned by a contact). 
// - `label` is an optional [human-readable name](/docs/#/types/label.js).
// - `fields` is an ordered list of [fields](/docs/#/form/field.js) to be 
//   filled.
// - `custom` is an arbitrary block of JSON provided by the creator of the
//   form, and returned as-is by the API. 
// - `access` is the list of access levels the contact `{as}` has over the
//   form. See [audience and access](/docs/#/concept/audience.md) for more 
//   information.
// - `audience` (**admin**-only) is the [audience](/docs/#/form/audience.js) of the form.

TEST("The response has valid return code and content type.", function(next) {
    Assert.fail();
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms/0SNQe0032JZ?as=0SNxd0002JZ
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     { "id" : "0SNQe0032JZ",
//       "label" : "Personal information", 
//       "owner" : "contact",
//       "custom" : null,
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
//       } ],
//       "access" : [ "admin", "fill" ],
//       "audience" : {
//         "admin": {},
//         "fill": { groups: [ "0SNQe0032JZ" ] } } }

TEST("Returns correct data in fill level.", function(next) {
    Assert.fail();
});

TEST("Returns correct data in admin level.", function(next) {
    Assert.fail();
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Assert.fail();
});

// - ... if form `{id}` does not exist in database `{db}`

TEST("Returns 404 when form does not exist.", function(next) {
    Assert.fail();
});

// - ... if contact `{as}` does not have at least **fill** 
//   access to view form `{id}`, to ensure [absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form not viewable.", function(next) {
    Assert.fail();
});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access as the named 
//   contact, or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});


 // # Access restrictions
//
// Subject to the form's `fill` [audience](/docs/#/form/audience.md). 
