.PHONY: build watch dev clean install

install: node_modules

node_modules: package.json
	npm install

build: install
	npm run build:html

watch: install
	node scripts/watch.mjs

dev: install
	npm run dev

clean:
	rm -rf dist CutTracker.html
