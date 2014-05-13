Tokens

Tokens are short authorization strings.

They are used by users to prove their [identity](/docs/#/concept/as.md) to the RunOrg API. 

# Obtaining a token 

Tokens are returned by authentication methods such as:
 
 - **Mozilla Persona**: [`POST /db/{db}/person/auth/persona`](/docs/#/contact/persona.js)
 - **HMAC**: [`POST /db/{db}/person/auth/hmac`](/docs/#/contact/hmac.js) 

When an user follows a link in an e-mail created with [`self` or
`auth` urls](/docs/#/mail/auth.md), a brand new authentication token
will be appended to that link as a query parameter called `runorg`.

# Using a token

A token is passed to the API in the `Authorization:` header of the [HTTPS 
request](/docs/#/concept/request.md).

### Authorization header example
    Authorization: RUNORG token=9dF3M1wEma4

# API endpoints
