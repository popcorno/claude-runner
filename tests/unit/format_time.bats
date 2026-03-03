#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
}

@test "format_time: 0 seconds" {
  run format_time 0
  [ "$status" -eq 0 ]
  [ "$output" = "0s" ]
}

@test "format_time: 30 seconds" {
  run format_time 30
  [ "$status" -eq 0 ]
  [ "$output" = "30s" ]
}

@test "format_time: 59 seconds stays in seconds" {
  run format_time 59
  [ "$status" -eq 0 ]
  [ "$output" = "59s" ]
}

@test "format_time: 60 seconds becomes 1m0s" {
  run format_time 60
  [ "$status" -eq 0 ]
  [ "$output" = "1m0s" ]
}

@test "format_time: 90 seconds becomes 1m30s" {
  run format_time 90
  [ "$status" -eq 0 ]
  [ "$output" = "1m30s" ]
}

@test "format_time: 3661 seconds becomes 61m1s" {
  run format_time 3661
  [ "$status" -eq 0 ]
  [ "$output" = "61m1s" ]
}
