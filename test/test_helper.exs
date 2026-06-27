# Route every Req request made during tests through Req.Test stubs (see
# Polymarket.Gamma.req_options/0). Individual tests register their stubs with
# `Req.Test.stub(Polymarket.Gamma, fn conn -> ... end)`.
Application.put_env(:ex_polymarket, :req_options, plug: {Req.Test, Polymarket.Gamma})

ExUnit.start()
