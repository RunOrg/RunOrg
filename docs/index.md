<page title="RunOrg documentation" />
<doc>
  Welcome ! 

  RunOrg is a database that stores information about [People](/people.md)
  and their interactions with you and with each other. It is designed for
  access over HTTPS: rather than letting it sit behind your application 
  server, you can let your users [Authenticate](auth.md) and interact 
  with the database directly&mdash;RunOrg will restrict the actions of 
  every user based on their identity, according to your [Access](/access.md) 
  rules. 

  Among other things, you can: 

  - Let people write [Posts](/posts.md), which can be standalone messages,
    replies to other messages or comments on arbitrary objects both inside
    and outside RunOrg. 

  - Create [Forms](/forms.md) and ask people to fill them. RunOrg computes
    statistics for you. 

  - Send [Mail](/mail.md). RunOrg lets you track which are opened and 
    includes links that authenticate recipients that click on it. 

  Some actions you can perform involve individual people, while others 
  involve [Groups](/groups.md) of people. 

  All of this happens inside a [Database](/database.md), and a single RunOrg
  server can host several independent databases.   
</doc>
