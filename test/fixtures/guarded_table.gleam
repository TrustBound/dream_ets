//// Tables that only the creating process may write (protected) or use at
//// all (private), for the tests that check what each operation returns when
//// ETS refuses it in another process.

import dream_ets/config
import dream_ets/table.{type EtsError, type Table}

/// Creates a protected string table with the given name.
pub fn protected_string_table(
  name: String,
) -> Result(Table(String, String), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value_string()
  |> config.access(config.access_protected())
  |> config.create()
}

/// Creates a private string table with the given name.
pub fn private_string_table(
  name: String,
) -> Result(Table(String, String), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value_string()
  |> config.access(config.access_private())
  |> config.create()
}

/// Creates a protected counter table with the given name.
pub fn protected_counter(name: String) -> Result(Table(String, Int), EtsError) {
  config.new(name)
  |> config.counter()
  |> config.access(config.access_protected())
  |> config.create()
}
