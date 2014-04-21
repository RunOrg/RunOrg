Mail

The mailing module deals with incoming and outgoing e-mail. 

# Sending e-mail

E-mail sent through the Runorg API goes through several stages, 
represented by separate resources: 

The author creates the **draft** object, a resource intended
to be viewed and edited by the people responsible for sending
e-mail.

Once the original draft is deemed ready for sending, a **mailing wave**
is created, a resource intended to represent the sending of a single
e-mail to one or multiple e-mail addresses. 

RunOrg processes the wave by actually sending individual e-mails to
each recipient. It creates individual **sent e-mail** objects, one
per recipient. These resources are intended to track the statistics
about that individual e-mail: was it sent ? Opened ? Were its links 
clicked ? 

# Module contents
