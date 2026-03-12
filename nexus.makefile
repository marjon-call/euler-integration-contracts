.PHONY: build

build:
	@if [ -f nexus_build_result.yaml ]; then \
		echo "nexus_build_result.yaml already exists, skipping build."; \
	else \
		git submodule update --init --recursive && \
		forge build && \
		echo 'language: solidity' > nexus_build_result.yaml && \
		echo 'build_targets:' >> nexus_build_result.yaml && \
		echo '  - .' >> nexus_build_result.yaml && \
		echo 'installation_script: "git submodule update --init --recursive && forge build"' >> nexus_build_result.yaml && \
		echo 'run_test_command: "MAINNET_RPC_URL=$$MAINNET_RPC_URL FORK_RPC_URL=$$MAINNET_RPC_URL forge test"' >> nexus_build_result.yaml && \
		echo 'developer_note: ""' >> nexus_build_result.yaml && \
		echo 'blocking_error: ""' >> nexus_build_result.yaml && \
		echo "Build complete. nexus_build_result.yaml created."; \
	fi
