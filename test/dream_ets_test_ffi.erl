-module(dream_ets_test_ffi).
-export([table_info/2, write_key_only_table/3, read_file/1]).

%% Returns one `ets:info/2` item of a named table, formatted with `~p`.
table_info(Name, Item) ->
    Value = ets:info(binary_to_existing_atom(Name), binary_to_existing_atom(Item)),
    iolist_to_binary(io_lib:format("~p", [Value])).

%% Writes a file of a named table that holds one object `{Key}`. The object
%% has a key and no value, so dream_ets cannot read a value from it.
write_key_only_table(Name, Key, Filename) ->
    Table = ets:new(binary_to_atom(Name), [set, public, named_table]),
    ets:insert(Table, {Key}),
    ok = ets:tab2file(Table, binary_to_list(Filename)),
    ets:delete(Table),
    nil.

%% Returns the text of a file, or an empty binary when it cannot be read.
read_file(Path) ->
    case file:read_file(Path) of
        {ok, Text} -> Text;
        {error, _} -> <<>>
    end.
