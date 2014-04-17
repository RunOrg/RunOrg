// JSON <token>
// Types / Token
//
// A short string.
//
// Tokens are used by the client to prove their
// [identity](/docs/#/concept/as.md) to the RunOrg API. It is returned by
// authentication methods such as [Persona](/docs/#/contact/persona.js)
// and [HMAC](/docs/#/contact/hmac.js). It is passed to the API in the
// `Authorization:` header of the [request](/docs/#/concept/request.md).
//
// A token always matches the regular expression `[a-zA-Z0-9]{1,128}`. In
// particular, even though most tokens returned by the API are 11
// characters long, they may take up to 128 characters in some situations.
// 
// ### Example token
//     9dF3M1wEma4
