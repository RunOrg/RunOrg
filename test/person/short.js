// JSON <person>
// People / A short representation of a person
// 
// Returned by most API methods that involve people. It is intended to 
// provide data relevant for displaying the person: its name, picture 
// and gender. 
// 
// Typical examples: [listing people in a group](/docs/#/group/list.js) or 
// [displaying the messages in a chatroom](/docs/#/chat/messages.js). 
//
// ### `Person` JSON format
//     { id : <id>, 
//       label : <label>, 
//       gender : "F" | "M" | null,
//       pic : <url> }
// 
// - `id` is the [unique 11-character identifier](/docs/#/types/id.js) for this 
//   person

TODO("The person's identifier is returned.", function() {
    Assert.fail();
});

// - `name` is a [human-readable name](/docs/#/types/label.js). This is the 
//   person's `fullname` (if specified), otherwise RunOrg will do its best
//   to create a recognizable name in an unspecified fashion.
TODO("The person's fullname is returned if available.", function() {
    Assert.fail();
});

TODO("The person's firstname + lastname is returned if available.", function() {
    Assert.fail();
});

TODO("The people's email is returned if available.", function() {
    Assert.fail();
});

// - `gender` can be `"F"` for female, `"M"` for male, or left 
//   undefined.

TODO("The person's gender is returned.", function() {
    Assert.fail();
});

// - `pic` is the URL of an avatar picture. Uses the person's 
//   `pic` if specified, otherwise RunOrg will do its best to 
//   generate a reasonable avatar picture in an unspecified fashion. 

TODO("The person's picture is returned if available.", function() {
    Assert.fail();
});

TODO("A gravatar is generated if no picture is available.", function() {
    Assert.fail();
});

// ### Example value
//     { "id" : "0Et9j0026rO",
//       "label" : "Victor Nicollet",
//       "gender" : "M", 
//       "pic" : "https://www.gravatar.com/avatar/648e25e4372728b2d3e0c0b2b6e26f4e" }
//
// If you end up with a person's id but not its basic information, this usually
// means the person has gone missing from the database. You can still
// [try to get its data directly](/docs/#/person/get.js), but it is not likely
// to work.
