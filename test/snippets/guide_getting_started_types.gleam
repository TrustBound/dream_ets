//// Guide: Getting started, step 4
////
//// A table with Int keys and Float values, made with the built-in encoders.

import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/option.{type Option}
import gleam/result

pub fn create_prices() -> Result(Table(Int, Float), EtsError) {
  config.new("product_prices")
  |> config.key(encoders.int_encoder, encoders.int_decoder())
  |> config.value(encoders.float_encoder, encoders.float_decoder())
  |> config.create()
}

pub fn price_of_product_42() -> Result(Option(Float), EtsError) {
  use prices <- result.try(create_prices())
  use Nil <- result.try(operations.set(prices, 42, 9.99))
  operations.get(prices, 42)
}
