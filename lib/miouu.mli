open Miou

type file_descr

val read : file_descr -> bytes -> off:int -> len:int -> int
val write : file_descr -> string -> off:int -> len:int -> unit
val connect : file_descr -> Unix.sockaddr -> unit
val accept : ?cloexec:bool -> file_descr -> file_descr * Unix.sockaddr
val close : file_descr -> unit
val sleep : float -> unit
val of_file_descr : ?non_blocking:bool -> Unix.file_descr -> file_descr
val to_file_descr : file_descr -> Unix.file_descr
val owner : file_descr -> Own.t option
val run : ?g:Random.State.t -> ?domains:int -> (unit -> 'a) -> 'a
