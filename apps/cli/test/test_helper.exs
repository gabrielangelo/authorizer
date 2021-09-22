ExUnit.start()

Mox.defmock(StdinMock, for: Cli.Ports.Stdin)
:ok = Application.ensure_started(:mox)
