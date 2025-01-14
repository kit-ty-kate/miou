let tick = Atomic.make 0

type domain = {
    interrupt: bool Atomic.t
  ; mutable tick: int
  ; sleepers: (Miou.uid, int * unit Miou.syscall) Hashtbl.t
}

let dom =
  let make () =
    { interrupt= Atomic.make false; tick= 0; sleepers= Hashtbl.create 0x100 }
  in
  let dom = Stdlib.Domain.DLS.new_key make in
  fun () -> Stdlib.Domain.DLS.get dom

let sleepers () =
  let sleepers = ref [] in
  let collect _ (until, syscall) =
    if until <= 0 then begin
      sleepers := syscall :: !sleepers;
      None
    end
    else Some (until, syscall)
  in
  let dom = dom () in
  Hashtbl.filter_map_inplace collect dom.sleepers;
  List.map (fun syscall -> Miou.task syscall (Fun.const ())) !sleepers

let update_sleepers ~quanta () =
  Hashtbl.filter_map_inplace
    (fun _ (until, syscall) ->
      let until' = Int.max 0 (until - quanta) in
      Some (until', syscall))
    (dom ()).sleepers

let smallest_sleeper () =
  let fold _ (until, syscall) = function
    | Some (until', _) when until' > until -> Some (until, syscall)
    | Some _ as sleeper -> sleeper
    | None -> Some (until, syscall)
  in
  Hashtbl.fold fold (dom ()).sleepers None

let clean_syscalls () =
  Hashtbl.filter_map_inplace
    (fun _ (until, syscall) ->
      if Miou.is_pending syscall then Some (until, syscall) else None)
    (dom ()).sleepers

let select () =
  clean_syscalls ();
  match Atomic.get (dom ()).interrupt with
  | true ->
      Atomic.set (dom ()).interrupt false;
      []
  | false ->
      let quanta =
        match smallest_sleeper () with
        | Some (until, _) -> Int.min 1 until
        | None -> 1
      in
      let _set =
        if quanta > 0 then
          Atomic.compare_and_set tick (dom ()).tick ((dom ()).tick + 1)
        else false
      in
      (dom ()).tick <- Atomic.get tick;
      update_sleepers ~quanta ();
      sleepers ()

let events _ =
  let dom = dom () in
  let interrupt () = Atomic.set dom.interrupt true in
  { Miou.interrupt; select }

let sleep until =
  let syscall = Miou.make (Fun.const ()) in
  Hashtbl.add (dom ()).sleepers (Miou.uid syscall) (until, syscall);
  Miou.suspend syscall

let run ?g ?domains fn = Miou.run ~events ?g ?domains fn
