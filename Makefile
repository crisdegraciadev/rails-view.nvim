.PHONY: test lint

test:
	nvim --headless -i NONE -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

lint:
	stylua --check lua plugin tests
