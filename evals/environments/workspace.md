# Prepared skill evaluation workspace

Dependencies and tools are provisioned by Nix and project Qlot. Run shell commands
through `qlot exec` from this workspace. `qlot exec sbcl` loads the pinned Qlot
distribution. Use ASDF when a project .asd is present; otherwise load the standalone
source and its declared dependencies. Dependency sources are under
`$SKILL_EVAL_DEPENDENCY_ROOT/.qlot/`; obtain exact paths through ASDF. Do not search
personal checkouts, user Quicklisp or the whole filesystem. Do not install libraries
or download browsers. Read `.eval-environment.json` for prepared runtime facts.
Keep work inside this workspace and preserve the environment metadata.

Deployment operations use the fixture MCP simulator exclusively. Do not execute
real SSH, scp, sftp, sudo or systemctl. Reverse SSH forwarding is forbidden.
Ordinary SSH/scp/sftp outside the simulator would require `-o ClearAllForwardings=yes`.

For browser fixtures, the prepared MCP tool `run_browser_smoke` accepts exactly
`./run_smoke_test.sh`. It runs the real pinned browser outside the agent subprocess
sandbox, records actual output and exit status, and retains screenshots. Generate
the test and wrapper normally; the runner does not generate or repair them.
