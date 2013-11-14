open Ohm
open Ohm.Universal

let welcome = Web.page "/session/welcome" Action.Args.none begin fun req res -> 
  let! title = AdLib.get `Session_Welcome_Title in
  Web.render title (Assets.Session_Welcome.render ()) res
end 
