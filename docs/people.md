<page title="People" parent="index.md" />
<doc>
  A human **person** is a type of entity used throughout the RunOrg API 
  for many  purposes, the most important being:  

  - Message and email recipients are always people. All sending APIs
    expect either individuals or [groups](/groups.md) of people 
    as their parameters.
  - Everyone who logs in, using any method, is bound to a person. 
  - Access restrictions are based on the [person who performs the
    action](/auth.md).
</doc>  
<doc for="js">
  # Class `Person`

  The class [`RunOrg.Person`](/people/person.md) contains basic 
  information about a person, just enough to be able to display their 
  identity : a human-readable name, a small picture and (if available) 
  their gender. 

  This class is used when retrieving lists of people (because it uses
  less bandwidth than fetching the entire profile) and in situations 
  where obtaining a person's data is not the main purpose of the request
  (for example, when fetching a list of messages, basic information
  is provided about each author as a matter of convenience).  
</doc>
<doc for="api">
  # Person information
  
  The type [`<person>`](/people/person.md) contains basic information 
  about a person, just enough to be able to display their identity : a 
  human-readable name, a small picture and (if available) their gender. 

  This type is returned when retrieving lists of people (because it uses
  less bandwidth than fetching the entire profile) and in situations 
  where obtaining a person's data is not the main purpose of the request
  (for example, when fetching a list of messages, basic information
  is provided about each author as a matter of convenience).    
</doc>
<list tags="class:person methods:person" />
<doc for="js">
  # Class "Person.Profile"

  The class [`RunOrg.Person.Profile`](/people/profile.md) contains full 
  information about a person. 
</doc>
<doc for="js">
  # Complete profile

  The type [`<person:profile>`](/people/profile.md) contains full 
  information about a person. 
</doc>
<list tags="class:person.profile methods:person.profile" />