Mail / Authentication

RunOrg supports e-mail authentication. The process is simple: 

 - Send an e-mail containing a link that enables authentication
   (using the `self` or `auth` template variables). 

 - The recipient clicks the link, is redirected to the original 
   URL with an additional query string parameter: an _e-mail_
   authentication token.

 - The page at the original URL uses that token to generate an 
   actual [API token](/docs/#/types/token.js). The visitor is now
   logged in !

### Example draft e-mail 

    { "self": "https://example.com/newsletters/{id}",
      "subject": "Newsletter",
      "html": {
        "script": "$0;self;$1",
        "inline": [ "<a href='", "'>Click here</a> to view the newsletter." ] },
      "from": "0xyxA0005rM" }

This [template](/docs/#/mail/template.js) uses the `self` variable,
which is always authenticated.

### Received e-mail

    <a href="https://api.runorg.com/db/0xyxA00B5rM/link/0xy..001">Click here</a> 
    to view the newsletter.

The generated link is secure, and points to the public URL of your
RunOrg server.  It includes a 28-character unique identifier designed
to be non-falsifiable.

Clicking this link will redirect to the original self-link (with
`{id}` replaced with the actual identifier of the draft).

### Redirection URL

    https://example.com/newsletters/0xyxA0995rM?auth=0xy..001

The authentication token is the same 28-character unique identifier
that could be found in the e-mail.

The page at that URL can then use the provided parameter to [authenticate
with an e-mail token](/docs/#/contact/authmail.js).