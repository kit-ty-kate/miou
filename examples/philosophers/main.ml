let () = Random.self_init ()
let with_lock m fn = Mutex.lock m; fn (); Mutex.unlock m
let n = 5
let l i = (i - 1 + n) mod n
let r i = (i + 1) mod n
let output = Mutex.create ()
let critical = Mutex.create ()

type state = Hungry | Thinking | Eating

let test sem state i =
  if state.(i) = Hungry && state.(l i) <> Eating && state.(r i) <> Eating then (
    state.(i) <- Eating;
    Semaphore.Binary.release sem.(i))

let think i =
  let duration = 1. +. Random.float 5. in
  with_lock output (fun () ->
      Format.printf "%02d is thinking %fs\n%!" i duration);
  Miouu.sleep duration

let take_forks sem state i =
  let () =
    with_lock critical @@ fun () ->
    state.(i) <- Hungry;
    with_lock output (fun () -> Format.printf "%02d is hungry\n%!" i);
    test sem state i
  in
  Semaphore.Binary.acquire sem.(i)

let eat i =
  let duration = 1. +. Random.float 5. in
  with_lock output (fun () -> Format.printf "%02d is eating\n%!" i);
  Miouu.sleep duration

let put_forks sem state i =
  with_lock critical @@ fun () ->
  state.(i) <- Thinking;
  test sem state (l i);
  test sem state (r i)

let rec philosopher sem state i () =
  think i;
  take_forks sem state i;
  Miou.yield ();
  eat i;
  put_forks sem state i;
  Miou.yield ();
  philosopher sem state i ()

open Miou

let () =
  let ts =
    match int_of_string Sys.argv.(1) with value -> value | exception _ -> 30
  in
  Miouu.run ~domains:6 @@ fun () ->
  let sem = Array.init 5 (fun _ -> Semaphore.Binary.make false) in
  let state = Array.init 5 (fun _ -> Thinking) in
  let sleep =
    Prm.call (fun () ->
        Miouu.sleep (Float.of_int ts);
        Array.iter Semaphore.Binary.release sem)
  in
  let uid01 = Prm.call (philosopher sem state 00) in
  let uid02 = Prm.call (philosopher sem state 01) in
  let uid03 = Prm.call (philosopher sem state 02) in
  let uid04 = Prm.call (philosopher sem state 03) in
  let uid05 = Prm.call (philosopher sem state 04) in
  Prm.await_first [ uid01; uid02; uid03; uid04; uid05; sleep ] |> ignore
