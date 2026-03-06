# List available tasks.
default:
    @just --list

# Build the Swift FFI static library
ext:
    cd ext && make

# Build the Crystal library (type-check)
build: ext
    crystal build src/fm.cr --no-codegen

# Run specs
spec: ext
    crystal spec

# Build all examples
examples: ext
    mkdir -p bin
    for f in examples/*.cr; do \
        echo "Building $f..."; \
        crystal build "$f" -o "bin/$(basename $f .cr)" || exit 1; \
    done

# Clean all build artifacts
clean:
    cd ext && make clean
    rm -rf bin
