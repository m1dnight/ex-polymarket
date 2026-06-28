# Route every Req request made during tests through Req.Test stubs (see
# Polymarket.Http.get/3). Each client owns its own stub, so individual tests
# register them against the client module, e.g.
# `Req.Test.stub(Polymarket.Gamma, fn conn -> ... end)` /
# `Req.Test.stub(Polymarket.Clob, fn conn -> ... end)`.
Application.put_env(:ex_polymarket, :http_test_mode, true)

ExUnit.start()
