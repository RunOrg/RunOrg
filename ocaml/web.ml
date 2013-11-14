open Ohm
open Ohm.Universal
open BatPervasives

type i18n = Assets.AdLib.key 

class webctx adlib = object
  inherit O.ctx
  inherit [i18n] AdLib.ctx 
    (match adlib with 
    | `EN -> Assets.AdLib.en
    | `FR -> Assets.AdLib.fr)
end

let server = object
  val domain = "runorg.local"
  method protocol () = `HTTP
  method domain () = domain
  method port () = 80
  method cookie_domain () = Some ("." ^ domain)
  method matches protocol domain' port = 
    if protocol <> `HTTP then None else
      if domain = domain' then Some () else None 
end

let language req = 
  let string = match req # get "lang" with 
    | Some l -> Some l 
    | None   -> req # cookie "L"
  in
  match string with 
  | Some "fr" -> `FR
  | Some "en"
  | _         -> `EN

let with_language_cookie lang res = 
  let string = match lang with `EN -> "en" | `FR -> "fr" in
  Action.with_cookie ~name:"L" ~value:string ~life:(3600 * 24 * 364) res

let page url args action = 
  Action.register server url args begin fun req res -> 
    let  lang = language req in    
    let  ctx  = new webctx lang in     
    let! res  = Run.with_context ctx (action req res) in
    return (with_language_cookie lang res) 
  end

let js = [
  "/public/jquery.min.js" ;
  "/public/jquery.json.min.js" ;
  Assets.Static.js
] 

let render title html res = 
  let! html = html in 
  return $ Action.page
    (Html.print_page
       ~js
       ~css:[Assets.Static.css]
       ~favicon:"/favicon.ico"
       ~title
       html) res

