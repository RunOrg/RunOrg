(* © 2014 RunOrg *)

open Std

let build = 24

let major = 0
let minor = 1

let version = major, minor, build
let version_string = !! "%d.%d.%d" major minor build
