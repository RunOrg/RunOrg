open Ohm
open Ohm.Universal

let welcome = Web.page "/session/welcome" Action.Args.none begin fun req res -> 
  let title = "Login" in
  let page = Html.str "<b>Hello, world!</b>" in  
  return (Action.page (Html.print_page ~title page) res)
end 
