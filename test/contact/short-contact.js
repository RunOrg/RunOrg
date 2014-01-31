// JSON <shortcontact>
// Contacts / A short representation of a contact
// 
// Returned by most API methods that involve contacts. It is intended to 
// provide data relevant for displaying the contact: its name, picture 
// and gender. 
// 
// Typical examples: [listing contacts in a group](/docs/#/group/list.js) or 
// [displaying the messages in a chatroom](/docs/#/chat/messages.js). 
//
// ### `ShortContact` JSON format
//     { id : <id>, 
//       name : <label>, 
//       gender : "F" | "M" | null,
//       pic : <url> }
// 
// - `id` is the [unique 11-character identifier](/docs/#/types/id.js) for this 
//   contact

TEST("The contact's identifier is returned.", function() {
    Assert.fail();
});

// - `name` is a [human-readable name](/docs/#/types/label.js). This is the 
//   contact's `fullname` (if specified), otherwise RunOrg will do its best
//   to create a recognizable name in an unspecified fashion.
TEST("The contact's fullname is returned if available.", function() {
    Assert.fail();
});

TEST("The contact's firstname + lastname is returned if available.", function() {
    Assert.fail();
});

TEST("The contacts's email is returned if available.", function() {
    Assert.fail();
});

// - `gender` can be `"F"` for female, `"M"` for male, or left 
//   undefined.

TEST("The contact's gender is returned.", function() {
    Assert.fail();
});

// - `pic` is the URL of an avatar picture. Uses the contact's 
//   `pic` if specified, otherwise RunOrg will do its best to 
//   generate a reasonable avatar picture in an unspecified fashion. 

TEST("The contact's picture is returned if available.", function() {
    Assert.fail();
});

TEST("A gravatar is generated if no picture is available.", function() {
    Assert.fail();
});

// ### Example value
//     { "id" : "0Et9j0026rO",
//       "name" : "Victor Nicollet",
//       "gender" : "M", 
//       "pic" : "https://www.gravatar.com/avatar/648e25e4372728b2d3e0c0b2b6e26f4e" }
//
// If you end up with a contact's id but not its basic information, this usually
// means the contact has gone missing from the database. You can still
// [try to get its data directly](/docs/#/contact/get.js), but it is not likely
// to work.
