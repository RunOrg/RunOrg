(* © 2014 RunOrg *)

open Std

let build = 9

let major = 0
let minor = 9

let version = major, minor, build
let version_string = !! "%d.%d.%d" major minor build
