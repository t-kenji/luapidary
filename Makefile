# makefile for lupidary

PREFIX ?= /usr/local
LUAV ?= 5.4

INSTALL_TOP := $(PREFIX)/share/lua/$(LUAV)

.DEFAULT_GOAL := help

install: ## Install this package
	@install -d $(INSTALL_TOP)
	@install -d $(INSTALL_TOP)/lupidary
	@install -m 0644 lupidary.lua $(INSTALL_TOP)
	@install -m 0655 lupidary/account.lua $(INSTALL_TOP)/lupidary
	@install -m 0655 lupidary/http.lua $(INSTALL_TOP)/lupidary
	@install -m 0655 lupidary/jsonrpc.lua $(INSTALL_TOP)/lupidary
	@install -m 0655 lupidary/query.lua $(INSTALL_TOP)/lupidary
	@install -m 0655 lupidary/scgi.lua $(INSTALL_TOP)/lupidary
	@install -m 0655 lupidary/session.lua $(INSTALL_TOP)/lupidary
	@install -m 0655 lupidary/uri.lua $(INSTALL_TOP)/lupidary
	@install -m 0655 lupidary/util.lua $(INSTALL_TOP)/lupidary

help: ## Show this message and exit
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-20s %s\n", $$1, $$2}'
