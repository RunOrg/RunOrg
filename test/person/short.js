// JSON <person>
// People / A short representation of a person
// 
// Returned by most API methods that involve people. It is intended to 
// provide data relevant for displaying the person: its name, picture 
// and gender. 
// 
// Typical examples: [listing people in a group](/docs/#/group/get.js) or 
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
// - `label` is a [human-readable name](/docs/#/types/label.js). This is the 
//   person's `name` (if specified), otherwise RunOrg will do its best
//   to create a recognizable name in an unspecified fashion.
// - `gender` can be `"F"` for female, `"M"` for male, or left 
//   undefined.
// - `pic` is the URL of an avatar picture. Uses the person's 
//   `pic` if specified, otherwise RunOrg will do its best to 
//   generate a reasonable avatar picture in an unspecified fashion. 
//
// ### Example value
//     { "id" : "0Et9j0026rO",
//       "label" : "Victor Nicollet",
//       "gender" : "M", 
//       "pic" : "https://www.gravatar.com/avatar/648e25e4372728b2d3e0c0b2b6e26f4e" }

