// GET /db/{db}/chat/{id}
// Chatrooms / Read chatroom properties
//
// Beta @ 0.9.0
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Reads chatroom information (except the list of messages). 
// Data is returned using a [client join pattern](/docs/#/concept/client-join.md): 
//
// ### Response format
//     { "contacts": [ <shortcontact>, ... ],
//       "groups": [ <groupinfo>, ... ],
//       "info": <chatinfo> }
//  - `contacts` is a list of [short profiles](/docs/#/contact/short-contact.js) for 
//    all participants in the chatroom.
//  - `groups` is the [basic information](/docs/#/group/group-info.js)
//    for all groups present in the chatroom.
//  - `info` is a [chatroom information object](/docs/#/chat/chat-info.js).

TODO("The response has valid return code and content type.", function(next) {
    Assert.fail();
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/chat/0SNQe0132FW
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "contacts": [
//       { "id" : "0SNQe00311H",
//         "name" : "test@runorg.com",
//         "gender" : null,
//         "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70" },
//       { "id" : "0SNQg00511H",
//         "name" : "vnicollet@runorg.com",
//         "gender" : null,
//         "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060"} ],
//       "groups": [
//         { "id": "0SNQe0032JZ",
//         "label": "Team members",
//         "count" : 215 } ],
//       "info": { 
//         "id": 0SNQe0132FW,
//         "contacts": ["0SNQe00311H","0SNQg00511H"],
//         "groups": ["0SNQe0032JZ"],
//         "subject": "Preparation for the next meeting",
//         "public": false,
//         "count": 118 }}

TODO("Returns correct list of contacts.", function(next) {
    Assert.fail();
});

TODO("Returns correct list of groups.", function(next) {
    Assert.fail();
});

TODO("Returns correct message count.", function(next) {
    Assert.fail();
});

TODO("Returns correct subject.", function(next) {
    Assert.fail();
});

// 
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TODO("Returns 404 when database does not exist.", function(next) {
    Assert.fail();
});

// - ... if chatroom `{id}` does not exist in database `{db}`

TODO("Returns 404 when chatroom does not exist.", function(next) {
    Assert.fail();
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access to the chatroom,
//   or no token was provided

TODO("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});
 
// # Access restrictions
//
// Currently, anyone can read the basic details of a chatroom with a token for the corresponding database. 
// This is subject to change in future versions.
       


