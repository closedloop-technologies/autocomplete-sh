# tests/test_autocomplete.bats

@test "Autocomplete script runs without errors" {
  run ./autocomplete.sh
  [ "$status" -eq 0 ]
}

