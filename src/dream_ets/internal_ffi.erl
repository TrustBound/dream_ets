%% Erlang FFI for ETS operations
%%
%% Pure wrappers around Erlang ETS functions. No business logic here.

-module(internal_ffi).

-export([ets_new/2, ets_insert/2, ets_lookup/2, ets_take_one/2, ets_delete_table/1, ets_delete_key/2,
         ets_delete_all_objects/1, ets_first/1, ets_next/2, ets_member/2,
         ets_insert_new/2, ets_take/2, ets_update_element/3,
         ets_update_counter/4, ets_size/1,
         ets_match/2, ets_match_object/2, ets_select/2, ets_tab2file/2, ets_file2tab/1,
         to_dynamic/1, wrap_table_ref/1, unwrap_table_ref/1]).

%% Creates the table. Options are atoms or tuples, built in Gleam.
%%
%% ETS raises badarg both for a name that a named table already uses and for
%% options that it rejects. When a table with the name exists, the result is
%% {error, name_in_use}. Otherwise ETS rejected the options, and the result is
%% {error, {options_rejected, Message}}, where Message gives the reason that
%% ETS raised.
ets_new(Name, Options) ->
    try binary_to_atom(Name, utf8) of
        NameAtom -> ets_new_named(NameAtom, Options)
    catch
        %% An atom has at most 255 characters.
        error:Reason ->
            {error, {options_rejected,
                     <<"ETS rejected the table name: ", (format_error(Reason))/binary>>}}
    end.

ets_new_named(NameAtom, Options) ->
    try
        {ok, ets:new(NameAtom, Options)}
    catch
        error:Reason ->
            case ets:info(NameAtom) of
                undefined ->
                    {error, {options_rejected,
                             <<"ETS rejected the table options: ",
                               (format_error(Reason))/binary>>}};
                _ ->
                    {error, name_in_use}
            end
    end.

%% Each operation on an existing table runs through with_table/2, so that an
%% operation on a table that does not exist returns {error, table_not_found},
%% an operation that ETS refuses on a table that exists returns
%% {error, {invalid_operation, Message}}, and neither crashes the calling
%% process.

ets_insert(TableId, Object) ->
    with_table(TableId, fun() ->
        ets:insert(TableId, Object),
        {ok, nil}
    end).

%% Returns every object stored under Key, as a list. A set table has at most
%% one. A bag table can have more.
ets_lookup(TableId, Key) ->
    with_table(TableId, fun() -> {ok, ets:lookup(TableId, Key)} end).

ets_delete_table(TableId) ->
    with_table(TableId, fun() ->
        ets:delete(TableId),
        {ok, nil}
    end).

ets_delete_key(TableId, Key) ->
    with_table(TableId, fun() ->
        ets:delete(TableId, Key),
        {ok, nil}
    end).

ets_delete_all_objects(TableId) ->
    with_table(TableId, fun() ->
        ets:delete_all_objects(TableId),
        {ok, nil}
    end).

ets_first(TableId) ->
    with_table(TableId, fun() ->
        case ets:first(TableId) of
            '$end_of_table' ->
                {error, empty_table};
            Key ->
                {ok, Key}
        end
    end).

ets_next(TableId, Key) ->
    with_table(TableId, fun() ->
        case ets:next(TableId, Key) of
            '$end_of_table' ->
                {error, end_of_table};
            NextKey ->
                {ok, NextKey}
        end
    end).

ets_member(TableId, Key) ->
    with_table(TableId, fun() -> {ok, ets:member(TableId, Key)} end).

ets_insert_new(TableId, Object) ->
    with_table(TableId, fun() -> {ok, ets:insert_new(TableId, Object)} end).

%% Removes every object stored under Key, and returns them as a list.
ets_take(TableId, Key) ->
    with_table(TableId, fun() -> {ok, ets:take(TableId, Key)} end).

%% Removes the object stored under Key and returns it in a list, in one ETS
%% call. When the key has more than one object (a bag table), the objects
%% are put back, and the error is {several_objects, Count}.
ets_take_one(TableId, Key) ->
    with_table(TableId, fun() ->
        case ets:take(TableId, Key) of
            [_, _ | _] = Objects ->
                ets:insert(TableId, Objects),
                {error, {several_objects, length(Objects)}};
            Objects ->
                {ok, Objects}
        end
    end).

ets_update_element(TableId, Key, {Pos, Value}) ->
    with_table(TableId, fun() ->
        case ets:update_element(TableId, Key, {Pos, Value}) of
            Updated ->
                {ok, Updated}
        end
    end).

%% Adds Amount to the integer value of the object stored under Key, and
%% returns the new value, in one ETS call. When the key is not in the table,
%% ETS first inserts Default. ETS raises badarg when the value is not an
%% integer, or when the table is a bag or duplicate_bag table.
ets_update_counter(TableId, Key, Amount, Default) ->
    with_table(TableId, fun() ->
        {ok, ets:update_counter(TableId, Key, Amount, Default)}
    end).

%% Returns the number of objects in the table, in constant time.
%%
%% ets:info/1 also answers for a private table of another process, which
%% no other operation can read. For that table the result is the same
%% refused-operation error as the other reads give.
ets_size(TableId) ->
    case ets:info(TableId) of
        undefined ->
            {error, table_not_found};
        Info ->
            size_if_readable(Info)
    end.

size_if_readable(Info) ->
    Private = proplists:get_value(protection, Info) =:= private,
    Owner = proplists:get_value(owner, Info) =:= self(),
    case Private andalso not Owner of
        true ->
            {error, {invalid_operation, <<"ETS refused the operation: badarg">>}};
        false ->
            {ok, proplists:get_value(size, Info)}
    end.

%% Pattern matching - returns list of matches
ets_match(TableId, Pattern) ->
    with_table(TableId, fun() -> {ok, ets:match(TableId, Pattern)} end).

%% Pattern matching - returns matching objects
ets_match_object(TableId, Pattern) ->
    with_table(TableId, fun() -> {ok, ets:match_object(TableId, Pattern)} end).

%% Select with match specification
ets_select(TableId, MatchSpec) ->
    with_table(TableId, fun() -> {ok, ets:select(TableId, MatchSpec)} end).

%% Save table to file
ets_tab2file(TableId, Filename) ->
    %% Convert binary (Gleam String) to charlist (Erlang string)
    FilenamePath = binary_to_list(Filename),
    case ets:tab2file(TableId, FilenamePath) of
        ok ->
            {ok, nil};
        {error, badtab} ->
            missing_table_or(TableId, {invalid_operation, <<"badtab">>});
        {error, Reason} ->
            {error, {invalid_operation, format_error(Reason)}}
    end.

%% Load table from file
ets_file2tab(Filename) ->
    %% Convert binary (Gleam String) to charlist (Erlang string)
    FilenamePath = binary_to_list(Filename),
    case ets:file2tab(FilenamePath) of
        {ok, TableId} ->
            {ok, TableId};
        {error, Reason} ->
            {error, {invalid_operation, format_error(Reason)}}
    end.

%% Lookup and take return a list of objects
%% Runs Operation, which returns {ok, Value} or {error, Reason}.
%%
%% ETS raises badarg when the table does not exist, and also for other
%% causes (for example no access rights, or a bad match specification). The
%% table is checked only after badarg, so the normal path does no extra
%% lookup and no table can be deleted between a check and the operation.
%% A deleted table stays deleted, so the check after badarg finds it gone.
%% (Only if another process creates a new named table with the same name
%% between the two steps does the check find a table; then the result is
%% the refused-operation error.) When the table exists, ETS refused the
%% operation for another cause, and the result is
%% {error, {invalid_operation, <<"ETS refused the operation: badarg">>}}.
with_table(TableId, Operation) ->
    try
        Operation()
    catch
        error:badarg ->
            case ets:info(TableId) of
                undefined ->
                    {error, table_not_found};
                _ ->
                    {error, {invalid_operation,
                             <<"ETS refused the operation: badarg">>}}
            end
    end.

%% Returns {error, table_not_found} when the table does not exist, and
%% {error, OtherError} when it does
missing_table_or(TableId, OtherError) ->
    case ets:info(TableId) of
        undefined ->
            {error, table_not_found};
        _ ->
            {error, OtherError}
    end.

%% Format error reason as string
format_error(Reason) when is_atom(Reason) ->
    atom_to_binary(Reason, utf8);
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

%% Convert any Erlang term to Dynamic (identity function - Gleam FFI handles the wrapping)
to_dynamic(Value) ->
    Value.

%% Wrap table ID as opaque type (identity function)
wrap_table_ref(TableId) ->
    TableId.

%% Unwrap opaque table ref to table ID (identity function)
unwrap_table_ref(TableRef) ->
    TableRef.
