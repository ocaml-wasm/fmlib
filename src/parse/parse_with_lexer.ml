module type ANY = Fmlib_std.Interfaces.ANY


module type RUN =
sig
    type ch

    val string_at:
        ('a -> bool)
        -> (ch -> 'a -> 'a)
        -> ('a -> 'a)
        -> int
        -> string
        -> 'a
        -> int * 'a

    val string:
        ('a -> bool)
        -> (ch -> 'a -> 'a)
        -> ('a -> 'a)
        -> string ->
        'a
        -> 'a

    val channel:
        ('a -> bool)
        -> (ch -> 'a -> 'a)
        -> ('a -> 'a)
        -> in_channel
        -> 'a
        -> 'a
end



module Run_char =
struct
    type ch = char
    include Run_on
end



module Run_utf8 =
struct
    type ch = Utf8.Decoder.t
    include Run_on.Make (Utf8.Decoder)
end



module Make_basic
        (Run: RUN)
        (State: ANY)
        (Token: ANY)
        (Final: ANY)
        (Semantic: ANY)
        (Lex: Interfaces.LEXER with type final = Position.range * Token.t
                                and type token = Run.ch)
        (Parse: Interfaces.FULL_PARSER with
                type state = State.t
            and type token = Position.range * Token.t
            and type expect= string * Indent.expectation option
            and type final = Final.t
            and type semantic = Semantic.t)
=
struct
    type token    = Run.ch
    type item     = token
    type final    = Final.t
    type expect   = string * Indent.expectation option
    type semantic = Semantic.t
    type state    = State.t

    type t = {
        lex:   Lex.t;
        parse: Parse.t;
    }

    let make (lex: Lex.t) (parse: Parse.t): t =
        {lex; parse}


    let make_next (p: t) (parse: Parse.t): t =
        {
            lex = p.lex;
            parse = Parse.transfer_lookahead p.parse parse;
        }


    let lex (p: t): Lex.t =
        p.lex


    let parse (p: t): Parse.t =
        p.parse


    let needs_more (p: t): bool =
        Lex.needs_more p.lex
        &&
        Parse.needs_more p.parse

    let has_succeeded (p: t): bool =
        Parse.has_succeeded p.parse

    let has_ended (p: t): bool =
        Parse.has_ended p.parse

    let has_consumed_end (p: t): bool =
        Parse.has_consumed_end p.parse


    let has_failed_syntax (p:t): bool =
        if Parse.needs_more p.parse then
            Lex.has_failed_syntax p.lex
        else
            Parse.has_failed_syntax p.parse


    let has_failed_semantic (p: t): bool =
        Parse.has_failed_semantic p.parse


    let final (p: t): Final.t =
        assert (has_succeeded p);
        Parse.final p.parse


    let failed_expectations
            (p: t)
        : expect list
        =
        assert (has_failed_syntax p);
        if Parse.needs_more p.parse then
            Lex.failed_expectations p.lex
        else
            Parse.failed_expectations p.parse


    let failed_semantic (p: t): Semantic.t =
        assert (has_failed_semantic p);
        Parse.failed_semantic p.parse



    let position (p: t): Position.t =
        match
            Parse.first_lookahead_token p.parse
        with
        | None ->
            Lex.position p.lex
        | Some ((p1, _), _) ->
            p1


    let range (p: t): Position.range =
        match
            Parse.first_lookahead_token p.parse
        with
        | None ->
            let pos = Lex.position p.lex in
            pos, pos
        | Some (range, _) ->
            range


    let state (p: t): State.t =
        Parse.state p.parse


    let rec check_token (p: t): t =
        if
            Lex.(has_succeeded p.lex && not (has_consumed_end p.lex))
        then
            check_token {
                lex =
                    Lex.restart p.lex;
                parse =
                    Parse.put (Lex.final p.lex) p.parse
            }
        else
            p


    let put (c: Run.ch) (p: t): t =
        check_token {p with lex = Lex.put c p.lex}

    let put_end (p: t): t =
        let p =
            check_token {p with lex = Lex.put_end p.lex}
        in
        assert Lex.(not (has_succeeded p.lex) || has_consumed_end p.lex);
        if Lex.has_succeeded p.lex then
            (* The lexer has succeeded and has consumed the end of input.
             * Therefore it has encountered the end token.
             *)
            {p with parse = Parse.put_end p.parse}
        else
            p


    let run_on_string    = Run.string     needs_more put put_end
    let run_on_string_at = Run.string_at  needs_more put put_end
    let run_on_channel   = Run.channel    needs_more put put_end
end






module Make
        (State: ANY)
        (Token: ANY)
        (Final: ANY)
        (Semantic: ANY)
        (Lex: Interfaces.LEXER with type final = Position.range * Token.t
                                and type token = char)
        (Parse: Interfaces.FULL_PARSER with
                type state = State.t
            and type token = Position.range * Token.t
            and type expect= string * Indent.expectation option
            and type final = Final.t
            and type semantic = Semantic.t)
    =
    Make_basic (Run_char) (State) (Token) (Final) (Semantic) (Lex) (Parse)






module Make_utf8
        (State: ANY)
        (Token: ANY)
        (Final: ANY)
        (Semantic: ANY)
        (Lex: Interfaces.LEXER with type final = Position.range * Token.t
                                and type token = Utf8.Decoder.t)
        (Parse: Interfaces.FULL_PARSER with
                type state = State.t
            and type token = Position.range * Token.t
            and type expect= string * Indent.expectation option
            and type final = Final.t
            and type semantic = Semantic.t)
    =
    Make_basic (Run_utf8) (State) (Token) (Final) (Semantic) (Lex) (Parse)
