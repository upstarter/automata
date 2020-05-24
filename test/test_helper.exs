# @tag :pending
# test "my pending test" do
#   assert 2 + 2 == 5
# end
# mix test --include pending
ExUnit.configure(exclude: [pending: true])
# TODO: remove this, make tests random
ExUnit.configure(seed: 0)
ExUnit.start()

# {:ok, files} = File.ls("./test/support")
#
# Enum.each files, fn(file) ->
#   Code.require_file "support/#{file}", __DIR__
# end
