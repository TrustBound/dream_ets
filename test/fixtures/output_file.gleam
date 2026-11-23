//// The output files that the guides show. A guide test builds the real
//// output of a snippet and compares it with one of these files, so the
//// guide, the file and the real output are the same text.

import gleam/int
import gleam/list
import gleam/string

/// Reads `test/outputs/<name>.txt`, or returns an empty string when the file
/// cannot be read.
pub fn read(name: String) -> String {
  read_file("test/outputs/" <> name <> ".txt")
}

/// Formats calls and the text of their real results as the guides show
/// them: one line per call, with each `->` two columns after the longest call.
/// Give each result as `string.inspect(result)`.
pub fn calls(lines: List(#(String, String))) -> String {
  let width =
    lines
    |> list.map(fn(line) { string.length(line.0) })
    |> list.fold(0, int.max)
  lines
  |> list.map(fn(line) {
    string.pad_end(line.0, width + 2, " ") <> "-> " <> line.1 <> "\n"
  })
  |> string.concat
}

/// Formats one real value as the guides show it: its text and a line break.
pub fn value(value: a) -> String {
  string.inspect(value) <> "\n"
}

@external(erlang, "dream_ets_test_ffi", "read_file")
fn read_file(path: String) -> String
